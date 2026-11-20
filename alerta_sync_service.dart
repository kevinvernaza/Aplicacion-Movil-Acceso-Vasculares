import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import 'alerta_database.dart';
import 'alerta_model.dart';

/// Sincroniza las alertas locales con el endpoint REST de Django.
///
/// IMPORTANTE: si la URL pública de ngrok cambia, actualiza [endpointAlertas].
/// El POST envía únicamente codigo_qr, nivel, fecha_hora_atencion y comentario.
/// Los registros marcados como prueba nunca deben enviarse a Django.
class AlertaSyncService {
  AlertaSyncService._();

  static final AlertaSyncService instance = AlertaSyncService._();

  static const String endpointAlertas =
      'https://frugally-slick-parmesan.ngrok-free.dev/api/alertas/';
  static const Duration _timeoutSolicitud = Duration(seconds: 20);

  final http.Client _cliente = http.Client();
  StreamSubscription<List<ConnectivityResult>>? _suscripcionConectividad;
  Timer? _reintentoPeriodico;
  bool _sincronizando = false;
  bool _sincronizacionSolicitadaDuranteEjecucion = false;
  bool _monitorIniciado = false;

  /// Inicia el intento inicial y vuelve a intentar cuando se recupera una
  /// conexión de red mientras el proceso de la app está activo.
  ///
  /// La conectividad del dispositivo solo es una señal preliminar: cada POST
  /// confirma si realmente se pudo contactar y obtener respuesta de Django.
  void iniciarMonitorDeConectividad() {
    if (_monitorIniciado) return;
    _monitorIniciado = true;

    _suscripcionConectividad = Connectivity().onConnectivityChanged.listen(
      (resultados) {
        final hayInterfazDeRed =
            resultados.any((resultado) => resultado != ConnectivityResult.none);
        if (hayInterfazDeRed) {
          unawaited(sincronizarPendientes());
        }
      },
      onError: (_) {
        // El botón manual seguirá disponible; el POST es la comprobación real.
      },
    );

    // Al iniciar la app, intenta enviar registros pendientes de sesiones previas.
    unawaited(sincronizarPendientes());

    // La interfaz de red puede seguir activa aunque Django/ngrok haya estado
    // caído. Este reintento periódico detecta que el servidor volvió a responder.
    // Solo se hace trabajo de red si todavía existen alertas pendientes.
    _reintentoPeriodico = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(sincronizarPendientes());
    });
  }

  Future<ResultadoSincronizacion> sincronizarPendientes() async {
    if (_sincronizando) {
      // Si se guarda una alerta mientras otro envío está en curso, solicita
      // una segunda pasada para que el nuevo registro no tenga que esperar
      // al siguiente reintento periódico.
      _sincronizacionSolicitadaDuranteEjecucion = true;
      return const ResultadoSincronizacion(yaEstabaEnCurso: true);
    }

    _sincronizando = true;
    try {
      final pendientes = await AlertaDatabase.instance
          .obtenerPendientesDeSincronizacion();

      if (pendientes.isEmpty) {
        return const ResultadoSincronizacion(sinPendientes: true);
      }

      // Esto evita solicitudes inútiles si el teléfono no tiene ninguna red.
      // Si el plugin falla al consultar, continuamos y dejamos que el POST
      // determine si Django es realmente accesible.
      try {
        final conectividades = await Connectivity().checkConnectivity();
        if (conectividades.contains(ConnectivityResult.none)) {
          return const ResultadoSincronizacion(sinConexion: true);
        }
      } catch (_) {
        // La petición HTTP de abajo es la comprobación definitiva.
      }

      var sincronizadas = 0;

      for (final alerta in pendientes) {
        // Protección adicional: las valoraciones de prueba no son clínicas.
        // No se envían aunque, por un error futuro, llegaran a esta lista.
        if (alerta.esPrueba) continue;

        final idLocal = alerta.id;
        if (idLocal == null) {
          continue;
        }

        try {
          final respuesta = await _cliente
              .post(
                Uri.parse(endpointAlertas),
                headers: const {
                  'Content-Type': 'application/json; charset=UTF-8',
                  'Accept': 'application/json',
                  // Evita la página intermedia de advertencia en algunos
                  // túneles gratuitos de ngrok para clientes HTTP.
                  'ngrok-skip-browser-warning': 'true',
                },
                body: jsonEncode(alerta.toApiJson()),
              )
              .timeout(_timeoutSolicitud);

          final errorValidacion = _validarRespuesta(respuesta, alerta);
          if (errorValidacion == null) {
            await AlertaDatabase.instance.marcarComoSincronizada(idLocal);
            sincronizadas++;
          } else {
            await AlertaDatabase.instance.registrarErrorDeSincronizacion(
              idLocal,
              errorValidacion,
            );
          }
        } on TimeoutException {
          await AlertaDatabase.instance.registrarErrorDeSincronizacion(
            idLocal,
            'Tiempo de espera agotado al contactar con Django. Se reintentará.',
          );
          // Si no responde el servidor, evita esperar por cada alerta restante.
          break;
        } on SocketException catch (error) {
          await AlertaDatabase.instance.registrarErrorDeSincronizacion(
            idLocal,
            'No se pudo establecer conexión con el servidor: ${error.message}',
          );
          break;
        } on http.ClientException catch (error) {
          await AlertaDatabase.instance.registrarErrorDeSincronizacion(
            idLocal,
            'Error de comunicación HTTP: ${error.message}. Se reintentará.',
          );
          break;
        } catch (error) {
          await AlertaDatabase.instance.registrarErrorDeSincronizacion(
            idLocal,
            'No se pudo sincronizar. Se reintentará. Detalle: $error',
          );
        }
      }

      return ResultadoSincronizacion(
        totalProcesadas: pendientes.length,
        sincronizadas: sincronizadas,
        fallidas: pendientes.length - sincronizadas,
      );
    } catch (error) {
      return ResultadoSincronizacion(errorGeneral: error.toString());
    } finally {
      _sincronizando = false;

      // Ejecuta una nueva pasada si se solicitó sincronizar mientras la
      // anterior estaba ocupada. La nueva consulta incluye los registros
      // recién guardados en SQLite.
      if (_sincronizacionSolicitadaDuranteEjecucion) {
        _sincronizacionSolicitadaDuranteEjecucion = false;
        unawaited(sincronizarPendientes());
      }
    }
  }

  /// Solo considera confirmada una respuesta 200/201 cuyo cuerpo JSON incluya
  /// el ID remoto y coincida con el QR, el nivel y la fecha/hora enviada.
  /// HTTP 200 también es válido cuando Django responde que la alerta ya existía.
  String? _validarRespuesta(http.Response respuesta, AlertaRegistro alerta) {
    if (respuesta.statusCode != 200 && respuesta.statusCode != 201) {
      return 'Django respondió HTTP ${respuesta.statusCode}: '
          '${_resumirCuerpo(respuesta.body)}';
    }

    dynamic decodificado;
    try {
      decodificado = jsonDecode(respuesta.body);
    } catch (_) {
      return 'Django respondió, pero el contenido no era JSON válido. '
          'La alerta sigue pendiente.';
    }

    if (decodificado is! Map) {
      return 'La respuesta de Django no tiene el formato esperado.';
    }

    final datos = Map<String, dynamic>.from(decodificado);
    if (datos['id'] == null) {
      return 'Django no devolvió el ID de la alerta; no se marcó como enviada.';
    }
    if (datos['codigo_qr'] != alerta.codigoQr) {
      return 'El código QR de la respuesta no coincide con el enviado.';
    }
    if (datos['nivel'] != alerta.nivelAlerta) {
      return 'El nivel de alerta de la respuesta no coincide con el enviado.';
    }

    final fechaServidor = datos['fecha_hora_atencion'];
    if (fechaServidor is! String) {
      return 'Django no devolvió fecha_hora_atencion en la respuesta.';
    }

    try {
      final fechaRecibida = DateTime.parse(fechaServidor).toUtc();
      final fechaEnviada = alerta.fechaHoraAtencion.toUtc();
      final diferenciaMs = fechaRecibida
          .difference(fechaEnviada)
          .inMilliseconds
          .abs();
      // Se toleran pequeñas diferencias de precisión del serializador/BD.
      if (diferenciaMs > 5000) {
        return 'La fecha/hora devuelta por Django no coincide con la enviada.';
      }
    } catch (_) {
      return 'Django devolvió una fecha/hora que no se pudo interpretar.';
    }

    return null;
  }

  String _resumirCuerpo(String cuerpo) {
    if (cuerpo.trim().isEmpty) return 'respuesta vacía';
    try {
      final dato = jsonDecode(cuerpo);
      if (dato is Map) {
        final detalle = dato['detail'] ?? dato['mensaje'] ?? dato['error'];
        if (detalle != null) return detalle.toString();
        return dato.entries
            .map((entrada) => '${entrada.key}: ${entrada.value}')
            .join('; ');
      }
    } catch (_) {
      // Puede ser una página HTML de error, por ejemplo si ngrok no está activo.
    }
    final limpio = cuerpo.replaceAll(RegExp(r'\s+'), ' ').trim();
    return limpio.length > 220 ? '${limpio.substring(0, 220)}…' : limpio;
  }

  Future<void> dispose() async {
    _reintentoPeriodico?.cancel();
    await _suscripcionConectividad?.cancel();
    _cliente.close();
  }
}

class ResultadoSincronizacion {
  final int totalProcesadas;
  final int sincronizadas;
  final int fallidas;
  final bool sinConexion;
  final bool sinPendientes;
  final bool yaEstabaEnCurso;
  final String? errorGeneral;

  const ResultadoSincronizacion({
    this.totalProcesadas = 0,
    this.sincronizadas = 0,
    this.fallidas = 0,
    this.sinConexion = false,
    this.sinPendientes = false,
    this.yaEstabaEnCurso = false,
    this.errorGeneral,
  });

  String get mensaje {
    if (yaEstabaEnCurso) return 'La sincronización ya está en curso.';
    if (sinPendientes) return 'No hay alertas pendientes de sincronización.';
    if (sinConexion) {
      return 'No hay conexión de red. Las alertas permanecen pendientes.';
    }
    if (errorGeneral != null) {
      return 'No se pudo consultar el almacenamiento local: $errorGeneral';
    }
    if (fallidas == 0) {
      return 'Sincronización completada: $sincronizadas alerta(s) confirmada(s) por Django.';
    }
    if (sincronizadas > 0) {
      return 'Se sincronizaron $sincronizadas alerta(s); $fallidas siguen pendientes para reintentar.';
    }
    return 'No se pudo confirmar el envío. $fallidas alerta(s) siguen pendientes para reintentar.';
  }
}
