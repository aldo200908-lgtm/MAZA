# Verificación de la entrega

Entorno verificado: Flutter 3.35.7, Dart 3.9.2, Linux; Supabase Flutter 2.8.4 y dependencias fijadas en pubspec.lock.

- `flutter analyze`: sin incidencias.
- `flutter test --dart-define=VISUAL_OUTPUT=/tmp/maza-qa`: **17 pruebas correctas**.
- `flutter build web --release --no-web-resources-cdn`: compilación release de Flutter web.
- Prueba SQL con PostgreSQL embebido/PGlite 0.5.14: migración, seed, horarios, exclusión de solapamientos, turnos contiguos, instantáneas, versión, RLS y permisos correctos.
- Revisión visual de acceso, inicio, agenda, barbería y módulos futuros a 390×844; revisión de escritorio a 1440×900. Prueba de 360×800 con texto al 130 %.

La revisión independiente de código detectó y se corrigieron: recargas que podían pisar escrituras, historiales sin paginación, actualizaciones de citas sin versión, selector de estado que podía mostrar un guardado fallido y rutas privadas que podían permanecer visibles tras salir. Las pruebas cubren estos comportamientos. También se corrigió la liberación de controladores antes de terminar la animación del formulario.

## No verificado en servicios/dispositivos reales

No se conectó un proyecto Supabase del usuario, no se envió correo real de recuperación ni se probó un APK en dispositivo/emulador. No hay Android SDK en este entorno. Los tests del adaptador usan HTTP simulado; el SQL usa un auth mínimo de prueba. Estas limitaciones están explicadas en README.md.

No se publicó la aplicación ni se modificó ningún repositorio remoto.
