import 'dart:async';

import 'package:flutter/material.dart';

import 'alerta_database.dart';
import 'alerta_sync_service.dart';
import 'alerta_model.dart';

// Colores de apoyo (solo visuales)
const Color _primario = Color(0xFF087E8B);
const Color _oscuro = Color(0xFF18364A);
const Color _textoSuave = Color(0xFF5B6E7C);
const Color _borde = Color(0xFFE1EAF0);

class HistorialAlertasScreen extends StatefulWidget {
  const HistorialAlertasScreen({super.key});

  @override
  State<HistorialAlertasScreen> createState() => _HistorialAlertasScreenState();
}

class _HistorialAlertasScreenState extends State<HistorialAlertasScreen> {
  List<AlertaRegistro> _alertas = [];
  int _pendientes = 0;
  bool _cargando = true;
  bool _soloPendientes = false;
  bool _sincronizando = false;
  String? _mensajeSincronizacion;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sincronizarPendientes(mostrarMensaje: false));
    });
  }

  Future<void> _sincronizarPendientes({bool mostrarMensaje = true}) async {
    if (_sincronizando) return;
    if (mounted) setState(() => _sincronizando = true);

    final resultado = await AlertaSyncService.instance.sincronizarPendientes();
    await _cargarDatos();
    if (!mounted) return;

    setState(() {
      _sincronizando = false;
      _mensajeSincronizacion = resultado.mensaje;
    });

    if (mostrarMensaje) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(resultado.mensaje)));
    }
  }

  Future<void> _cargarDatos() async {
    try {
      final alertas = await AlertaDatabase.instance.obtenerTodasLasAlertas();
      final pendientes =
          await AlertaDatabase.instance.contarPendientesDeSincronizacion();
      if (!mounted) return;
      setState(() {
        _alertas = alertas;
        _pendientes = pendientes;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo consultar la base de datos local: $e';
      });
    }
  }

  Color _colorAlerta(String nivel) {
    switch (nivel) {
      case 'VERDE':
        return const Color(0xFF238636);
      case 'AMARILLA':
        return const Color(0xFFB77900);
      default:
        return const Color(0xFFC62828);
    }
  }

  Color _fondoAlerta(String nivel) {
    switch (nivel) {
      case 'VERDE':
        return const Color(0xFFEAF7ED);
      case 'AMARILLA':
        return const Color(0xFFFFF5D9);
      default:
        return const Color(0xFFFFEBEE);
    }
  }

  void _mostrarDetalleAlerta(AlertaRegistro alerta) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetalleAlertaSheet(
        alerta: alerta,
        colorAlerta: _colorAlerta(alerta.nivelAlerta),
        fondoAlerta: _fondoAlerta(alerta.nivelAlerta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _soloPendientes
        ? _alertas.where((a) => a.estaPendiente).toList()
        : _alertas;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de alertas',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar historial',
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _MensajeEstado(
                    icono: Icons.error_outline_rounded,
                    titulo: 'No se pudo cargar el historial',
                    detalle: _error!,
                    accion: _cargarDatos,
                  )
                : RefreshIndicator(
                    onRefresh: _cargarDatos,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 850),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                          children: [
                            // RESUMEN + SINCRONIZACIÓN
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0A9AA8),
                                    Color(0xFF087E8B),
                                    Color(0xFF155E75),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primario.withValues(alpha: 0.22),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -40,
                                    top: -40,
                                    child: Container(
                                      width: 150,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white
                                            .withValues(alpha: 0.08),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.18),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: const Icon(
                                                Icons.cloud_upload_outlined,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'PENDIENTES DE SINCRONIZAR',
                                                    style: TextStyle(
                                                      color: Color(0xCCFFFFFF),
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '$_pendientes',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 36,
                                                      height: 1.1,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      letterSpacing: -0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _mensajeSincronizacion ??
                                              'Guardadas en este dispositivo. '
                                                  'Se enviarán cuando el '
                                                  'servidor esté disponible.',
                                          style: const TextStyle(
                                            color: Color(0xEBFFFFFF),
                                            fontSize: 12.5,
                                            height: 1.45,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: _sincronizando
                                                ? null
                                                : () =>
                                                    _sincronizarPendientes(),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: _primario,
                                              disabledBackgroundColor: Colors
                                                  .white
                                                  .withValues(alpha: 0.75),
                                              disabledForegroundColor:
                                                  _primario,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            icon: _sincronizando
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: _primario,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.cloud_upload_rounded,
                                                  ),
                                            label: Text(
                                              _sincronizando
                                                  ? 'Sincronizando alertas…'
                                                  : 'Sincronizar ahora',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // FILTROS
                            Row(
                              children: [
                                _ChipFiltro(
                                  seleccionado: !_soloPendientes,
                                  icono: Icons.list_alt_rounded,
                                  texto: 'Todas (${_alertas.length})',
                                  onTap: () =>
                                      setState(() => _soloPendientes = false),
                                ),
                                const SizedBox(width: 10),
                                _ChipFiltro(
                                  seleccionado: _soloPendientes,
                                  icono: Icons.schedule_rounded,
                                  texto: 'Pendientes ($_pendientes)',
                                  onTap: () =>
                                      setState(() => _soloPendientes = true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // LISTADO
                            if (visibles.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 30),
                                child: _MensajeEstado(
                                  icono: Icons.inbox_rounded,
                                  titulo: _soloPendientes
                                      ? 'No hay alertas pendientes'
                                      : 'Todavía no hay alertas guardadas',
                                  detalle: _soloPendientes
                                      ? 'Aparecerán aquí hasta que puedan '
                                          'sincronizarse.'
                                      : 'Completa un checklist para guardar '
                                          'el primer registro.',
                                ),
                              )
                            else
                              ...visibles.map(
                                (alerta) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _TarjetaAlerta(
                                    alerta: alerta,
                                    colorAlerta:
                                        _colorAlerta(alerta.nivelAlerta),
                                    fondoAlerta:
                                        _fondoAlerta(alerta.nivelAlerta),
                                    onTap: () => _mostrarDetalleAlerta(alerta),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  size: 16,
                                  color: _textoSuave,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Disponible sin internet. Las pendientes '
                                    'se pueden reintentar.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: _textoSuave,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}

// ============================================================
// CHIP DE FILTRO
// ============================================================

class _ChipFiltro extends StatelessWidget {
  final bool seleccionado;
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  const _ChipFiltro({
    required this.seleccionado,
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? _oscuro : Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: seleccionado ? _oscuro : _borde,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                size: 17,
                color: seleccionado ? Colors.white : _textoSuave,
              ),
              const SizedBox(width: 7),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: seleccionado ? Colors.white : _oscuro,
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
// TARJETA DE ALERTA
// ============================================================

class _TarjetaAlerta extends StatelessWidget {
  final AlertaRegistro alerta;
  final Color colorAlerta;
  final Color fondoAlerta;
  final VoidCallback onTap;

  const _TarjetaAlerta({
    required this.alerta,
    required this.colorAlerta,
    required this.fondoAlerta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sincronizada =
        alerta.estadoSincronizacion == EstadoSincronizacion.sincronizada;
    final estadoError = alerta.estadoSincronizacion == EstadoSincronizacion.error;
    final colorEstado = sincronizada
        ? const Color(0xFF238636)
        : estadoError
            ? const Color(0xFFC62828)
            : const Color(0xFF8A5A00);
    final textoEstado = sincronizada
        ? 'Sincronizada'
        : estadoError
            ? 'Pendiente · error anterior'
            : 'Pendiente de sincronización';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borde),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1418364A),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra lateral con el color del nivel de alerta
              Container(width: 6, color: colorAlerta),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: fondoAlerta,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              color: colorAlerta,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              alerta.codigoQr,
                              style: const TextStyle(
                                color: _oscuro,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: fondoAlerta,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colorAlerta,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  alerta.nivelAlerta,
                                  style: TextStyle(
                                    color: colorAlerta,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: _textoSuave,
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FilaDato(
                        icono: Icons.medical_services_outlined,
                        texto: alerta.tipoAcceso,
                      ),
                      const SizedBox(height: 8),
                      _FilaDato(
                        icono: Icons.calendar_month_outlined,
                        texto: alerta.fechaHoraFormateada,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorEstado.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              sincronizada
                                  ? Icons.cloud_done_rounded
                                  : estadoError
                                      ? Icons.sync_problem_rounded
                                      : Icons.schedule_rounded,
                              color: colorEstado,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                textoEstado,
                                style: TextStyle(
                                  color: colorEstado,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (!sincronizada && alerta.id != null)
                              Text(
                                'Local #${alerta.id}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textoSuave,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (alerta.ultimoErrorSincronizacion != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: Color(0xFFC62828),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                alerta.ultimoErrorSincronizacion!,
                                style: const TextStyle(
                                  color: Color(0xFFC62828),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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

class _DetalleAlertaSheet extends StatelessWidget {
  final AlertaRegistro alerta;
  final Color colorAlerta;
  final Color fondoAlerta;

  const _DetalleAlertaSheet({
    required this.alerta,
    required this.colorAlerta,
    required this.fondoAlerta,
  });

  @override
  Widget build(BuildContext context) {
    final resumen = alerta.resumenChecklist.trim();
    final comentario = alerta.comentario.trim();
    final tieneResumen = resumen.isNotEmpty;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6E0E6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: fondoAlerta,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.assignment_turned_in_outlined,
                      color: colorAlerta,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalle de la alerta',
                          style: TextStyle(
                            color: _oscuro,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          alerta.codigoQr,
                          style: const TextStyle(
                            color: _textoSuave,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar detalle',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _BloqueDetalle(
                titulo: 'DATOS DE LA ATENCIÓN',
                icono: Icons.calendar_month_outlined,
                child: Column(
                  children: [
                    _FilaDato(
                      icono: Icons.medical_services_outlined,
                      texto: alerta.tipoAcceso,
                    ),
                    const SizedBox(height: 10),
                    _FilaDato(
                      icono: Icons.schedule_rounded,
                      texto: alerta.fechaHoraFormateada,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: fondoAlerta,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'ALERTA ${alerta.nivelAlerta}',
                          style: TextStyle(
                            color: colorAlerta,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BloqueDetalle(
                titulo: 'RESUMEN DEL CHECKLIST',
                icono: Icons.fact_check_outlined,
                child: tieneResumen
                    ? _ResumenChecklistVista(texto: resumen)
                    : const Text(
                        'No hay un resumen clínico guardado para este registro. '
                        'Las alertas registradas antes de esta mejora no '
                        'contienen este detalle.',
                        style: TextStyle(
                          color: _textoSuave,
                          fontSize: 13,
                          height: 1.55,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              _BloqueDetalle(
                titulo: 'COMENTARIO DEL ENFERMERO',
                icono: Icons.chat_bubble_outline_rounded,
                child: Text(
                  comentario.isEmpty ? 'Sin comentarios.' : comentario,
                  style: TextStyle(
                    color: comentario.isEmpty ? _textoSuave : _oscuro,
                    fontSize: 13,
                    height: 1.5,
                    fontStyle:
                        comentario.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'El resumen se conserva en este dispositivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textoSuave,
                    fontSize: 11,
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

class _BloqueDetalle extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;

  const _BloqueDetalle({
    required this.titulo,
    required this.icono,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        border: Border.all(color: _borde),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: _primario),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: _oscuro,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ============================================================
// VISTA ESTRUCTURADA DEL RESUMEN DEL CHECKLIST (SOLO PRESENTACIÓN)
// ============================================================
// Recibe el mismo texto que antes se mostraba plano y lo presenta con
// secciones (hallazgos, recomendaciones, etc.), viñetas e iconos.
// No modifica ni guarda datos: solo interpreta el texto para mostrarlo.

class _LineaResumen {
  final String texto;
  final bool esVineta;

  const _LineaResumen(this.texto, this.esVineta);
}

class _SeccionResumen {
  final String titulo;
  final List<String> items = [];

  _SeccionResumen(this.titulo);
}

class _ResumenParseado {
  final List<_LineaResumen> intro = [];
  final List<_SeccionResumen> secciones = [];
}

class _EstiloSeccionResumen {
  final Color color;
  final Color fondo;
  final IconData icono;
  final IconData? iconoItem;

  const _EstiloSeccionResumen({
    required this.color,
    required this.fondo,
    required this.icono,
    this.iconoItem,
  });
}

final RegExp _reVineta =
    RegExp(r'^(?:[-–—•●▪‣·*]|\d{1,2}[.)])\s+(.*)$');

final RegExp _reClave = RegExp(
  r'^(hallazgos?|recomendaci[oó]n(?:es)?|observaci[oó]n(?:es)?|conclusi[oó]n(?:es)?)\b',
  caseSensitive: false,
);

String _limpiarMarcado(String texto) {
  var t = texto.replaceAll('**', '').replaceAll('__', '');
  t = t.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
  return t.trim();
}

String _tituloPresentable(String titulo) {
  var t = titulo.trim();
  while (t.endsWith(':')) {
    t = t.substring(0, t.length - 1).trim();
  }
  if (t.isEmpty) return t;
  if (t == t.toUpperCase()) {
    t = t.toLowerCase();
  }
  return t[0].toUpperCase() + t.substring(1);
}

_ResumenParseado _parsearResumen(String texto) {
  final resultado = _ResumenParseado();
  _SeccionResumen? actual;

  final lineas =
      texto.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  for (final cruda in lineas) {
    final original = cruda.trim();
    if (original.isEmpty) continue;

    final esTituloMarkdown = original.startsWith('#') ||
        (original.startsWith('**') &&
            original.endsWith('**') &&
            original.length > 4);
    final linea = _limpiarMarcado(original);
    if (linea.isEmpty) continue;

    // 1. Viñeta o elemento numerado.
    final vineta = _reVineta.firstMatch(linea);
    if (vineta != null) {
      final contenido = (vineta.group(1) ?? '').trim();
      if (contenido.isEmpty) continue;
      if (actual != null) {
        actual.items.add(contenido);
      } else {
        resultado.intro.add(_LineaResumen(contenido, true));
      }
      continue;
    }

    // 2. Título de sección.
    final terminaEnDosPuntos = linea.endsWith(':') && linea.length <= 60;
    final palabras = linea.split(RegExp(r'\s+')).length;
    final soloClave = _reClave.hasMatch(linea) &&
        palabras <= 4 &&
        !linea.contains(RegExp(r'[.;,]'));

    if (terminaEnDosPuntos || esTituloMarkdown || soloClave) {
      actual = _SeccionResumen(_tituloPresentable(linea));
      resultado.secciones.add(actual);
      continue;
    }

    // 3. Título con contenido en la misma línea ("Hallazgos: texto").
    final enLinea = RegExp(r'^([^:]{3,40}):\s+(.+)$').firstMatch(linea);
    if (enLinea != null && _reClave.hasMatch(enLinea.group(1)!.trim())) {
      actual = _SeccionResumen(_tituloPresentable(enLinea.group(1)!));
      actual.items.add(enLinea.group(2)!.trim());
      resultado.secciones.add(actual);
      continue;
    }

    // 4. Línea normal.
    if (actual != null) {
      actual.items.add(linea);
    } else {
      resultado.intro.add(_LineaResumen(linea, false));
    }
  }

  return resultado;
}

_EstiloSeccionResumen _estiloSeccion(String titulo) {
  final t = titulo.toLowerCase();

  if (t.contains('hallazgo')) {
    return const _EstiloSeccionResumen(
      color: Color(0xFFB77900),
      fondo: Color(0xFFFFF6DC),
      icono: Icons.manage_search_rounded,
      iconoItem: Icons.warning_amber_rounded,
    );
  }
  if (t.contains('recomend') ||
      t.contains('sugerenc') ||
      t.contains('acciones')) {
    return const _EstiloSeccionResumen(
      color: Color(0xFF087E8B),
      fondo: Color(0xFFE6F5F6),
      icono: Icons.lightbulb_outline_rounded,
      iconoItem: Icons.check_circle_outline_rounded,
    );
  }
  if (t.contains('urgente') ||
      t.contains('crític') ||
      t.contains('critic') ||
      t.contains('alerta')) {
    return const _EstiloSeccionResumen(
      color: Color(0xFFC62828),
      fondo: Color(0xFFFFEBEE),
      icono: Icons.priority_high_rounded,
      iconoItem: Icons.error_outline_rounded,
    );
  }
  if (t.contains('observ') || t.contains('conclus')) {
    return const _EstiloSeccionResumen(
      color: Color(0xFF4268B0),
      fondo: Color(0xFFEAF0FF),
      icono: Icons.visibility_outlined,
    );
  }
  return const _EstiloSeccionResumen(
    color: Color(0xFF435867),
    fondo: Color(0xFFEFF3F6),
    icono: Icons.notes_rounded,
  );
}

class _ResumenChecklistVista extends StatelessWidget {
  final String texto;

  const _ResumenChecklistVista({required this.texto});

  @override
  Widget build(BuildContext context) {
    final parseado = _parsearResumen(texto);

    // Si no se pudo interpretar nada, se muestra el texto tal cual.
    if (parseado.intro.isEmpty && parseado.secciones.isEmpty) {
      return Text(
        texto,
        style: const TextStyle(
          color: _oscuro,
          fontSize: 13,
          height: 1.55,
        ),
      );
    }

    final hijos = <Widget>[];

    if (parseado.intro.isNotEmpty) {
      hijos.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < parseado.intro.length; i++) ...[
                if (i > 0) const SizedBox(height: 9),
                parseado.intro[i].esVineta
                    ? _ItemResumen(
                        texto: parseado.intro[i].texto,
                        color: _primario,
                      )
                    : Text.rich(
                        _construirTexto(parseado.intro[i].texto),
                      ),
              ],
            ],
          ),
        ),
      );
    }

    for (final seccion in parseado.secciones) {
      if (hijos.isNotEmpty) hijos.add(const SizedBox(height: 10));
      hijos.add(_TarjetaSeccionResumen(seccion: seccion));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: hijos,
    );
  }
}

class _TarjetaSeccionResumen extends StatelessWidget {
  final _SeccionResumen seccion;

  const _TarjetaSeccionResumen({required this.seccion});

  @override
  Widget build(BuildContext context) {
    final estilo = _estiloSeccion(seccion.titulo);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estilo.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            color: estilo.fondo,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(estilo.icono, size: 18, color: estilo.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    seccion.titulo,
                    style: TextStyle(
                      color: estilo.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (seccion.items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estilo.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${seccion.items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (seccion.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < seccion.items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 11),
                    _ItemResumen(
                      texto: seccion.items[i],
                      color: estilo.color,
                      icono: estilo.iconoItem,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemResumen extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData? icono;

  const _ItemResumen({
    required this.texto,
    required this.color,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icono != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icono, size: 18, color: color),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 7, left: 5, right: 5),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(_construirTexto(texto)),
        ),
      ],
    );
  }
}

/// Resalta en negrita la etiqueta inicial cuando el texto tiene la forma
/// "Etiqueta: valor". Si no la tiene, devuelve el texto normal.
InlineSpan _construirTexto(String texto) {
  const base = TextStyle(color: _oscuro, fontSize: 13, height: 1.5);
  final indice = texto.indexOf(':');

  if (indice > 0 && indice <= 40 && indice < texto.length - 1) {
    return TextSpan(
      style: base,
      children: [
        TextSpan(
          text: texto.substring(0, indice + 1),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        TextSpan(text: texto.substring(indice + 1)),
      ],
    );
  }

  return TextSpan(text: texto, style: base);
}

class _FilaDato extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _FilaDato({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: _textoSuave),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: Color(0xFF435867),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MENSAJE DE ESTADO (VACÍO / ERROR)
// ============================================================

class _MensajeEstado extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback? accion;

  const _MensajeEstado({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primario.withValues(alpha: 0.10),
              ),
              child: Icon(icono, size: 42, color: _primario),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _oscuro,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: _textoSuave,
              ),
            ),
            if (accion != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: accion,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}