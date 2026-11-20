import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'checklist_screen.dart';
import 'historial_alertas_screen.dart';
import 'alerta_sync_service.dart';

// flutter pub get
//flutter run -d chrome
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AlertaSyncService.instance.iniciarMonitorDeConectividad();
  runApp(const AccesosVascularesApp());
}

// ============================================================
// CONFIGURACIÓN GENERAL
// ============================================================

class AccesosVascularesApp extends StatelessWidget {
  const AccesosVascularesApp({super.key});

  static const Color primary = Color(0xFF087E8B);
  static const Color background = Color(0xFFF3F7FA);
  static const Color dark = Color(0xFF18364A);

  // Colores de apoyo (solo visuales)
  static const Color textoSuave = Color(0xFF5B6E7C);
  static const Color borde = Color(0xFFE1EAF0);
  static const Color azul = Color(0xFF5578C7);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accesos Vasculares',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: dark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: dark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: dark,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 4,
          activeTrackColor: primary,
          inactiveTrackColor: primary.withValues(alpha: 0.18),
          thumbColor: primary,
          overlayColor: primary.withValues(alpha: 0.12),
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 7,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(
              color: Color(0xFFE1EAF0),
            ),
          ),
        ),
      ),
      home: const InicioScreen(),
    );
  }
}

// ============================================================
// UTILIDADES VISUALES COMPARTIDAS
// ============================================================

List<BoxShadow> _sombraSuave([Color? color]) {
  return [
    BoxShadow(
      color: (color ?? const Color(0xFF18364A)).withValues(alpha: 0.08),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
  ];
}

class _Circulo extends StatelessWidget {
  final double tamano;
  final double alpha;

  const _Circulo(this.tamano, this.alpha);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

/// Icono dentro de un recuadro redondeado con tinte del color dado.
class _IconoTile extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double tamano;

  const _IconoTile({
    required this.icono,
    required this.color,
    this.tamano = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(tamano * 0.32),
      ),
      child: Icon(icono, color: color, size: tamano * 0.55),
    );
  }
}

/// Banner compacto con degradado (solo título e icono).
class _BannerTitulo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final List<Color> colores;

  const _BannerTitulo({
    required this.icono,
    required this.titulo,
    required this.colores,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colores,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: _sombraSuave(colores.first),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -30,
            top: -40,
            child: _Circulo(120, 0.08),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icono, size: 26, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
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
}

/// Título de sección con barra de acento.
class _TituloSeccion extends StatelessWidget {
  final String titulo;
  final String? subtitulo;

  const _TituloSeccion(this.titulo, {this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 20,
              decoration: BoxDecoration(
                color: AccesosVascularesApp.primary,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AccesosVascularesApp.dark,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Text(
              subtitulo!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AccesosVascularesApp.textoSuave,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Etiqueta pequeña para campos (en mayúsculas).
class _EtiquetaCampo extends StatelessWidget {
  final String texto;

  const _EtiquetaCampo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AccesosVascularesApp.textoSuave,
      ),
    );
  }
}

/// Chip oscuro semitransparente para superponer sobre la cámara o imágenes.
class _ChipFlotante extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _ChipFlotante({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila "etiqueta: valor" para el diálogo de resultados.
class _FilaDato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _FilaDato(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EtiquetaCampo(etiqueta),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: AccesosVascularesApp.dark,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PANTALLA DE INICIO
// ============================================================

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      _IconoApp(),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Accesos Vasculares',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AccesosVascularesApp.dark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Apoyo a enfermería',
                              style: TextStyle(
                                fontSize: 12,
                                color: AccesosVascularesApp.textoSuave,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Bienvenida/o',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AccesosVascularesApp.dark,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ESCANEO QR
                  Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0A9AA8),
                          Color(0xFF087E8B),
                          Color(0xFF0B6477),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow:
                          _sombraSuave(AccesosVascularesApp.primary),
                    ),
                    child: Stack(
                      children: [
                        const Positioned(
                          right: -45,
                          top: -45,
                          child: _Circulo(170, 0.08),
                        ),
                        const Positioned(
                          right: 60,
                          bottom: -70,
                          child: _Circulo(130, 0.06),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                      Icons.qr_code_scanner_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Identificar acceso vascular',
                                          style: TextStyle(
                                            fontSize: 19,
                                            height: 1.2,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Lee el QR para ver su información',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xEBFFFFFF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const EscanerQrScreen(),
                                      ),
                                    );
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor:
                                        AccesosVascularesApp.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                  ),
                                  label: const Text(
                                    'Escanear código QR',
                                    style: TextStyle(
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

                  const SizedBox(height: 16),

                  // ACCESOS RÁPIDOS: HISTORIAL E INFOGRAFÍAS
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _AccesoRapido(
                            icono: Icons.history_rounded,
                            titulo: 'Historial',
                            detalle: 'Alertas registradas',
                            color: AccesosVascularesApp.azul,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const HistorialAlertasScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _AccesoRapido(
                            icono: Icons.menu_book_rounded,
                            titulo: 'Infografías',
                            detalle: 'Videos y guías',
                            color: AccesosVascularesApp.primary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const InfografiasScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Center(
                    child: Text(
                      'Prototipo académico',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF80909D),
                      ),
                    ),
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

class _AccesoRapido extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final VoidCallback onTap;

  const _AccesoRapido({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AccesosVascularesApp.borde),
        boxShadow: _sombraSuave(color),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconoTile(icono: icono, color: color, tamano: 46),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AccesosVascularesApp.dark,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AccesosVascularesApp.textoSuave,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconoApp extends StatelessWidget {
  const _IconoApp();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A9AA8),
            Color(0xFF087E8B),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _sombraSuave(AccesosVascularesApp.primary),
      ),
      child: const Icon(
        Icons.medical_services_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

// ============================================================
// TARJETA EDUCATIVA REUTILIZABLE
// ============================================================

class ModuloEducativoCard extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color color;
  final String etiqueta;
  final VoidCallback onTap;

  const ModuloEducativoCard({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AccesosVascularesApp.borde),
        boxShadow: _sombraSuave(color),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 12, 16),
                    child: Row(
                      children: [
                        _IconoTile(icono: icono, color: color),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                etiqueta,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                titulo,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: AccesosVascularesApp.dark,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (descripcion.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  descripcion,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: AccesosVascularesApp.textoSuave,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: color.withValues(alpha: 0.75),
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PANTALLA PRINCIPAL DE INFOGRAFÍAS
// ============================================================

class InfografiasScreen extends StatelessWidget {
  const InfografiasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'INFOGRAFÍAS',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ENFERMEDAD RENAL Y HEMODIÁLISIS
                  ModuloEducativoCard(
                    titulo: 'Enfermedad renal y hemodiálisis',
                    descripcion: 'Video e infografía introductoria',
                    icono: Icons.health_and_safety_rounded,
                    color: const Color(0xFF087E8B),
                    etiqueta: 'INTRODUCCIÓN',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecursosMultimediaScreen(
                            titulo: 'Enfermedad renal y hemodiálisis',
                            descripcion:
                                'Introducción a la enfermedad renal '
                                'crónica y al tratamiento de hemodiálisis.',
                            rutaVideo: 'assets/videos/VideoERC.mp4',
                            rutaImagen: 'assets/images/Picture1.png',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // FAV / AVG
                  ModuloEducativoCard(
                    titulo:
                        'Fístula arteriovenosa (FAV) o injerto '
                        'arteriovenoso (AVG)',
                    descripcion: 'Cuidados, valoración y educación',
                    icono: Icons.bloodtype_rounded,
                    color: const Color(0xFF5578C7),
                    etiqueta: 'ACCESOS VASCULARES',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccesoEducativoScreen(
                            tipo: TipoAcceso.favAvg,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // CVC
                  ModuloEducativoCard(
titulo: 'Catéter venoso central (CVC)',
                    descripcion: 'Cuidados, valoración y educación',
                    icono: Icons.medical_services_rounded,
                    color: const Color(0xFF087E8B),
                    etiqueta: 'ACCESOS VASCULARES',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccesoEducativoScreen(
                            tipo: TipoAcceso.cvc,
                          ),
                        ),
                      );
                    },
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
// LECTOR DE CÓDIGOS QR
// ============================================================

class EscanerQrScreen extends StatefulWidget {
  const EscanerQrScreen({super.key});

  @override
  State<EscanerQrScreen> createState() => _EscanerQrScreenState();
}

class _EscanerQrScreenState extends State<EscanerQrScreen> {
  late final MobileScannerController _controller;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _procesarCodigo(BarcodeCapture captura) {
    if (_procesando) return;

    String? contenido;
    for (final barcode in captura.barcodes) {
      final valor = barcode.rawValue?.trim();
      if (valor != null && valor.isNotEmpty) {
        contenido = valor;
        break;
      }
    }

    if (contenido == null) return;

    // Se aceptan identificadores nuevos con ubicación y códigos anteriores.
    // Nuevos: FAV1-000013, CVC5-000006, MIX9-000009.
    // Anteriores: FAV-000005, CVC-000006.
    final codigo = contenido.toUpperCase();
    final coincidencia = RegExp(
      r'^(FAV[1-4]|CVC[5-8]|MIX9|FAV|CVC)-\d{6,}$',
    ).firstMatch(codigo);

    if (coincidencia == null) {
      _procesando = true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'El formato del QR no es válido. Ejemplos: '
              'FAV1-000013, CVC5-000006 o MIX9-000009.',
            ),
          ),
        );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _procesando = false;
      });
      return;
    }

    _procesando = true;
    final prefijoCodigo = codigo.split('-').first;
    final TipoAcceso tipo;

    if (prefijoCodigo.startsWith('FAV')) {
      tipo = TipoAcceso.favAvg;
    } else if (prefijoCodigo.startsWith('CVC')) {
      tipo = TipoAcceso.cvc;
    } else {
      tipo = TipoAcceso.mix;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AccesoEducativoScreen(
          tipo: tipo,
          codigoQr: codigo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código QR')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _procesarCodigo,
                ),
                const IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: CustomPaint(painter: _EsquinasPainter()),
                    ),
                  ),
                ),
                const Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Center(
                      child: _ChipFlotante(
                        icono: Icons.center_focus_strong_rounded,
                        texto: 'Centra el código QR en el recuadro',
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Center(
                      child: _ChipFlotante(
                        icono: Icons.wifi_off_rounded,
                        texto: 'Funciona sin internet',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja las cuatro esquinas del marco de escaneo.
class _EsquinasPainter extends CustomPainter {
  const _EsquinasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const l = 40.0;
    final w = size.width;
    final h = size.height;

    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, 0)
        ..lineTo(l, 0),
      pincel,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - l, 0)
        ..lineTo(w, 0)
        ..lineTo(w, l),
      pincel,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h - l)
        ..lineTo(w, h)
        ..lineTo(w - l, h),
      pincel,
    );
    canvas.drawPath(
      Path()
        ..moveTo(l, h)
        ..lineTo(0, h)
        ..lineTo(0, h - l),
      pincel,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// TIPOS DE ACCESO
// ============================================================

enum TipoAcceso {
  favAvg,
  cvc,
  mix,
}

// ============================================================
// TARJETA DE PROTECCIÓN DEL ACCESO VASCULAR
// ============================================================

class _TarjetaProteccionAcceso extends StatelessWidget {
  final String mensaje;

  const _TarjetaProteccionAcceso({
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    const fondo = Color(0xFF18364A);
    const acento = Color(0xFFFFC857);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: acento,
          width: 2,
        ),
        boxShadow: _sombraSuave(fondo),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: acento,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: fondo,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROTEJA ESTE ACCESO',
                  style: TextStyle(
                    color: acento,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  mensaje,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PANTALLA DE FAV / AVG, CVC Y ACCESOS COMBINADOS
// ============================================================

class AccesoEducativoScreen extends StatelessWidget {
  final TipoAcceso tipo;
  final String? codigoQr;

  const AccesoEducativoScreen({
    super.key,
    required this.tipo,
    this.codigoQr,
  });

  bool get esFavAvg => tipo == TipoAcceso.favAvg;
  bool get esCvc => tipo == TipoAcceso.cvc;
  bool get esMixto => tipo == TipoAcceso.mix;

  String get tituloPantalla {
    switch (tipo) {
      case TipoAcceso.favAvg:
        return 'FAV o injerto AVG';
      case TipoAcceso.cvc:
        return 'Catéter venoso central (CVC)';
      case TipoAcceso.mix:
        return 'Dos accesos vasculares';
    }
  }

  String get tituloCompleto {
    switch (tipo) {
      case TipoAcceso.favAvg:
        return 'Fístula arteriovenosa (FAV) o injerto '
            'arteriovenoso (AVG)';
      case TipoAcceso.cvc:
        return 'Catéter venoso central (CVC)';
      case TipoAcceso.mix:
        return 'Fístula arteriovenosa (FAV) + '
            'catéter venoso central (CVC)';
    }
  }

  // El tipo se obtiene del QR cuando se accede desde un paciente.
  String get tipoQrDescripcion {
    final codigo = codigoQr?.toUpperCase();
    if (codigo != null) {
      final prefijoCodigo = codigo.split('-').first;
      if (prefijoCodigo == 'MIX9') {
        // En la pantalla mixta se muestra el nombre de ambos accesos.
        // Al entrar a una subpantalla, se muestra solo el acceso seleccionado.
        if (tipo != TipoAcceso.mix) return tituloCompleto;
        return 'Fístula arteriovenosa (FAV) + catéter venoso central '
            '(CVC): dos accesos vasculares';
      }
      if (prefijoCodigo.startsWith('FAV')) {
        return 'Fístula arteriovenosa (FAV) o injerto '
            'arteriovenoso (AVG)';
      }
      if (prefijoCodigo.startsWith('CVC')) {
        return 'Catéter venoso central (CVC)';
      }
    }
    return tituloCompleto;
  }

  // Los QR nuevos codifican ubicación en el prefijo. Los códigos antiguos
  // no incluyen ese dato, por lo que no se debe inferir una ubicación.
  String get ubicacionQrDescripcion {
    final codigo = codigoQr?.toUpperCase();
    if (codigo == null) return '';

    final prefijoCodigo = codigo.split('-').first;
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

    return ubicaciones[prefijoCodigo] ??
        'Ubicación no codificada en este QR anterior';
  }

  // Precauciones asociadas al tipo de acceso identificado por el QR.
  // Los mensajes corresponden a la tabla proporcionada por enfermería.
  String? get mensajeProteccionQr {
    final codigo = codigoQr?.toUpperCase();
    if (codigo == null) return null;

    final prefijoCodigo = codigo.split('-').first;

    if (prefijoCodigo == 'FAV' ||
        RegExp(r'^FAV[1-4]$').hasMatch(prefijoCodigo)) {
      return 'NO TOME PRESIÓN, NO CANALICE, '
          'NO PUNCIONE, NO TOME MUESTRAS.';
    }

    if (prefijoCodigo == 'CVC' ||
        RegExp(r'^CVC[5-8]$').hasMatch(prefijoCodigo)) {
      return 'NO UTILICE NI MANIPULE PARA FINES DIFERENTES '
          'A LOS AUTORIZADOS EN EL PROTOCOLO INSTITUCIONAL.';
    }

    if (prefijoCodigo == 'MIX9') {
      return 'NO MANIPULE EL ACCESO PARA FINES DIFERENTES '
          'A LA DIÁLISIS.';
    }

    return null;
  }

  String get prefijo => esCvc ? 'CVC' : 'FAV';

  Color get colorPrincipal => esCvc
      ? const Color(0xFF087E8B)
      : const Color(0xFF4268B0);

  void abrirImagen(
    BuildContext context, {
    required String titulo,
    required String ruta,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisorInfografiaScreen(
          titulo: titulo,
          rutaImagen: ruta,
        ),
      ),
    );
  }

  void abrirVideo(
    BuildContext context, {
    required String titulo,
    required String video,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoERCScreen(
          titulo: titulo,
          rutaVideo: video,
        ),
      ),
    );
  }

  void abrirMultimedia(
    BuildContext context, {
    required String titulo,
    required String video,
    required String imagen,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecursosMultimediaScreen(
          titulo: titulo,
          descripcion:
              'Consulta los recursos educativos de esta sección.',
          rutaVideo: video,
          rutaImagen: imagen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final introduccion =
        'assets/images/${prefijo}_Introduccion.png';

    final introduccionVideo =
        'assets/videos/CVC_Introduccion.mp4';

    final proteccionImagen =
        'assets/images/${prefijo}_Proteccion.png';

    final proteccionVideo =
        'assets/videos/${prefijo}_Proteccion.mp4';

    final valoracionImagen =
        'assets/images/${prefijo}_Valoracion.png';

    final valoracionVideo =
        'assets/videos/${prefijo}_Valoracion.mp4';

    final educacion =
        'assets/images/${prefijo}_Educacion.png';

    return Scaffold(
      appBar: AppBar(
        title: Text(tituloPantalla),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cuando se ingresa mediante QR, la primera información
                  // visible es el tipo de acceso y su ubicación exacta.
                  if (codigoQr != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE8F7F4),
                            Color(0xFFD6EFEA),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFB8E3DC),
                          width: 1.3,
                        ),
                        boxShadow: _sombraSuave(
                          AccesosVascularesApp.primary,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _IconoTile(
                                icono: Icons.verified_user_rounded,
                                color: AccesosVascularesApp.primary,
                                tamano: 44,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const _EtiquetaCampo('ACCESO'),
                                    const SizedBox(height: 3),
                                    Text(
                                      tipoQrDescripcion,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.3,
                                        fontWeight: FontWeight.w800,
                                        color: AccesosVascularesApp.dark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(
                              height: 1,
                              color: Color(0xFFB8E3DC),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _IconoTile(
                                icono: Icons.location_on_rounded,
                                color: AccesosVascularesApp.primary,
                                tamano: 44,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const _EtiquetaCampo('UBICACIÓN'),
                                    const SizedBox(height: 3),
                                    Text(
                                      ubicacionQrDescripcion,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        height: 1.25,
                                        fontWeight: FontWeight.w900,
                                        color: AccesosVascularesApp.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 17,
                                  color: AccesosVascularesApp.dark,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    'ID QR: $codigoQr',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AccesosVascularesApp.dark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mensajeProteccionQr != null) ...[
                      const SizedBox(height: 14),
                      _TarjetaProteccionAcceso(
                        mensaje: mensajeProteccionQr!,
                      ),
                    ],
                    const SizedBox(height: 24),
                  ] else ...[
                    // Sin QR: banner compacto con el nombre del acceso.
                    _BannerTitulo(
                      icono: Icons.medical_services_rounded,
                      titulo: tituloCompleto,
                      colores: [
                        colorPrincipal,
                        esCvc
                            ? const Color(0xFF155E75)
                            : const Color(0xFF284B86),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (esMixto) ...[
                    _SelectorAccesosMixtos(codigoQr: codigoQr ?? ''),
                  ] else ...[
                    const _TituloSeccion('Contenido educativo'),
                    const SizedBox(height: 16),

                    // 1. INTRODUCCIÓN
                    // FAV/AVG: infografía. CVC: video introductorio.
                    ModuloEducativoCard(
                      titulo: 'Introducción',
                      descripcion: esFavAvg
                          ? 'Características generales de la FAV y el injerto'
                          : 'Características generales del catéter',
                      icono: esFavAvg
                          ? Icons.menu_book_rounded
                          : Icons.play_circle_rounded,
                      color: const Color(0xFF087E8B),
                      etiqueta: esFavAvg ? 'INFOGRAFÍA' : 'VIDEO',
                      onTap: () {
                        if (esFavAvg) {
                          abrirImagen(
                            context,
                            titulo: 'Introducción · $tituloPantalla',
                            ruta: introduccion,
                          );
                        } else {
                          abrirVideo(
                            context,
                            titulo: 'Introducción · $tituloPantalla',
                            video: introduccionVideo,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // 2. PROTECCIÓN: VIDEO + INFOGRAFÍA
                    ModuloEducativoCard(
                      titulo: 'Protección',
                      descripcion: 'Cómo proteger el acceso vascular',
                      icono: Icons.shield_rounded,
                      color: const Color(0xFF5578C7),
                      etiqueta: 'VIDEO + INFOGRAFÍA',
                      onTap: () {
                        abrirMultimedia(
                          context,
                          titulo: 'Protección · $tituloPantalla',
                          video: proteccionVideo,
                          imagen: proteccionImagen,
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // 3. VALORACIÓN: VIDEO + INFOGRAFÍA
                    ModuloEducativoCard(
                      titulo: 'Valoración',
                      descripcion: 'Cómo valorar el acceso vascular',
                      icono: Icons.fact_check_rounded,
                      color: const Color(0xFF8064B5),
                      etiqueta: 'VIDEO + INFOGRAFÍA',
                      onTap: () {
                        abrirMultimedia(
                          context,
                          titulo: 'Valoración · $tituloPantalla',
                          video: valoracionVideo,
                          imagen: valoracionImagen,
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // 4. EDUCACIÓN AL PACIENTE: INFOGRAFÍA
                    ModuloEducativoCard(
                      titulo: 'Educación al paciente',
                      descripcion: 'Material de apoyo para el paciente',
                      icono: Icons.diversity_1_rounded,
                      color: const Color(0xFFB86B3D),
                      etiqueta: 'INFOGRAFÍA',
                      onTap: () {
                        abrirImagen(
                          context,
                          titulo: 'Educación al paciente · $tituloPantalla',
                          ruta: educacion,
                        );
                      },
                    ),
                  ],

                  if (codigoQr != null && !esMixto) ...[
                    const SizedBox(height: 26),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E8),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFF1D0AC),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.assignment_turned_in_rounded,
                                color: Color(0xFF9A4D19),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'SIGUIENTE PASO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF9A4D19),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                // El checklist se determina por el contenido educativo
                                // seleccionado, no por el prefijo del QR. Esto permite
                                // ejecutar FAV y CVC con el mismo QR MIX9.
                                final tipoChecklist = esCvc
                                    ? TipoChecklistAcceso.cvc
                                    : TipoChecklistAcceso.favAvg;
                                final resultado = await Navigator.of(context)
                                    .push<ResultadoChecklistPrueba>(
                                  MaterialPageRoute(
                                    builder: (_) => ChecklistScreen(
                                      codigoQr: codigoQr!,
                                      tipoAcceso: tipoQrDescripcion,
                                      tipoChecklist: tipoChecklist,
                                    ),
                                  ),
                                );

                                if (!context.mounted || resultado == null) {
                                  return;
                                }

                                final colorAlerta =
                                    resultado.nivelAlerta == 'VERDE'
                                        ? const Color(0xFF238636)
                                        : resultado.nivelAlerta == 'AMARILLA'
                                            ? const Color(0xFFD69E00)
                                            : const Color(0xFFC62828);

                                await showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    title: const Text(
                                      'Valoración guardada',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: AccesosVascularesApp.dark,
                                      ),
                                    ),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: colorAlerta.withValues(
                                                alpha: 0.10,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: colorAlerta.withValues(
                                                  alpha: 0.35,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              'ALERTA ${resultado.nivelAlerta}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: colorAlerta,
                                                fontSize: 17,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          _FilaDato(
                                            'CÓDIGO QR',
                                            resultado.codigoQr,
                                          ),
                                          _FilaDato(
                                            'TIPO DE ACCESO',
                                            resultado.tipoAcceso,
                                          ),
                                          _FilaDato(
                                            'FECHA Y HORA',
                                            resultado.fechaHoraFormateada,
                                          ),
                                          _FilaDato(
                                            'REGISTRO LOCAL',
                                            '#${resultado.idLocal ?? '-'}',
                                          ),
                                          const _FilaDato(
                                            'ESTADO',
                                            'GUARDADO · SINCRONIZACIÓN AUTOMÁTICA',
                                          ),
                                          if (resultado.comentario
                                              .trim()
                                              .isNotEmpty)
                                            _FilaDato(
                                              'COMENTARIO',
                                              resultado.comentario,
                                            ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'El registro quedó guardado en el dispositivo. '
                                            'La aplicación intentará sincronizarlo con Django '
                                            'automáticamente; si no hay conexión, permanecerá '
                                            'pendiente hasta que se recupere. Las respuestas '
                                            'individuales del checklist no se guardan ni se envían.',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              height: 1.4,
                                              color: AccesosVascularesApp
                                                  .textoSuave,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: const Text('Aceptar'),
                                      ),
                                    ],
                                  ),
                                );

                                if (!context.mounted) return;

                                // En pacientes MIX9, el resumen del primer acceso
                                // vuelve al selector para abrir automáticamente el otro.
                                if (codigoQr!.toUpperCase().startsWith('MIX9')) {
                                  Navigator.of(context).pop(resultado);
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF18364A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 19,
                                  horizontal: 18,
                                ),
                                elevation: 4,
                                shadowColor: const Color(0x6618364A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(
                                Icons.playlist_add_check_circle_rounded,
                                size: 25,
                              ),
                              label: const Text(
                                'REALIZAR CHECKLIST',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
// COORDINADOR DE PACIENTES CON DOS ACCESOS (MIX9)
// ============================================================

class _SelectorAccesosMixtos extends StatefulWidget {
  final String codigoQr;

  const _SelectorAccesosMixtos({required this.codigoQr});

  @override
  State<_SelectorAccesosMixtos> createState() =>
      _SelectorAccesosMixtosState();
}

class _SelectorAccesosMixtosState extends State<_SelectorAccesosMixtos> {
  bool _favCompletado = false;
  bool _cvcCompletado = false;
  bool _abriendoAcceso = false;

  ResultadoChecklistPrueba? _resultadoFav;
  ResultadoChecklistPrueba? _resultadoCvc;

  int get _cantidadCompletada =>
      (_favCompletado ? 1 : 0) + (_cvcCompletado ? 1 : 0);

  bool _estaCompletado(TipoAcceso tipo) {
    return tipo == TipoAcceso.favAvg ? _favCompletado : _cvcCompletado;
  }

  Future<void> _abrirAcceso(TipoAcceso tipo) async {
    if (_abriendoAcceso || _estaCompletado(tipo)) return;

    setState(() => _abriendoAcceso = true);
    ResultadoChecklistPrueba? resultado;

    try {
      resultado = await Navigator.of(context)
          .push<ResultadoChecklistPrueba>(
        MaterialPageRoute(
          builder: (_) => AccesoEducativoScreen(
            tipo: tipo,
            codigoQr: widget.codigoQr,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _abriendoAcceso = false);
      }
    }

    if (!mounted || resultado == null) return;

    setState(() {
      if (tipo == TipoAcceso.favAvg) {
        _favCompletado = true;
        _resultadoFav = resultado;
      } else {
        _cvcCompletado = true;
        _resultadoCvc = resultado;
      }
    });

    // Al completar el primer acceso, se abre el contenido educativo del otro.
    // El profesional podrá revisarlo y luego realizar su checklist.
    final otroTipo = tipo == TipoAcceso.favAvg
        ? TipoAcceso.cvc
        : TipoAcceso.favAvg;

    if (!_estaCompletado(otroTipo)) {
      await _abrirAcceso(otroTipo);
      return;
    }

    await _mostrarCierreDeAmbasValoraciones();
  }

  Future<void> _mostrarCierreDeAmbasValoraciones() async {
    final fav = _resultadoFav;
    final cvc = _resultadoCvc;
    if (fav == null || cvc == null || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Ambas valoraciones completadas',
          style: TextStyle(
            color: AccesosVascularesApp.dark,
            fontWeight: FontWeight.w900,
            fontSize: 19,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se completaron los checklists de FAV/AVG y CVC. Cada '
                'valoración quedó guardada como un registro independiente '
                'con el código QR del paciente.',
                style: TextStyle(
                  color: AccesosVascularesApp.textoSuave,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _FilaDato('CHECKLIST FAV / AVG', 'ALERTA ${fav.nivelAlerta}'),
              _FilaDato('FECHA FAV / AVG', fav.fechaHoraFormateada),
              _FilaDato('REGISTRO FAV / AVG', '#${fav.idLocal ?? '-'}'),
              const SizedBox(height: 8),
              _FilaDato('CHECKLIST CVC', 'ALERTA ${cvc.nivelAlerta}'),
              _FilaDato('FECHA CVC', cvc.fechaHoraFormateada),
              _FilaDato('REGISTRO CVC', '#${cvc.idLocal ?? '-'}'),
              const SizedBox(height: 8),
              const Text(
                'La sincronización con Django se gestiona automáticamente. '
                'Si no hay conexión, los registros permanecerán pendientes '
                'en el dispositivo hasta que se restablezca.',
                style: TextStyle(
                  color: AccesosVascularesApp.textoSuave,
                  height: 1.4,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaAcceso({
    required TipoAcceso tipo,
    required String titulo,
    required String descripcion,
    required IconData icono,
    required Color color,
  }) {
    final completado = _estaCompletado(tipo);
    return ModuloEducativoCard(
      titulo: titulo,
      descripcion: completado
          ? 'Checklist completado en esta sesión'
          : descripcion,
      icono: completado ? Icons.task_alt_rounded : icono,
      color: completado ? const Color(0xFF238636) : color,
      etiqueta: completado
          ? 'VALORACIÓN COMPLETADA'
          : tipo == TipoAcceso.favAvg
              ? 'CONTENIDO FAV / AVG'
              : 'CONTENIDO CVC',
      onTap: (_abriendoAcceso || completado)
          ? () {}
          : () => _abrirAcceso(tipo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progreso = _cantidadCompletada / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion(
          'Contenido educativo',
          subtitulo: 'Consulta cada acceso y completa sus dos valoraciones.',
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AccesosVascularesApp.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Progreso de las valoraciones',
                      style: TextStyle(
                        color: AccesosVascularesApp.dark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '$_cantidadCompletada de 2',
                    style: const TextStyle(
                      color: AccesosVascularesApp.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progreso,
                  minHeight: 8,
                  backgroundColor:
                      AccesosVascularesApp.primary.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AccesosVascularesApp.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _tarjetaAcceso(
          tipo: TipoAcceso.favAvg,
          titulo: 'Fístula arteriovenosa (FAV) o injerto (AVG)',
          descripcion: 'Cuidados, valoración y educación',
          icono: Icons.bloodtype_rounded,
          color: const Color(0xFF5578C7),
        ),
        const SizedBox(height: 14),
        _tarjetaAcceso(
          tipo: TipoAcceso.cvc,
          titulo: 'Catéter venoso central (CVC)',
          descripcion: 'Cuidados, valoración y educación',
          icono: Icons.medical_services_rounded,
          color: const Color(0xFF087E8B),
        ),
        if (_abriendoAcceso) ...[
          const SizedBox(height: 14),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
        if (_cantidadCompletada == 2) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFB8E3C0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF238636)),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Los dos checklists fueron completados y guardados.',
                    style: TextStyle(
                      color: Color(0xFF1D6B32),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// PANTALLA REUTILIZABLE: VIDEO + INFOGRAFÍA
// ============================================================

class RecursosMultimediaScreen extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final String rutaVideo;
  final String rutaImagen;

  const RecursosMultimediaScreen({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.rutaVideo,
    required this.rutaImagen,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TarjetaVideo(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoERCScreen(
                            titulo: titulo,
                            rutaVideo: rutaVideo,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _TarjetaInfografia(
                    rutaImagen: rutaImagen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VisorInfografiaScreen(
                            titulo: titulo,
                            rutaImagen: rutaImagen,
                          ),
                        ),
                      );
                    },
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
// TARJETA DE VIDEO
// ============================================================

class _TarjetaVideo extends StatelessWidget {
  final VoidCallback onTap;

  const _TarjetaVideo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AccesosVascularesApp.borde),
        boxShadow: _sombraSuave(AccesosVascularesApp.primary),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF155E75),
                      Color(0xFF087E8B),
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      right: -35,
                      top: -35,
                      child: _Circulo(140, 0.08),
                    ),
                    const Positioned(
                      left: -30,
                      bottom: -50,
                      child: _Circulo(130, 0.06),
                    ),
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 38,
                            color: AccesosVascularesApp.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 24,
                      color: AccesosVascularesApp.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Video educativo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AccesosVascularesApp.dark,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 26,
                      color: AccesosVascularesApp.primary,
                    ),
                  ],
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
// TARJETA DE INFOGRAFÍA
// ============================================================

class _TarjetaInfografia extends StatelessWidget {
  final String rutaImagen;
  final VoidCallback onTap;

  const _TarjetaInfografia({
    required this.rutaImagen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AccesosVascularesApp.borde),
        boxShadow: _sombraSuave(AccesosVascularesApp.azul),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF1F5FF),
                      Color(0xFFE4ECFF),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Image.asset(
                  rutaImagen,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 42,
                        color: AccesosVascularesApp.azul,
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 24,
                      color: AccesosVascularesApp.azul,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Infografía educativa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AccesosVascularesApp.dark,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.zoom_in_rounded,
                      size: 26,
                      color: AccesosVascularesApp.azul,
                    ),
                  ],
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
// REPRODUCTOR DE VIDEO REUTILIZABLE
// ============================================================

class VideoERCScreen extends StatefulWidget {
  final String titulo;
  final String rutaVideo;

  const VideoERCScreen({
    super.key,
    required this.titulo,
    required this.rutaVideo,
  });

  @override
  State<VideoERCScreen> createState() => _VideoERCScreenState();
}

class _VideoERCScreenState extends State<VideoERCScreen> {
  late final VideoPlayerController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(widget.rutaVideo);
    _controller.addListener(_actualizarEstado);
    _inicializarVideo();
  }

  Future<void> _inicializarVideo() async {
    try {
      await _controller.initialize();

      if (!mounted) return;

      setState(() {});
    } catch (error) {
      debugPrint('Error al cargar ${widget.rutaVideo}: $error');

      if (!mounted) return;

      setState(() {
        _error =
            'No se pudo cargar el video. Comprueba que el archivo '
            'esté registrado en pubspec.yaml y que su formato '
            'sea compatible con el navegador.';
      });
    }
  }

  void _actualizarEstado() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _alternarReproduccion() async {
    if (!_controller.value.isInitialized) return;

    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      if (_controller.value.isCompleted) {
        await _controller.seekTo(Duration.zero);
      }

      await _controller.play();
    }
  }

  String _formatearTiempo(Duration tiempo) {
    final horas = tiempo.inHours;
    final minutos = tiempo.inMinutes.remainder(60);
    final segundos = tiempo.inSeconds.remainder(60);

    final mm = minutos.toString().padLeft(2, '0');
    final ss = segundos.toString().padLeft(2, '0');

    if (horas > 0) {
      return '$horas:$mm:$ss';
    }

    return '$mm:$ss';
  }

  @override
  void dispose() {
    _controller.removeListener(_actualizarEstado);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listo = _controller.value.isInitialized;

    final duracion =
        listo ? _controller.value.duration : Duration.zero;

    final posicion =
        listo ? _controller.value.position : Duration.zero;

    final duracionMs = duracion.inMilliseconds;

    final maximo = duracionMs > 0
        ? duracionMs.toDouble()
        : 1.0;

    final valor = posicion.inMilliseconds
        .clamp(0, duracionMs)
        .toDouble();

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // VENTANA DEL VIDEO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: _error != null
                          ? AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.white70,
                                        size: 34,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : !listo
                              ? const AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : AspectRatio(
                                  aspectRatio:
                                      _controller.value.aspectRatio > 0
                                          ? _controller.value.aspectRatio
                                          : 16 / 9,
                                  child: VideoPlayer(_controller),
                                ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CONTROLES
                  if (listo)
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AccesosVascularesApp.borde,
                        ),
                        boxShadow: _sombraSuave(),
                      ),
                      child: Row(
                        children: [
                          IconButton.filled(
                            tooltip: _controller.value.isPlaying
                                ? 'Pausar video'
                                : 'Reproducir video',
                            onPressed: _alternarReproduccion,
                            style: IconButton.styleFrom(
                              backgroundColor: AccesosVascularesApp.primary,
                              foregroundColor: Colors.white,
                              fixedSize: const Size(48, 48),
                            ),
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatearTiempo(posicion),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AccesosVascularesApp.dark,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: valor,
                              max: maximo,
                              onChanged: duracionMs > 0
                                  ? (nuevoValor) {
                                      _controller.seekTo(
                                        Duration(
                                          milliseconds: nuevoValor.round(),
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                          Text(
                            _formatearTiempo(duracion),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AccesosVascularesApp.textoSuave,
                            ),
                          ),
                        ],
                      ),
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
// VISOR DE INFOGRAFÍAS CON AMPLIACIÓN
// ============================================================

class VisorInfografiaScreen extends StatelessWidget {
  final String titulo;
  final String rutaImagen;

  const VisorInfografiaScreen({
    super.key,
    required this.titulo,
    required this.rutaImagen,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AccesosVascularesApp.borde,
              ),
              boxShadow: _sombraSuave(),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      boundaryMargin: const EdgeInsets.all(30),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Image.asset(
                          rutaImagen,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No se pudo cargar la infografía. '
                                  'Comprueba la ruta del archivo '
                                  'en pubspec.yaml.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                const Positioned(
                  bottom: 14,
                  left: 14,
                  right: 14,
                  child: IgnorePointer(
                    child: Center(
                      child: _ChipFlotante(
                        icono: Icons.pinch_rounded,
                        texto: 'Pellizca para ampliar',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
