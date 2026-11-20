import 'package:flutter/foundation.dart';

/// Registro final de una valoración.
/// Nunca contiene las respuestas individuales del checklist.
/// El resumenChecklist contiene únicamente hallazgos/recomendaciones derivados
/// del resultado y se conserva localmente; no se envía a Django.
@immutable
class AlertaRegistro {
  final int? id;
  final String codigoQr;
  final String tipoAcceso;
  final String nivelAlerta;
  final DateTime fechaHoraAtencion;
  final String comentario;
  final String resumenChecklist;
  /// Tipo de checklist que originó la alerta: FAV o CVC.
  /// Se conserva localmente para identificar alertas MIX9 al sincronizar.
  final String tipoChecklist;
  final bool esPrueba;
  final String estadoSincronizacion;
  final int intentosSincronizacion;
  final String? ultimoErrorSincronizacion;

  const AlertaRegistro({
    this.id,
    required this.codigoQr,
    required this.tipoAcceso,
    required this.nivelAlerta,
    required this.fechaHoraAtencion,
    this.comentario = '',
    this.resumenChecklist = '',
    this.tipoChecklist = '',
    this.esPrueba = false,
    this.estadoSincronizacion = EstadoSincronizacion.pendiente,
    this.intentosSincronizacion = 0,
    this.ultimoErrorSincronizacion,
  });

  /// Las pruebas no cuentan como pendientes y nunca se sincronizan.
  bool get estaPendiente =>
      !esPrueba && estadoSincronizacion != EstadoSincronizacion.sincronizada;

  String get fechaHoraFormateada {
    final local = fechaHoraAtencion.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${local.year} · $hora:$minuto';
  }

  /// Datos persistidos localmente. No incluye respuestas individuales del
  /// checklist ni tipoAcceso; el tipo se deriva del prefijo del QR.
  Map<String, Object?> toDatabaseMap() => {
        'codigo_qr': codigoQr,
        'nivel': nivelAlerta,
        'fecha_hora_atencion_utc': fechaHoraAtencion.toUtc().toIso8601String(),
        'comentario': comentario,
        'resumen_checklist': resumenChecklist,
        'tipo_checklist': tipoChecklist,
        'es_prueba': esPrueba ? 1 : 0,
        'estado_sincronizacion': estadoSincronizacion,
        'intentos_sincronizacion': intentosSincronizacion,
        'ultimo_error_sincronizacion': ultimoErrorSincronizacion,
      };

  factory AlertaRegistro.fromDatabaseMap(Map<String, Object?> map) {
    final codigo = map['codigo_qr'] as String;
    final tipoChecklist =
        (map['tipo_checklist'] as String? ?? '').toUpperCase();
    return AlertaRegistro(
      id: map['id'] as int?,
      codigoQr: codigo,
      tipoAcceso: _tipoAccesoDesdeCodigo(codigo, tipoChecklist),
      tipoChecklist: tipoChecklist,
      nivelAlerta: map['nivel'] as String,
      fechaHoraAtencion: DateTime.parse(
        map['fecha_hora_atencion_utc'] as String,
      ).toLocal(),
      comentario: map['comentario'] as String? ?? '',
      resumenChecklist: map['resumen_checklist'] as String? ?? '',
      esPrueba: (map['es_prueba'] as int? ?? 0) == 1,
      estadoSincronizacion:
          map['estado_sincronizacion'] as String? ??
              EstadoSincronizacion.pendiente,
      intentosSincronizacion:
          map['intentos_sincronizacion'] as int? ?? 0,
      ultimoErrorSincronizacion:
          map['ultimo_error_sincronizacion'] as String?,
    );
  }

  /// Comentario que se envía a Django.
  /// En QR MIX9 agrega una etiqueta dentro del comentario para distinguir
  /// qué checklist originó la alerta, sin agregar campos al contrato de la API.
  /// El comentario almacenado localmente permanece limpio.
  String get comentarioParaApi {
    final comentarioLimpio = comentario.trim();
    if (!codigoQr.toUpperCase().startsWith('MIX9')) {
      return comentarioLimpio;
    }

    final tipo = tipoChecklist.toUpperCase();
    final etiqueta = switch (tipo) {
      'FAV' => '[CHECKLIST FAV/AVG]',
      'CVC' => '[CHECKLIST CVC]',
      _ => '',
    };

    if (etiqueta.isEmpty) return comentarioLimpio;
    if (comentarioLimpio.isEmpty) return etiqueta;
    return '$etiqueta $comentarioLimpio';
  }

  /// Payload compatible con POST /api/alertas/ de Django.
  /// Se mantienen exclusivamente QR, nivel, fecha/hora y comentario.
  /// resumenChecklist y tipoChecklist se conservan localmente y NO se envían
  /// como campos independientes al servidor.
  Map<String, dynamic> toApiJson() => {
        'codigo_qr': codigoQr,
        'nivel': nivelAlerta,
        'fecha_hora_atencion': _fechaIsoConZonaHoraria(fechaHoraAtencion),
        'comentario': comentarioParaApi,
      };

  AlertaRegistro copyWith({
    int? id,
    String? resumenChecklist,
    String? tipoChecklist,
    String? estadoSincronizacion,
    int? intentosSincronizacion,
    String? ultimoErrorSincronizacion,
    bool borrarUltimoError = false,
  }) {
    return AlertaRegistro(
      id: id ?? this.id,
      codigoQr: codigoQr,
      tipoAcceso: tipoAcceso,
      nivelAlerta: nivelAlerta,
      fechaHoraAtencion: fechaHoraAtencion,
      comentario: comentario,
      resumenChecklist: resumenChecklist ?? this.resumenChecklist,
      tipoChecklist: tipoChecklist ?? this.tipoChecklist,
      esPrueba: esPrueba,
      estadoSincronizacion:
          estadoSincronizacion ?? this.estadoSincronizacion,
      intentosSincronizacion:
          intentosSincronizacion ?? this.intentosSincronizacion,
      ultimoErrorSincronizacion: borrarUltimoError
          ? null
          : (ultimoErrorSincronizacion ?? this.ultimoErrorSincronizacion),
    );
  }

  static String _tipoAccesoDesdeCodigo(
    String codigo,
    String tipoChecklist,
  ) {
    final prefijo = codigo.toUpperCase().split('-').first;
    if (prefijo.startsWith('CVC')) return 'Catéter venoso central (CVC)';
    if (prefijo == 'MIX9') {
      if (tipoChecklist == 'FAV') {
        return 'Fístula arteriovenosa (FAV) o injerto arteriovenoso (AVG)';
      }
      if (tipoChecklist == 'CVC') {
        return 'Catéter venoso central (CVC)';
      }
      return 'Fístula arteriovenosa (FAV) + catéter venoso central (CVC)';
    }
    if (prefijo.startsWith('FAV')) {
      return 'Fístula arteriovenosa (FAV) o injerto arteriovenoso (AVG)';
    }
    return 'Acceso vascular';
  }

  static String _fechaIsoConZonaHoraria(DateTime valor) {
    final local = valor.toLocal();
    final offset = local.timeZoneOffset;
    final signo = offset.isNegative ? '-' : '+';
    final horas = offset.inHours.abs().toString().padLeft(2, '0');
    final minutos = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final fecha =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}T'
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
    return '$fecha$signo$horas:$minutos';
  }
}

class EstadoSincronizacion {
  static const String pendiente = 'PENDIENTE';
  static const String sincronizada = 'SINCRONIZADA';
  static const String error = 'ERROR';
}
