# Acce-S.O.S

**Aplicación móvil y plataforma web para la identificación, valoración clínica y seguimiento de accesos vasculares para hemodiálisis.**

## Descripción

Acce-S.O.S es un prototipo tecnológico desarrollado para apoyar al personal de enfermería en el cuidado y seguimiento de pacientes con accesos vasculares para hemodiálisis. Integra una aplicación móvil y una plataforma web que permiten identificar accesos mediante códigos QR, consultar material educativo, realizar valoraciones clínicas y registrar alertas de atención.

El sistema contempla fístulas arteriovenosas (FAV), injertos arteriovenosos (AVG) y catéteres venosos centrales (CVC), incluyendo pacientes que cuentan con dos tipos de acceso vascular.

## Funcionalidades principales

### Aplicación móvil
- Identificación de accesos vasculares mediante códigos QR.
- Reconocimiento de FAV, injertos AVG y CVC.
- Manejo de pacientes con dos accesos vasculares (MIX9).
- Consulta de material educativo mediante videos e infografías.
- Checklists de valoración clínica independientes para FAV/AVG y CVC.
- Clasificación de alertas en niveles VERDE, AMARILLA y ROJA.
- Generación de resúmenes de valoración y recomendaciones.
- Registro de comentarios del personal de enfermería.
- Historial local de valoraciones.
- Almacenamiento mediante SQLite.
- Sincronización automática de alertas con el servidor cuando existe conexión a Internet.

### Plataforma web
- Administración de accesos vasculares.
- Generación de códigos QR.
- Gestión de usuarios y perfiles.
- Consulta de alertas recibidas desde la aplicación móvil.
- Visualización de niveles de alerta, fechas de atención y comentarios.
- Seguimiento del historial de atención.

## Arquitectura del proyecto

El sistema está compuesto por dos componentes principales:

| Componente | Tecnología | Función |
|---|---|---|
| Aplicación móvil | Flutter / Dart | Identificación QR, educación y valoración clínica |
| Servidor web | Django / Python | Administración y recepción de alertas |
| Base de datos móvil | SQLite | Almacenamiento local e historial |
| API | Django
