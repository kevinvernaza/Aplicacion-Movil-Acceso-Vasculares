import 'dart:async';

import 'package:flutter/material.dart';

import 'alerta_sync_service.dart';

import 'alerta_database.dart';
import 'alerta_model.dart';

// Colores de apoyo (solo visuales)
const Color _azulOscuro = Color(0xFF18364A);
const Color _turquesa = Color(0xFF087E8B);
const Color _textoSuave = Color(0xFF5B6E7C);
const Color _borde = Color(0xFFE1EAF0);

const Color _verde = Color(0xFF238636);

/// Tipo de checklist que se ejecutará. Es independiente del código QR:
/// un QR MIX9 puede abrir primero FAV/AVG y después CVC.
enum TipoChecklistAcceso {
  favAvg,
  cvc,
}

/// Resultado final de la valoración. No contiene ni expone respuestas individuales.
class ResultadoChecklistPrueba {
  final String codigoQr;
  final String tipoAcceso;
  final String nivelAlerta;
  final DateTime fechaHoraAtencion;
  final String comentario;
  final int? idLocal;
  final bool esPrueba;

  const ResultadoChecklistPrueba({
    required this.codigoQr,
    required this.tipoAcceso,
    required this.nivelAlerta,
    required this.fechaHoraAtencion,
    this.comentario = '',
    this.idLocal,
    this.esPrueba = false,
  });

  ResultadoChecklistPrueba copyWith({int? idLocal}) {
    return ResultadoChecklistPrueba(
      codigoQr: codigoQr,
      tipoAcceso: tipoAcceso,
      nivelAlerta: nivelAlerta,
      fechaHoraAtencion: fechaHoraAtencion,
      comentario: comentario,
      idLocal: idLocal ?? this.idLocal,
      esPrueba: esPrueba,
    );
  }

  String get fechaHoraFormateada {
    final fecha = fechaHoraAtencion.toLocal();
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} · $hora:$minuto';
  }
}


/// Hallazgo calculado en memoria a partir de las respuestas FAV.
/// No se guarda en SQLite ni se envía a Django.
class _HallazgoFAV {
  final String nivelAlerta; // ROJA o AMARILLA
  final String textoHallazgo;
  final String recomendacion;
  final bool recomendacionPendiente;

  const _HallazgoFAV({
    required this.nivelAlerta,
    required this.textoHallazgo,
    required this.recomendacion,
    this.recomendacionPendiente = false,
  });
}

/// Clasificación calculada al finalizar el checklist FAV.
class _ClasificacionFAV {
  final String nivelAlerta; // VERDE, AMARILLA o ROJA
  final List<_HallazgoFAV> hallazgos;

  const _ClasificacionFAV({
    required this.nivelAlerta,
    this.hallazgos = const [],
  });
}

/// Hallazgo calculado en memoria a partir de las respuestas CVC.
/// No se guarda en SQLite ni se envía a Django.
class _HallazgoCVC {
  final String nivelAlerta; // ROJA o AMARILLA
  final String textoHallazgo;
  final String recomendacion;

  const _HallazgoCVC({
    required this.nivelAlerta,
    required this.textoHallazgo,
    required this.recomendacion,
  });
}

/// Clasificación calculada al finalizar el checklist CVC.
class _ClasificacionCVC {
  final String nivelAlerta; // VERDE, AMARILLA o ROJA
  final List<_HallazgoCVC> hallazgos;

  const _ClasificacionCVC({
    required this.nivelAlerta,
    this.hallazgos = const [],
  });
}

/// Datos de presentación de un hallazgo y su recomendación (solo visual).
class _DatosCompendio {
  final String nivel;
  final String hallazgo;
  final String recomendacion;
  final bool pendiente;

  const _DatosCompendio({
    required this.nivel,
    required this.hallazgo,
    required this.recomendacion,
    this.pendiente = false,
  });
}

/// Estilo visual de cada nivel de alerta (solo presentación).
class _EstiloNivel {
  final Color color;
  final Color colorTexto;
  final Color colorCirculo;
  final List<Color> gradiente;
  final String titulo;
  final IconData icono;

  const _EstiloNivel({
    required this.color,
    required this.colorTexto,
    required this.colorCirculo,
    required this.gradiente,
    required this.titulo,
    required this.icono,
  });
}

_EstiloNivel _estiloNivel(String nivel) {
  if (nivel == 'ROJA') {
    return const _EstiloNivel(
      color: Color(0xFFC62828),
      colorTexto: Colors.white,
      colorCirculo: Color(0x38FFFFFF),
      gradiente: [Color(0xFFE53935), Color(0xFFB71C1C)],
      titulo: 'ROJO — Se requiere valoración urgente',
      icono: Icons.error_rounded,
    );
  }
  if (nivel == 'AMARILLA') {
    return const _EstiloNivel(
      color: Color(0xFFB77900),
      colorTexto: Color(0xFF5C3A00),
      colorCirculo: Color(0x66FFFFFF),
      gradiente: [Color(0xFFFFE595), Color(0xFFFFCB57)],
      titulo: 'AMARILLO — Se requiere valoración oportuna',
      icono: Icons.warning_amber_rounded,
    );
  }
  return const _EstiloNivel(
    color: _verde,
    colorTexto: Colors.white,
    colorCirculo: Color(0x38FFFFFF),
    gradiente: [Color(0xFF2EA043), _verde],
    titulo: 'ALERTA VERDE',
    icono: Icons.check_circle_rounded,
  );
}

class ChecklistScreen extends StatefulWidget {
  final String codigoQr;
  final String tipoAcceso;
  final TipoChecklistAcceso? tipoChecklist;

  const ChecklistScreen({
    super.key,
    required this.codigoQr,
    required this.tipoAcceso,
    this.tipoChecklist,
  });

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  // Las respuestas solo viven en la memoria de esta pantalla.
  // Nunca se incluyen en AlertaRegistro, SQLite ni el payload de Django.
  final Map<String, String> _respuestas = {};
  final TextEditingController _comentarioController = TextEditingController();

  bool _resultadoMostrado = false;
  bool _guardando = false;
  String? _errorGuardado;
  DateTime? _fechaHoraResultado;
  ResultadoChecklistPrueba? _resultado;
  _ClasificacionFAV? _clasificacionFAV;
  _ClasificacionCVC? _clasificacionCVC;

  static const List<_PreguntaChecklist> _inspeccion = [
    _PreguntaChecklist(
      codigo: 'FAV-01',
      pregunta:
          '¿Hay sangrado activo en el acceso o en alguna zona de punción?',
    ),
    _PreguntaChecklist(
      codigo: 'FAV-02',
      pregunta:
          '¿Se observa enrojecimiento, secreción, heridas o lesiones en la piel del acceso?',
    ),
    _PreguntaChecklist(
      codigo: 'FAV-03',
      pregunta:
          '¿Se observa edema en el brazo o la mano del lado del acceso vascular y se acompaña de dolor intenso o cambios importantes de coloración/temperatura?',
    ),
    _PreguntaChecklist(
      codigo: 'FAV-04',
      pregunta:
          '¿Se observan dilataciones o abultamientos prominentes en el acceso, acompañados de piel adelgazada/brillante, costra, úlcera, lesión o sangrado?',
    ),
    _PreguntaChecklist(
      codigo: 'FAV-05',
      pregunta:
          '¿La mano presenta palidez, coloración azulada o frialdad marcada, acompañada de dolor en reposo, pérdida de sensibilidad, adormecimiento, hormigueo o debilidad?',
    ),
    _PreguntaChecklist(
      codigo: 'FAV-06',
      pregunta:
          '¿Se identifican apósitos compresivos en las zonas de punción después de la sesión de hemodiálisis?',
    ),
  ];

  static const List<_PreguntaChecklist> _palpacion = [
    _PreguntaChecklist(
      codigo: 'FAV-07',
      pregunta:
          '¿Se identifica frémito (vibración) al palpar suavemente la FAV o el injerto?',
    ),
  ];

  // Preguntas específicas del checklist CVC, basadas en la infografía de enfermería.
  static const _PreguntaChecklist _cvcAposito = _PreguntaChecklist(
    codigo: 'CVC-01',
    pregunta: 'Apósito limpio, seco, íntegro y bien adherido.',
  );

  static const List<_PreguntaChecklist> _cvcValoracionCateter = [
    _PreguntaChecklist(
      codigo: 'CVC-02',
      pregunta:
          'Sitio de inserción y orificio de salida limpios, secos, sin eritema, exudado ni dolor.',
    ),
    _PreguntaChecklist(
      codigo: 'CVC-03',
      pregunta: '¿Las aletas de fijación están intactas?',
    ),
    _PreguntaChecklist(
      codigo: 'CVC-04',
      pregunta: '¿Las conexiones están firmes y sin fugas?',
    ),
    _PreguntaChecklist(
      codigo: 'CVC-05',
      pregunta: '¿Los tapones o clamps están en buen estado?',
    ),
    _PreguntaChecklist(
      codigo: 'CVC-06',
      pregunta: '¿Las líneas están sin grietas, oclusiones ni pinzamientos?',
    ),
    _PreguntaChecklist(
      codigo: 'CVC-07',
      pregunta: '¿Se observa desplazamiento, tracción o salida accidental?',
    ),
  ];

  static const List<_PreguntaChecklist> _cvcValoracionPaciente = [
    _PreguntaChecklist(
      codigo: 'CVC-08',
      pregunta: '¿Presenta dolor en el sitio de inserción?',
    ),
    _PreguntaChecklist(
      codigo: 'CVC-09',
      pregunta: '¿Presenta fiebre y escalofríos?',
    ),
    _PreguntaChecklist(
      codigo: 'CVC-10',
      pregunta:
          '¿Hay tumefacción en cuello, tórax, brazo o pierna del lado del catéter?',
    ),
    _PreguntaChecklist(
      codigo: 'CVC-11',
      pregunta: '¿Hay sangrado persistente o abundante?',
    ),
  ];

  static const List<_OpcionRespuesta> _siNo = [
    _OpcionRespuesta(valor: 'SI', etiqueta: 'Sí'),
    _OpcionRespuesta(valor: 'NO', etiqueta: 'No'),
  ];

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  bool get _esCvc {
    // Si main.dart especifica el checklist, ese dato tiene prioridad.
    // El prefijo del QR solo se usa como compatibilidad con llamadas antiguas.
    final tipo = widget.tipoChecklist;
    if (tipo != null) return tipo == TipoChecklistAcceso.cvc;
    return widget.codigoQr.toUpperCase().startsWith('CVC');
  }

  /// Códigos que se deben responder según la condición del apósito.
  /// Si CVC-01 es Sí, se omiten CVC-02 a CVC-07; si es No, se requieren.
  List<String> get _codigosCvcRequeridos {
    final estadoAposito = _respuestas['CVC-01'];
    if (estadoAposito == null) return const ['CVC-01'];

    final codigos = <String>['CVC-01'];
    if (estadoAposito == 'NO') {
      codigos.addAll(List.generate(
        6,
        (indice) => 'CVC-${(indice + 2).toString().padLeft(2, '0')}',
      ));
    }
    codigos.addAll(List.generate(
      4,
      (indice) => 'CVC-${(indice + 8).toString().padLeft(2, '0')}',
    ));
    return codigos;
  }

  int get _preguntasPrincipalesRespondidas {
    if (_esCvc) {
      return _codigosCvcRequeridos.where(_respuestas.containsKey).length;
    }

    final codigos = <String>[
      ..._inspeccion.map((p) => p.codigo),
      ..._palpacion.map((p) => p.codigo),
      'FAV-08',
    ];
    return codigos.where(_respuestas.containsKey).length;
  }

  int get _totalPreguntasPrincipales =>
      _esCvc ? _codigosCvcRequeridos.length : 8;

  bool get _respuestasCompletas {
    if (_esCvc) {
      return _codigosCvcRequeridos.every(_respuestas.containsKey);
    }

    final principales = <String>[
      ..._inspeccion.map((p) => p.codigo),
      ..._palpacion.map((p) => p.codigo),
      'FAV-08',
    ];

    if (principales.any((codigo) => !_respuestas.containsKey(codigo))) {
      return false;
    }

    // FAV-02a solo aplica si FAV-02 = Sí.
    if (_respuestas['FAV-02'] == 'SI' &&
        !_respuestas.containsKey('FAV-02-COND')) {
      return false;
    }

    // FAV-06a solo aplica si FAV-06 = Sí.
    if (_respuestas['FAV-06'] == 'SI' &&
        !_respuestas.containsKey('FAV-06-COND')) {
      return false;
    }

    return true;
  }

  void _seleccionarRespuesta(String codigo, String valor) {
    if (_resultadoMostrado || _resultado != null) return;

    setState(() {
      _respuestas[codigo] = valor;

      // Se conserva la lógica CVC: si el apósito está íntegro (Sí),
      // los ítems CVC-02 a CVC-07 dejan de aplicar.
      if (codigo == 'CVC-01' && valor == 'SI') {
        for (var numero = 2; numero <= 7; numero++) {
          _respuestas.remove('CVC-${numero.toString().padLeft(2, '0')}');
        }
      }

      // Al responder No en una pregunta principal, su condicional deja de
      // aplicar y se elimina solo de la memoria de esta pantalla.
      if (valor == 'NO') {
        if (codigo == 'FAV-02' || codigo == 'FAV-06') {
          _respuestas.remove('$codigo-COND');
        }
      }
    });
  }

  void _finalizarValoracionDePrueba() {
    if (!_respuestasCompletas || _resultadoMostrado) return;

    // Cada tipo de acceso utiliza exclusivamente sus propios criterios.
    final clasificacionFAV = _esCvc ? null : _clasificarFAV();
    final clasificacionCVC = _esCvc ? _clasificarCVC() : null;

    setState(() {
      _resultadoMostrado = true;
      _fechaHoraResultado = DateTime.now();
      _clasificacionFAV = clasificacionFAV;
      _clasificacionCVC = clasificacionCVC;
      _errorGuardado = null;
    });
  }

  _ClasificacionFAV _clasificarFAV() {
    final hallazgos = <_HallazgoFAV>[];

    void agregarRojo(String texto, String recomendacion) {
      hallazgos.add(
        _HallazgoFAV(
          nivelAlerta: 'ROJA',
          textoHallazgo: texto,
          recomendacion: recomendacion,
        ),
      );
    }

    void agregarAmarillo(
      String texto,
      String recomendacion, {
      bool recomendacionPendiente = false,
    }) {
      hallazgos.add(
        _HallazgoFAV(
          nivelAlerta: 'AMARILLA',
          textoHallazgo: texto,
          recomendacion: recomendacion,
          recomendacionPendiente: recomendacionPendiente,
        ),
      );
    }

    // FAV-01: sangrado activo -> ROJA.
    if (_respuestas['FAV-01'] == 'SI') {
      agregarRojo(
        'Hay sangrado activo en el acceso o en una zona de punción.',
        'Active de inmediato la ruta institucional para controlar el sangrado y solicite valoración clínica urgente. Siga el protocolo institucional.',
      );
    }

    // FAV-02 + FAV-02a: lesión cutánea sin signos acompañantes -> AMARILLA;
    // con dolor, malestar general o extensión rápida -> ROJA.
    // La infografía aprobada utiliza "dolor" en la pregunta condicional,
    // por lo que el texto del hallazgo refleja esa misma condición.
    if (_respuestas['FAV-02'] == 'SI') {
      if (_respuestas['FAV-02-COND'] == 'SI') {
        agregarRojo(
          'La alteración de la piel se acompaña de dolor, malestar general o extensión rápida.',
          'Solicite valoración clínica urgente y active la ruta institucional correspondiente. Informe los signos acompañantes.',
        );
      } else if (_respuestas['FAV-02-COND'] == 'NO') {
        agregarAmarillo(
          'Se observa enrojecimiento, secreción, heridas o lesiones en la piel del acceso, sin dolor, malestar general ni extensión rápida reportados en la pregunta condicional.',
          'Comunique el hallazgo al equipo responsable y solicite valoración clínica oportuna. Vigile si aumenta la lesión, el dolor o la secreción.',
        );
      }
    }

    // FAV-03: edema con dolor intenso o cambios importantes de color/temperatura.
    if (_respuestas['FAV-03'] == 'SI') {
      agregarRojo(
        'Hay edema en el brazo o la mano del lado del acceso, acompañado de dolor intenso o cambios importantes de color o temperatura.',
        'Solicite valoración clínica urgente por posible compromiso vascular. Evite comprimir o manipular innecesariamente el miembro.',
      );
    }

    // FAV-04: dilataciones/abultamientos con signos de riesgo.
    if (_respuestas['FAV-04'] == 'SI') {
      agregarRojo(
        'Hay dilataciones o abultamientos prominentes del acceso con piel adelgazada o brillante, costra, úlcera, lesión o sangrado.',
        'Solicite valoración clínica urgente y proteja el acceso de golpes, presión o manipulación innecesaria. Si hay sangrado activo, active la ruta institucional para control del sangrado.',
      );
    }

    // FAV-05: alteraciones de la mano con síntomas asociados.
    if (_respuestas['FAV-05'] == 'SI') {
      agregarRojo(
        'La mano presenta palidez, color azulado o frialdad marcada, junto con dolor en reposo, pérdida de sensibilidad, adormecimiento, hormigueo o debilidad.',
        'Comunique el hallazgo de forma prioritaria y gestione valoración clínica. Si los síntomas son súbitos, intensos o progresivos, solicite valoración urgente según la ruta institucional.',
      );
    }

    // FAV-06 + FAV-06a: apósito compresivo de más de 24 horas -> AMARILLA.
    // Recomendación incorporada según la confirmación de enfermería.
    if (_respuestas['FAV-06'] == 'SI' &&
        _respuestas['FAV-06-COND'] == 'SI') {
      agregarAmarillo(
        'Hay apósitos compresivos en las zonas de punción después de la sesión de hemodiálisis que llevan más de 24 horas colocados.',
        'Verifique que no haya sangrado en las zonas de punción y retire cuidadosamente los apósitos compresivos, de acuerdo con el protocolo institucional. Si identifica sangrado, realice compresión directa según el protocolo, vigile el control del sangrado o cambios de perfusión, evite mantener compresión innecesaria y notifique al equipo responsable.',
      );
    }

    // FAV-07: ausencia de frémito -> ROJA.
    if (_respuestas['FAV-07'] == 'NO') {
      agregarRojo(
        'No se identifica frémito (vibración) al palpar suavemente la FAV o el injerto.',
        'Solicite valoración clínica urgente del acceso y comunique de inmediato la ausencia de frémito. No intente restablecerlo mediante manipulaciones.',
      );
    }

    // FAV-08: ausencia de soplo -> ROJA.
    if (_respuestas['FAV-08'] == 'NO') {
      agregarRojo(
        'No se identifica soplo sobre la FAV o el injerto mediante auscultación.',
        'Solicite valoración clínica urgente del acceso y comunique de inmediato la ausencia de soplo.',
      );
    }

    // Prioridad global: ROJA > AMARILLA > VERDE. Se conservan todos los
    // hallazgos activados aunque el color final sea rojo.
    final tieneRojo = hallazgos.any((h) => h.nivelAlerta == 'ROJA');
    final tieneAmarillo = hallazgos.any((h) => h.nivelAlerta == 'AMARILLA');

    final nivel = tieneRojo
        ? 'ROJA'
        : tieneAmarillo
            ? 'AMARILLA'
            : 'VERDE';

    return _ClasificacionFAV(
      nivelAlerta: nivel,
      hallazgos: hallazgos,
    );
  }

  _ClasificacionCVC _clasificarCVC() {
    final hallazgos = <_HallazgoCVC>[];

    void agregarRojo(String texto, String recomendacion) {
      hallazgos.add(
        _HallazgoCVC(
          nivelAlerta: 'ROJA',
          textoHallazgo: texto,
          recomendacion: recomendacion,
        ),
      );
    }

    void agregarAmarillo(String texto, String recomendacion) {
      hallazgos.add(
        _HallazgoCVC(
          nivelAlerta: 'AMARILLA',
          textoHallazgo: texto,
          recomendacion: recomendacion,
        ),
      );
    }

    final apositoNoIntegro = _respuestas['CVC-01'] == 'NO';

    // Ítems 2–7 solo aplican cuando CVC-01 = NO.
    if (apositoNoIntegro) {
      if (_respuestas['CVC-02'] == 'NO') {
        agregarRojo(
          'El apósito del catéter se encuentra desprendido o no está íntegro. '
          'El sitio de inserción o el orificio de salida presenta alguna '
          'alteración, como eritema, exudado, suciedad o dolor.',
          'Informe inmediatamente al equipo responsable y solicite valoración '
          'clínica urgente. Mantenga protegido el sitio y gestione el cambio '
          'del apósito con técnica estéril por personal de diálisis, Si no hay '
          'personal de diálisis disponible, realice el cambio con técnica '
          'estéril únicamente si cuenta con la competencia y autorización '
          'institucional, siguiendo el protocolo.',
        );
      }

      if (_respuestas['CVC-03'] == 'NO') {
        agregarRojo(
          'El apósito del catéter se encuentra desprendido o no está íntegro. '
          'Las aletas de fijación no están intactas.',
          'Informe inmediatamente al equipo responsable. Evite traccionar, '
          'movilizar o reposicionar el catéter. Mantenga protegido el sitio y '
          'gestione el cambio del apósito con técnica estéril por personal de '
          'diálisis. Si no hay personal de diálisis disponible, realice el '
          'cambio con técnica estéril únicamente si cuenta con la competencia '
          'y autorización institucional, siguiendo el protocolo.',
        );
      }

      if (_respuestas['CVC-04'] == 'NO') {
        agregarRojo(
          'El apósito del catéter se encuentra desprendido o no está íntegro. '
          'Las conexiones no están firmes o presentan fugas.',
          'Informe inmediatamente al equipo responsable y active la ruta '
          'institucional correspondiente. Aplique las medidas de seguridad '
          'del protocolo para controlar los riesgos de sangrado, entrada de '
          'aire y contaminación. Mantenga protegido el sitio y gestione el '
          'cambio del apósito con técnica estéril por personal de diálisis, '
          'Si no hay personal de diálisis disponible, realice el cambio con '
          'técnica estéril únicamente si cuenta con la competencia y '
          'autorización institucional, siguiendo el protocolo.',
        );
      }

      if (_respuestas['CVC-05'] == 'NO') {
        agregarRojo(
          'El apósito del catéter se encuentra desprendido o no está íntegro. '
          'Los tapones o clamps no se encuentran en buen estado.',
          'Informe inmediatamente al equipo responsable. Aplique las medidas '
          'de seguridad institucionales para prevenir fugas, sangrado y '
          'contaminación. Mantenga protegido el sitio y gestione el cambio '
          'del apósito con técnica estéril por personal de diálisis, Si no '
          'hay personal de diálisis disponible, realice el cambio con técnica '
          'estéril únicamente si cuenta con la competencia y autorización '
          'institucional, siguiendo el protocolo.',
        );
      }

      if (_respuestas['CVC-06'] == 'NO') {
        agregarRojo(
          'El apósito del catéter se encuentra desprendido o no está íntegro. '
          'Las líneas presentan grietas, oclusiones o pinzamientos.',
          'Informe inmediatamente al equipo responsable. No utilice líneas '
          'deterioradas ni intente corregir una oclusión mediante maniobras '
          'no autorizadas. Mantenga protegido el sitio y gestione el cambio '
          'del apósito con técnica estéril por personal de diálisis, Si no '
          'hay personal de diálisis disponible, realice el cambio con técnica '
          'estéril únicamente si cuenta con la competencia y autorización '
          'institucional, siguiendo el protocolo.',
        );
      }

      if (_respuestas['CVC-07'] == 'SI') {
        agregarRojo(
          'El apósito del catéter se encuentra desprendido o no está íntegro. '
          'Se identifica desplazamiento, tracción o salida accidental del '
          'catéter.',
          'Informe inmediatamente al equipo responsable. No avance, '
          'reintroduzca ni intente reposicionar el catéter. Protéjalo para '
          'prevenir tracciones adicionales y aplique las medidas '
          'institucionales correspondientes.',
        );
      }

    }

    // Los ítems 8–11 se evalúan independientemente del estado del apósito.
    if (_respuestas['CVC-08'] == 'SI') {
      agregarRojo(
        'El paciente presenta dolor en el sitio de inserción del catéter.',
        'Valore el dolor y el sitio de inserción. Informe inmediatamente al '
        'equipo responsable y solicite valoración clínica urgente. Vigile '
        'otros signos locales o sistémicos y registre las intervenciones.',
      );
    }

    if (_respuestas['CVC-09'] == 'SI') {
      agregarRojo(
        'El paciente presenta fiebre y escalofríos en presencia de un catéter '
        'venoso central para diálisis.',
        'Valore inmediatamente el estado clínico y los signos vitales. '
        'Informe al equipo médico y active la ruta institucional de atención '
        'urgente. Vigile la evolución y registre los hallazgos.',
      );
    }

    if (_respuestas['CVC-10'] == 'SI') {
      agregarRojo(
        'Se identifica tumefacción en el cuello, tórax, brazo o pierna del '
        'lado donde se encuentra el catéter.',
        'Informe inmediatamente al equipo médico y solicite valoración '
        'urgente. Valore la localización y extensión de la tumefacción y '
        'vigile otros cambios clínicos.',
      );
    }

    if (_respuestas['CVC-11'] == 'SI') {
      agregarRojo(
        'El paciente presenta sangrado persistente o abundante asociado al '
        'catéter venoso central.',
        'Atienda inmediatamente el sangrado, valore el estado hemodinámico y '
        'active la ruta institucional de atención urgente. Aplique las '
        'medidas de control del sangrado establecidas en el protocolo.',
      );
    }

    // El hallazgo amarillo del apósito se conserva en el compendio aunque
    // exista además un criterio rojo independiente en los ítems 8–11.
    // Se agrega después de los hallazgos rojos para priorizar su lectura.
    final cateterSinHallazgosRojos =
        apositoNoIntegro &&
        _respuestas['CVC-02'] == 'SI' &&
        _respuestas['CVC-03'] == 'SI' &&
        _respuestas['CVC-04'] == 'SI' &&
        _respuestas['CVC-05'] == 'SI' &&
        _respuestas['CVC-06'] == 'SI' &&
        _respuestas['CVC-07'] == 'NO';

    if (cateterSinHallazgosRojos) {
      agregarAmarillo(
        'El apósito del catéter se encuentra desprendido o no está íntegro.',
        'Verifique que no haya sangrado. Solicite el cambio del apósito por '
        'personal encargado de díalisis. Si no hay personal de diálisis '
        'disponible, realice el cambio con técnica estéril únicamente si '
        'cuenta con la competencia y autorización institucional, siguiendo '
        'el protocolo. Informe al equipo responsable y registre la '
        'intervención.',
      );
    }

    // Prioridad global: ROJA > AMARILLA > VERDE.
    final tieneRojo = hallazgos.any((h) => h.nivelAlerta == 'ROJA');
    final tieneAmarillo = hallazgos.any((h) => h.nivelAlerta == 'AMARILLA');
    final nivel = tieneRojo
        ? 'ROJA'
        : tieneAmarillo
            ? 'AMARILLA'
            : 'VERDE';

    return _ClasificacionCVC(
      nivelAlerta: nivel,
      hallazgos: hallazgos,
    );
  }

  /// Construye un resumen local con los hallazgos y recomendaciones activados.
  /// No serializa ni persiste las respuestas individuales del checklist.
  String _crearResumenChecklist() {
    final resumen = StringBuffer();

    if (_esCvc) {
      final clasificacion = _clasificacionCVC;
      if (clasificacion == null) {
        return 'No hay un resumen disponible para este checklist CVC.';
      }

      resumen.writeln('Checklist CVC');
      resumen.writeln('Nivel de alerta: ${clasificacion.nivelAlerta}');
      resumen.writeln();

      if (clasificacion.hallazgos.isEmpty) {
        resumen.write(
          'No se identificaron hallazgos de alerta en los criterios evaluados.',
        );
      } else {
        resumen.writeln('Hallazgos y recomendaciones:');
        resumen.writeln();
        for (final hallazgo in clasificacion.hallazgos) {
          resumen.writeln('• [${hallazgo.nivelAlerta}] ${hallazgo.textoHallazgo}');
          resumen.writeln('  Recomendación: ${hallazgo.recomendacion}');
          resumen.writeln();
        }
      }
    } else {
      final clasificacion = _clasificacionFAV;
      if (clasificacion == null) {
        return 'No hay un resumen disponible para este checklist FAV / injerto.';
      }

      resumen.writeln('Checklist FAV / injerto');
      resumen.writeln('Nivel de alerta: ${clasificacion.nivelAlerta}');
      resumen.writeln();

      if (clasificacion.hallazgos.isEmpty) {
        resumen.write(
          'No se identificaron hallazgos de alerta en los criterios evaluados.',
        );
      } else {
        resumen.writeln('Hallazgos y recomendaciones:');
        resumen.writeln();
        for (final hallazgo in clasificacion.hallazgos) {
          resumen.writeln('• [${hallazgo.nivelAlerta}] ${hallazgo.textoHallazgo}');
          resumen.writeln('  Recomendación: ${hallazgo.recomendacion}');
          resumen.writeln();
        }
      }
    }

    return resumen.toString().trim();
  }

  Future<void> _guardarResultadoDePrueba() async {
    if (!_resultadoMostrado || _fechaHoraResultado == null || _guardando) {
      return;
    }

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });

    final comentario = _comentarioController.text.trim();
    final nivelCalculado = _esCvc
        ? (_clasificacionCVC?.nivelAlerta ?? 'VERDE')
        : (_clasificacionFAV?.nivelAlerta ?? 'VERDE');
    final resumenChecklist = _crearResumenChecklist();

    final resultadoTemporal = ResultadoChecklistPrueba(
      codigoQr: widget.codigoQr,
      tipoAcceso: widget.tipoAcceso,
      nivelAlerta: nivelCalculado,
      fechaHoraAtencion: _fechaHoraResultado!,
      comentario: comentario,
      esPrueba: false,
    );

    try {
      final idLocal = await AlertaDatabase.instance.guardarAlerta(
        AlertaRegistro(
          codigoQr: resultadoTemporal.codigoQr,
          tipoAcceso: resultadoTemporal.tipoAcceso,
          nivelAlerta: resultadoTemporal.nivelAlerta,
          fechaHoraAtencion: resultadoTemporal.fechaHoraAtencion,
          comentario: resultadoTemporal.comentario,
          resumenChecklist: resumenChecklist,
          // Se conserva localmente para etiquetar el comentario enviado
          // cuando el QR MIX9 representa dos accesos distintos.
          tipoChecklist: _esCvc ? 'CVC' : 'FAV',
          esPrueba: false,
          estadoSincronizacion: EstadoSincronizacion.pendiente,
        ),
      );

      if (!mounted) return;
      setState(() {
        // Al guardar el resultado final, se descartan las respuestas de la
        // memoria de esta pantalla. Nunca se escribieron en SQLite.
        _respuestas.clear();
        _resultado = resultadoTemporal.copyWith(idLocal: idLocal);
        _guardando = false;
      });

      // Intenta sincronizar inmediatamente el nuevo registro real. Si el
      // teléfono no tiene conexión o Django no responde, SQLite lo conserva
      // como pendiente y el servicio volverá a intentarlo automáticamente.
      unawaited(AlertaSyncService.instance.sincronizarPendientes());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado =
            'No se pudo guardar el registro en el dispositivo. '
            'Inténtalo de nuevo. Detalle: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esCvc ? 'Checklist CVC' : 'Checklist FAV / AVG',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
              children: [
                _encabezadoAcceso(),
                const SizedBox(height: 14),
                if (_esCvc) ...[
                  _guiaVisualCvc(),
                  const SizedBox(height: 16),
                  _progreso(),
                  const SizedBox(height: 20),
                  _seccionCvcAposito(),
                  if (_respuestas.containsKey('CVC-01')) ...[
                    if (_respuestas['CVC-01'] == 'NO') ...[
                      const SizedBox(height: 18),
                      _seccionCvcCateter(),
                    ],
                    const SizedBox(height: 18),
                    _seccionCvcPaciente(),
                  ],
                ] else ...[
                  _progreso(),
                  const SizedBox(height: 20),
                  _seccion(
                    letra: 'A',
                    titulo: 'INSPECCIÓN',
                    subtitulo: 'Piel, punciones y extremidad',
                    color: const Color(0xFF149B78),
                    fondo: const Color(0xFFE9F8F2),
                    icono: Icons.visibility_rounded,
                    preguntas: _inspeccion,
                  ),
                  const SizedBox(height: 18),
                  _seccion(
                    letra: 'B',
                    titulo: 'PALPACIÓN',
                    subtitulo: 'Frémito y vibración del acceso',
                    color: const Color(0xFFB77900),
                    fondo: const Color(0xFFFFF6D8),
                    icono: Icons.back_hand_rounded,
                    preguntas: _palpacion,
                  ),
                  const SizedBox(height: 18),
                  _seccionAuscultacion(),
                ],
                const SizedBox(height: 22),
                if (!_resultadoMostrado && _resultado == null) ...[
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _respuestasCompletas
                          ? _finalizarValoracionDePrueba
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _azulOscuro,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFD8E1E7),
                        disabledForegroundColor: const Color(0xFF70818B),
                        elevation: _respuestasCompletas ? 4 : 0,
                        shadowColor: const Color(0x6618364A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.checklist_rounded),
                      label: const Text(
                        'FINALIZAR CHECKLIST',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  if (!_respuestasCompletas) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: _textoSuave,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _esCvc
                                ? 'Responde las preguntas que apliquen según el apósito y la valoración del paciente.'
                                : 'Responde todas las preguntas y las adicionales que aparezcan.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _textoSuave,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                if (_resultadoMostrado || _resultado != null) ...[
                  const SizedBox(height: 2),
                  _AparicionSuave(child: _resultadoDePrueba()),
                  const SizedBox(height: 16),
                  _campoComentario(),
                  const SizedBox(height: 16),
                  if (_resultado == null) ...[
                    if (_errorGuardado != null) ...[
                      _mensajeError(_errorGuardado!),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _guardando ? null : _guardarResultadoDePrueba,
                        style: FilledButton.styleFrom(
                          backgroundColor: _turquesa,
                          foregroundColor: Colors.white,
                          elevation: _guardando ? 0 : 4,
                          shadowColor: const Color(0x66087E8B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _guardando
                              ? 'GUARDANDO...'
                              : (_esCvc
                                  ? 'GUARDAR VALORACIÓN'
                                  : 'GUARDAR VALORACIÓN'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7ED),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFB8E3C0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _verde.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_done_rounded,
                              color: _verde,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Registro guardado en el dispositivo. Se intentará sincronizar automáticamente cuando haya conexión con el servidor.',
                              style: TextStyle(
                                color: Color(0xFF1D6B32),
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(_resultado),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text(
                          'VOLVER AL CONTENIDO EDUCATIVO',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ENCABEZADO Y PROGRESO
  // ============================================================

  Widget _encabezadoAcceso() {
    final ubicacion = _ubicacionDesdeQr(widget.codigoQr);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A74C2), Color(0xFF4268B0), Color(0xFF284B86)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x334268B0),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -35,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -55,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACCESO IDENTIFICADO',
                        style: TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tipoAcceso,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chipEncabezado(Icons.location_on_rounded, ubicacion),
                          _chipEncabezado(
                            Icons.tag_rounded,
                            widget.codigoQr,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipEncabezado(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progreso() {
    final respondidas = _preguntasPrincipalesRespondidas;
    final total = _totalPreguntasPrincipales;
    final avance = total > 0 ? (respondidas / total).clamp(0.0, 1.0) : 0.0;
    final completo = total > 0 && respondidas >= total;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borde),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F18364A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (completo ? _verde : _turquesa)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  completo
                      ? Icons.task_alt_rounded
                      : Icons.checklist_rounded,
                  color: completo ? _verde : _turquesa,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Progreso',
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$respondidas de $total',
                style: TextStyle(
                  color: completo ? _verde : _turquesa,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: avance),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, valor, _) => LinearProgressIndicator(
                value: valor,
                minHeight: 9,
                backgroundColor: _turquesa.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  completo ? _verde : _turquesa,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GUÍA VISUAL CVC
  // ============================================================

  Widget _guiaVisualCvc() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB8DDEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1218364A),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1767A5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    color: Color(0xFF1767A5),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guía visual del CVC',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Identifica las partes del catéter',
                        style: TextStyle(
                          color: _textoSuave,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ampliar imagen',
                  onPressed: _mostrarGuiaCvcAmpliada,
                  icon: const Icon(Icons.open_in_full_rounded),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _mostrarGuiaCvcAmpliada,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FCFE), Color(0xFFEAF4FA)],
                ),
              ),
              child: Image.asset(
                'assets/images/CheckList_CVC.png',
                height: 240,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No se pudo cargar CheckList_CVC.png. Verifica que el archivo esté en assets/images y registrado en pubspec.yaml.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFB4232C), height: 1.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarGuiaCvcAmpliada() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.asset(
                  'assets/images/CheckList_CVC.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No se pudo cargar la guía visual del CVC.'),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton.filledTonal(
                tooltip: 'Cerrar imagen',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECCIONES CVC
  // ============================================================

  Widget _seccionCvcAposito() {
    return _seccionCvc(
      numero: '1',
      titulo: 'SITIO DE INSERCIÓN Y APÓSITO',
      subtitulo: 'Evalúa el apósito antes de continuar',
      color: const Color(0xFF1767A5),
      fondo: const Color(0xFFEAF5FF),
      icono: Icons.medical_services_rounded,
      preguntas: const [_cvcAposito],
    );
  }

  Widget _seccionCvcCateter() {
    return _seccionCvc(
      numero: '2',
      titulo: 'VALORACIÓN DEL CATÉTER',
      subtitulo: 'Solo si el apósito responde No',
      color: const Color(0xFF0B887E),
      fondo: const Color(0xFFE9F8F5),
      icono: Icons.water_drop_rounded,
      preguntas: _cvcValoracionCateter,
      aviso: 'Apósito no íntegro: completa los ítems 2 al 7.',
    );
  }

  Widget _seccionCvcPaciente() {
    return _seccionCvc(
      numero: '3',
      titulo: 'VALORACIÓN DEL PACIENTE',
      subtitulo: 'Síntomas y signos a registrar',
      color: const Color(0xFF5141A5),
      fondo: const Color(0xFFF0EEFF),
      icono: Icons.person_rounded,
      preguntas: _cvcValoracionPaciente,
    );
  }

  Widget _seccionCvc({
    required String numero,
    required String titulo,
    required String subtitulo,
    required Color color,
    required Color fondo,
    required IconData icono,
    required List<_PreguntaChecklist> preguntas,
    String? aviso,
  }) {
    return _AparicionSuave(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _encabezadoSeccion(
              marca: numero,
              circular: true,
              titulo: titulo,
              subtitulo: subtitulo,
              color: color,
              icono: icono,
              preguntas: preguntas,
            ),
            const SizedBox(height: 14),
            if (aviso != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: color, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        aviso,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ...preguntas.map((pregunta) => _tarjetaPregunta(pregunta, color)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECCIONES FAV / AVG
  // ============================================================

  Widget _seccion({
    required String letra,
    required String titulo,
    required String subtitulo,
    required Color color,
    required Color fondo,
    required IconData icono,
    required List<_PreguntaChecklist> preguntas,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezadoSeccion(
            marca: letra,
            circular: false,
            titulo: titulo,
            subtitulo: subtitulo,
            color: color,
            icono: icono,
            preguntas: preguntas,
          ),
          const SizedBox(height: 14),
          ...preguntas.map((pregunta) => _tarjetaPregunta(pregunta, color)),
          if (letra == 'B')
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1C2),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    size: 17,
                    color: Color(0xFF765500),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Palpe suavemente el acceso. No lo comprima ni realice maniobras para modificar su flujo.',
                      style: TextStyle(
                        color: Color(0xFF765500),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _seccionAuscultacion() {
    const color = Color(0xFF1683C5);
    const fondo = Color(0xFFEAF6FF);
    const pregunta = _PreguntaChecklist(
      codigo: 'FAV-08',
      pregunta:
          '¿Se identifica soplo sobre la FAV o el injerto mediante auscultación?',
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezadoSeccion(
            marca: 'C',
            circular: false,
            titulo: 'AUSCULTACIÓN',
            subtitulo: 'Soplo del acceso',
            color: color,
            icono: Icons.medical_services_rounded,
            preguntas: const [pregunta],
          ),
          const SizedBox(height: 14),
          _tarjetaPregunta(pregunta, color, opciones: _siNo),
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 2, 2, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hearing_rounded, size: 16, color: _textoSuave),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Ausculte con un fonendoscopio e identifique si hay soplo.',
                    style: TextStyle(
                      color: _textoSuave,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Encabezado común de sección: marca (letra/número), título, subtítulo,
  /// icono y contador de preguntas respondidas dentro de la sección.
  Widget _encabezadoSeccion({
    required String marca,
    required bool circular,
    required String titulo,
    required String subtitulo,
    required Color color,
    required IconData icono,
    required List<_PreguntaChecklist> preguntas,
  }) {
    final respondidas =
        preguntas.where((p) => _respuestas.containsKey(p.codigo)).length;
    final completa = respondidas == preguntas.length;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.85), color],
            ),
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular ? null : BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            marca,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: color,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: const TextStyle(color: _textoSuave, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: completa ? color : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                completa ? Icons.check_rounded : icono,
                size: 14,
                color: completa ? Colors.white : color,
              ),
              const SizedBox(width: 4),
              Text(
                '$respondidas/${preguntas.length}',
                style: TextStyle(
                  color: completa ? Colors.white : color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PREGUNTAS Y RESPUESTAS
  // ============================================================

  Widget _tarjetaPregunta(
    _PreguntaChecklist pregunta,
    Color color, {
    List<_OpcionRespuesta>? opciones,
  }) {
    final respuestas = opciones ?? _siNo;
    final respondida = _respuestas.containsKey(pregunta.codigo);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: respondida ? color.withValues(alpha: 0.55) : _borde,
          width: respondida ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (respondida ? color : _azulOscuro).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pregunta.codigo,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    pregunta.pregunta,
                    style: const TextStyle(
                      color: _azulOscuro,
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (respondida) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, color: color, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 13),
          _opcionesRespuesta(pregunta.codigo, respuestas, color),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _respuestas[pregunta.codigo] == 'SI'
                ? _bloqueCondicional(pregunta.codigo, color)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _bloqueCondicional(String codigoPrincipal, Color color) {
    switch (codigoPrincipal) {
      case 'FAV-02':
        return _preguntaCondicional(
          codigo: 'FAV-02-COND',
          pregunta:
              '¿El enrojecimiento, la secreción o la lesión se acompaña de dolor, malestar general o extensión rápida?',
          opciones: _siNo,
          color: color,
        );
      case 'FAV-06':
        return _preguntaCondicional(
          codigo: 'FAV-06-COND',
          pregunta:
              '¿Los apósitos compresivos llevan más de 24 horas colocados?',
          opciones: _siNo,
          color: color,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _preguntaCondicional({
    required String codigo,
    required String pregunta,
    required List<_OpcionRespuesta> opciones,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.subdirectory_arrow_right_rounded,
                        size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      'PREGUNTA ADICIONAL',
                      style: TextStyle(
                        color: color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            pregunta,
            style: const TextStyle(
              color: _azulOscuro,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 11),
          _opcionesRespuesta(codigo, opciones, color),
        ],
      ),
    );
  }

  Widget _opcionesRespuesta(
    String codigo,
    List<_OpcionRespuesta> opciones,
    Color color,
  ) {
    final seleccionada = _respuestas[codigo];
    final bloqueado = _resultadoMostrado || _resultado != null;
    // IntrinsicHeight evita el error de altura infinita al usar stretch
    // dentro de una lista con scroll y mantiene los botones del mismo alto.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < opciones.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _BotonOpcion(
                etiqueta: opciones[i].etiqueta,
                activa: seleccionada == opciones[i].valor,
                color: color,
                onTap: bloqueado
                    ? null
                    : () => _seleccionarRespuesta(codigo, opciones[i].valor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // RESULTADO, COMENTARIO Y ERRORES
  // ============================================================

  Widget _resultadoDePrueba() {
    final fechaHora =
        _resultado?.fechaHoraAtencion ?? _fechaHoraResultado;
    final clasificacionFAV = _clasificacionFAV;
    final clasificacionCVC = _clasificacionCVC;
    final nivel = _esCvc
        ? (clasificacionCVC?.nivelAlerta ?? 'VERDE')
        : (clasificacionFAV?.nivelAlerta ?? 'VERDE');
    final estilo = _estiloNivel(nivel);

    final niveles = _esCvc
        ? (clasificacionCVC?.hallazgos.map((h) => h.nivelAlerta).toList() ??
            <String>[])
        : (clasificacionFAV?.hallazgos.map((h) => h.nivelAlerta).toList() ??
            <String>[]);
    final rojos = niveles.where((n) => n == 'ROJA').length;
    final amarillos = niveles.where((n) => n == 'AMARILLA').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: estilo.color.withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: estilo.color.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen solicitada por enfermería para el cierre de ambos checklist.
          // Se conserva la proporción completa, sin recortar el contenido.
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF5F9FB),
              child: Image.asset(
                'assets/images/Finalizacion.png',
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6E5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.image_not_supported_outlined,
                            color: Color(0xFF986600)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No se pudo cargar Finalizacion.png. Comprueba que exista en assets/images/ y que esté declarada en pubspec.yaml.',
                            style: TextStyle(
                              color: Color(0xFF795400),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(Icons.fact_check_rounded, color: _turquesa, size: 22),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Resumen de la valoración',
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borde),
            ),
            child: Column(
              children: [
                _filaResumen(
                  Icons.tag_rounded,
                  'Identificador QR',
                  widget.codigoQr,
                ),
                const Divider(height: 22, color: _borde),
                _filaResumen(
                  Icons.medical_services_outlined,
                  'Tipo de acceso',
                  widget.tipoAcceso,
                ),
                const Divider(height: 22, color: _borde),
                _filaResumen(
                  Icons.calendar_month_outlined,
                  'Fecha y hora de atención',
                  fechaHora == null ? 'Pendiente' : _formatearFecha(fechaHora),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _bannerNivel(estilo),
          if (rojos > 0 || amarillos > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (rojos > 0)
                  _chipConteo(
                    rojos,
                    rojos == 1 ? 'hallazgo en rojo' : 'hallazgos en rojo',
                    const Color(0xFFC62828),
                    const Color(0xFFFFEBEE),
                  ),
                if (amarillos > 0)
                  _chipConteo(
                    amarillos,
                    amarillos == 1
                        ? 'hallazgo en amarillo'
                        : 'hallazgos en amarillo',
                    const Color(0xFF9A6700),
                    const Color(0xFFFFF5D9),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (_esCvc && clasificacionCVC != null) ...[
            _compendioCVC(clasificacionCVC),
          ] else if (!_esCvc && clasificacionFAV != null) ...[
            _compendioFAV(clasificacionFAV),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: _turquesa, size: 18),
                    SizedBox(width: 7),
                    Text(
                      'COMENTARIO',
                      style: TextStyle(
                        color: _textoSuave,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _comentarioController,
                  builder: (context, value, child) {
                    final comentario = value.text.trim();
                    return Text(
                      comentario.isEmpty ? 'Sin comentarios.' : comentario,
                      style: TextStyle(
                        color: comentario.isEmpty
                            ? _textoSuave
                            : _azulOscuro,
                        fontSize: 13,
                        height: 1.45,
                        fontStyle: comentario.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner de nivel de alerta con degradado, icono y círculos decorativos.
  Widget _bannerNivel(_EstiloNivel estilo) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: estilo.gradiente,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: estilo.color.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            right: 46,
            bottom: -48,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: estilo.colorCirculo,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    estilo.icono,
                    color: estilo.colorTexto,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    estilo.titulo,
                    style: TextStyle(
                      color: estilo.colorTexto,
                      fontSize: 15.5,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipConteo(int cantidad, String texto, Color color, Color fondo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            '$cantidad $texto',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compendioCVC(_ClasificacionCVC clasificacion) {
    if (clasificacion.nivelAlerta == 'VERDE') {
      return _compendioVerde(
        'No se identificaron hallazgos de alarma en los criterios evaluados. '
        'Continúe protegiendo el acceso vascular durante toda la atención: '
        'evite manipulaciones innecesarias; mantenga las medidas de higiene '
        'y protección del acceso según el protocolo institucional, vigile '
        'cambios. Si aparecen nuevos signos de alarma, volver a valorar y '
        'seguir la recomendación correspondiente.',
      );
    }

    return _listaCompendio([
      for (final h in clasificacion.hallazgos)
        _DatosCompendio(
          nivel: h.nivelAlerta,
          hallazgo: h.textoHallazgo,
          recomendacion: h.recomendacion,
        ),
    ]);
  }

  Widget _compendioFAV(_ClasificacionFAV clasificacion) {
    if (clasificacion.nivelAlerta == 'VERDE') {
      return _compendioVerde(
        'No se identificaron hallazgos de alarma en los criterios evaluados. '
        'Continúe protegiendo el acceso vascular durante toda la atención: '
        'evite compresiones, punciones o manipulaciones innecesarias; '
        'mantenga las medidas de higiene y protección del acceso según el '
        'protocolo institucional; y vigile cambios en la piel, dolor, '
        'temperatura, frémito o soplo. Si aparecen nuevos signos de alarma, '
        'volver a valorar y seguir la recomendación correspondiente.',
      );
    }

    return _listaCompendio([
      for (final h in clasificacion.hallazgos)
        _DatosCompendio(
          nivel: h.nivelAlerta,
          hallazgo: h.textoHallazgo,
          recomendacion: h.recomendacion,
          pendiente: h.recomendacionPendiente,
        ),
    ]);
  }

  Widget _compendioVerde(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB8E3C0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _verde.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: _verde,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: Color(0xFF1D6B32),
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lista de hallazgos y, a continuación, sus recomendaciones.
  Widget _listaCompendio(List<_DatosCompendio> datos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloCompendio(
          numero: '1',
          texto: 'HALLAZGOS IDENTIFICADOS',
          color: const Color(0xFFB77900),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < datos.length; i++) ...[
          _itemCompendio(
            numero: i + 1,
            titulo: 'Hallazgo ${i + 1}.',
            texto: datos[i].hallazgo,
            nivel: datos[i].nivel,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        _tituloCompendio(
          numero: '2',
          texto: 'RECOMENDACIONES',
          color: _turquesa,
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < datos.length; i++) ...[
          _itemCompendio(
            numero: i + 1,
            titulo: 'Recomendación para el hallazgo ${i + 1}.',
            texto: datos[i].recomendacion,
            nivel: datos[i].nivel,
            pendiente: datos[i].pendiente,
            esRecomendacion: true,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _tituloCompendio({
    required String numero,
    required String texto,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Text(
            numero,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemCompendio({
    required int numero,
    required String titulo,
    required String texto,
    required String nivel,
    bool pendiente = false,
    bool esRecomendacion = false,
  }) {
    final esRojo = nivel == 'ROJA';
    final color = esRojo ? const Color(0xFFC62828) : const Color(0xFF9A6700);
    final fondo = esRojo ? const Color(0xFFFFF1F1) : const Color(0xFFFFF8E5);
    final colorBorde =
        pendiente ? const Color(0xFFE5B567) : color.withValues(alpha: 0.25);

    final IconData icono = esRecomendacion
        ? Icons.lightbulb_outline_rounded
        : (esRojo ? Icons.error_outline_rounded : Icons.warning_amber_rounded);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pendiente ? const Color(0xFFFFF4E5) : fondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorde),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              color: pendiente ? const Color(0xFFE5B567) : color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            icono,
                            size: 18,
                            color: pendiente
                                ? const Color(0xFF744500)
                                : color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            titulo,
                            style: TextStyle(
                              color: pendiente
                                  ? const Color(0xFF744500)
                                  : color,
                              fontSize: 12.5,
                              height: 1.25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            esRojo ? 'ROJA' : 'AMARILLA',
                            style: TextStyle(
                              color: color,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      texto,
                      style: const TextStyle(
                        color: _azulOscuro,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    if (pendiente) ...[
                      const SizedBox(height: 7),
                      const Text(
                        'No se muestra una recomendación clínica hasta recibir la versión aprobada.',
                        style: TextStyle(
                          color: Color(0xFF744500),
                          fontSize: 11.5,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaResumen(IconData icono, String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _turquesa.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icono, size: 19, color: _turquesa),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta.toUpperCase(),
                style: const TextStyle(
                  color: _textoSuave,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _campoComentario() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borde),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F18364A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _turquesa.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    color: _turquesa, size: 20),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Comentario del enfermero',
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Opcional',
                  style: TextStyle(
                    color: _textoSuave,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comentarioController,
            enabled: _resultado == null,
            maxLines: 4,
            minLines: 3,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Observaciones adicionales sobre la valoración...',
              hintStyle: const TextStyle(color: Color(0xFF8A9AA6), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF7FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _borde),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _borde),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _turquesa, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensajeError(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7A8AE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB4232C),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                color: Color(0xFFB4232C),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatearFecha(DateTime valor) {
    final fecha = valor.toLocal();
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} · $hora:$minuto';
  }

  static String _ubicacionDesdeQr(String codigoQr) {
    final prefijo = codigoQr.toUpperCase().split('-').first;
    const ubicaciones = <String, String>{
      'FAV1': 'Brazo derecho',
      'FAV2': 'Brazo izquierdo',
      'FAV3': 'Miembro inferior derecho',
      'FAV4': 'Miembro inferior izquierdo',
      'CVC5': 'Yugular derecho',
      'CVC6': 'Yugular izquierdo',
      'CVC7': 'Femoral derecho',
      'CVC8': 'Femoral izquierdo',
      'MIX9': 'Dos accesos vasculares: FAV + CVC',
    };
    return ubicaciones[prefijo] ??
        'Ubicación no codificada en este QR anterior';
  }
}

// ============================================================
// APARICIÓN SUAVE (FUNDIDO + DESLIZAMIENTO, SOLO VISUAL)
// ============================================================

class _AparicionSuave extends StatelessWidget {
  final Widget child;

  const _AparicionSuave({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, valor, hijo) {
        return Opacity(
          opacity: valor,
          child: Transform.translate(
            offset: Offset(0, (1 - valor) * 14),
            child: hijo,
          ),
        );
      },
      child: child,
    );
  }
}

// ============================================================
// BOTÓN DE OPCIÓN (SÍ / NO / ETC.)
// ============================================================

class _BotonOpcion extends StatelessWidget {
  final String etiqueta;
  final bool activa;
  final Color color;
  final VoidCallback? onTap;

  const _BotonOpcion({
    required this.etiqueta,
    required this.activa,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: activa ? color : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: activa ? color : _borde,
              width: activa ? 1.5 : 1.2,
            ),
            boxShadow: activa
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activa) ...[
                const Icon(Icons.check_rounded, size: 17, color: Colors.white),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: activa ? Colors.white : _azulOscuro,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: activa ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CHECKLIST PENDIENTE (MIX9 / SIN CHECKLIST DISPONIBLE)
// ============================================================

class ChecklistPendienteScreen extends StatelessWidget {
  final String codigoQr;
  final String tipoAcceso;

  const ChecklistPendienteScreen({
    super.key,
    required this.codigoQr,
    required this.tipoAcceso,
  });

  @override
  Widget build(BuildContext context) {
    final esMixto = codigoQr.toUpperCase().startsWith('MIX9');
    return Scaffold(
      appBar: AppBar(title: const Text('Checklist de atención')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _AparicionSuave(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueGrey.withValues(alpha: 0.10),
                      ),
                      child: Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueGrey.withValues(alpha: 0.18),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.pending_actions_rounded,
                            size: 40,
                            color: Colors.blueGrey.shade500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      esMixto
                          ? 'Checklist para dos accesos pendiente'
                          : 'Checklist CVC pendiente',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _azulOscuro,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      esMixto
                          ? 'Este QR identifica una FAV y un CVC. El flujo para ambos accesos aún debe definirse con enfermería, por eso no se abre el checklist FAV como valoración completa.'
                          : 'El checklist de catéter venoso central se implementará por separado. Por ahora no genera ni guarda alertas.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _textoSuave,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _borde),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1018364A),
                            blurRadius: 18,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _turquesa.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'ID QR: $codigoQr',
                              style: const TextStyle(
                                color: _turquesa,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tipoAcceso,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text(
                          'VOLVER AL CONTENIDO EDUCATIVO',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreguntaChecklist {
  final String codigo;
  final String pregunta;

  const _PreguntaChecklist({
    required this.codigo,
    required this.pregunta,
  });
}

class _OpcionRespuesta {
  final String valor;
  final String etiqueta;

  const _OpcionRespuesta({required this.valor, required this.etiqueta});
}