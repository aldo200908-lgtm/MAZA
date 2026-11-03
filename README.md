# MAZA · primera versión

Demo navegable de agenda y barbería para **un administrador**, en Flutter con Android y web desde el mismo código. Interfaz en español, precios en soles y hora de Perú. Paleta marfil/carbón/naranja; no usa imágenes externas ni fuentes de red.

## Incluye

- **Base:** acceso privado por correo y contraseña con Supabase, sesión persistente, recuperación de contraseña, cierre de sesión y navegación inferior (lateral en escritorio).
- **Citas:** calendario día/semana, filtros de barbero y estado, alta de citas, selección de disponibilidad, notas, reprogramación y cinco estados. Reservas contiguas permitidas; solapamientos bloqueados en UI y PostgreSQL.
- **Barbería:** crear/editar/desactivar servicios y barberos, precios, duración, días y horario. Clientes con búsqueda, teléfono peruano, preferencias e historial.
- **Stock de belleza, Alquileres y Pagos:** pantallas vacías y tablas listas, sin operaciones ni cobros reales.
- **Demo local:** datos ficticios de Puno, guardados en el dispositivo/navegador. **No es un sistema de autenticación.** Solo se abre mediante «Explorar demo».
- **Modo Supabase:** login real y persistencia remota. No hay registro público; solo un UUID de Auth recibe acceso.

## Ejecutar sin credenciales

Requisito: Flutter **3.35.7** (Dart 3.9.2) o una versión compatible. Se incluye `pubspec.lock` para reproducir las dependencias verificadas.

```bash
cd maza
flutter pub get
flutter run -d chrome --dart-define=DEMO_MODE=true
```

Para teléfono Android con depuración USB activada y Android SDK instalado:

```bash
flutter devices
flutter run -d ID_DEL_TELEFONO --dart-define=DEMO_MODE=true
flutter build apk --debug --dart-define=DEMO_MODE=true
```

La carpeta `demo_web/` del paquete contiene la **compilación Flutter web**, no otra implementación. Para abrirla sin Flutter, desde la carpeta descomprimida:

```bash
python3 -m http.server 8080 --directory demo_web
```

Abre `http://localhost:8080`. En el teléfono conectado al mismo Wi-Fi, usa `http://IP_DE_TU_PC:8080`. No abrir `index.html` con `file://`: Flutter necesita un servidor HTTP. El modo demo guarda cambios por navegador y origen; salir mantiene los datos. Borrar el almacenamiento del sitio restablece los ejemplos. No hay sincronización entre dispositivos en demo.

## Conectar Supabase

1. Crea un proyecto de prueba en Supabase. Ejecuta **una vez** `supabase/migrations/001_maza.sql` en SQL Editor, sobre un proyecto vacío.
2. En Authentication → Users crea un usuario de administrador, con correo confirmado. Desactiva nuevos registros en Authentication → Providers → Email. La app no ofrece registro.
3. Copia su UUID en `supabase/bootstrap.sql` y ejecútalo. La clave primaria booleana obliga a que exista **un solo administrador**. Ningún usuario puede autoasignarse desde la app.
4. Opcional: ejecuta `supabase/seed_demo.sql` para cargar los ejemplos en el servidor. Deja vacíos Stock, Alquileres y Pagos. No ejecutar sobre datos reales.
5. Copia `config/supabase.example.json` a `config/supabase.json`. Completa URL y clave **pública anon** de tu proyecto (API Keys → legacy anon). **Nunca** introduzcas `service_role` ni una clave secreta. El archivo real está excluido de git.
6. Para Android conserva `AUTH_REDIRECT_URL=pe.maza://login-callback/`. Añade esa URL exacta a Authentication → URL Configuration → Redirect URLs. Android ya tiene el intent filter para abrirla.
7. Para web usa en `AUTH_REDIRECT_URL` la URL raíz donde se sirve la app (ej. `http://localhost:8080/` durante desarrollo o tu URL HTTPS al desplegar). Añádela a Redirect URLs y configura Site URL. Esta versión usa rutas hash; no requiere reescrituras para navegación.

```bash
flutter run -d chrome --web-port=8080 --dart-define-from-file=config/supabase.json
# O compila para el dispositivo configurado:
flutter build web --release --no-web-resources-cdn --dart-define-from-file=config/supabase.json
flutter build apk --debug --dart-define-from-file=config/supabase.json
```

El modo conectado **no cae automáticamente al modo demo** si faltan credenciales. Las credenciales de usuario nunca se incluyen en el código. La clave pública se compila en el cliente por diseño; RLS protege los datos.

## Estructura

```text
maza/
  lib/
    main.dart                       # configuración y arranque
    app.dart                        # sesión y navegación adaptativa
    core/
      clock.dart                    # Perú, fechas y moneda
      models.dart                   # entidades e instantáneas
      repository.dart               # contrato de persistencia
      store.dart                    # estado y reglas de negocio
      theme.dart                    # identidad MAZA
      widgets.dart                  # superficies, formularios y errores
    data/
      demo_repository.dart          # persistencia local y ejemplos
      supabase_repository.dart      # API, paginación y versiones
    features/
      auth/login_screen.dart
      home/home_screen.dart
      appointments/
        appointments_screen.dart
        appointment_editor.dart
      barbers/barbers_screen.dart
      clients/clients_screen.dart
      more/more_screen.dart         # módulos futuros vacíos
  android/                          # proyecto nativo, permiso Internet y deep link
  web/                              # arranque web y marca
  assets/fonts/                     # Roboto y su licencia
  config/supabase.example.json
  supabase/
    migrations/001_maza.sql
    bootstrap.sql
    seed_demo.sql
    tests/{invariants,access}.sql
  test/                             # dominio, widgets y adaptador HTTP
  tool/                             # verificaciones reproducibles
  docs/database.md                  # esquema y decisiones sobre pagos
  pubspec.yaml
  pubspec.lock
```

## Verificar

```bash
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

Prueba SQL local opcional, sin cuenta Supabase (Node.js 20+, PostgreSQL embebido con PGlite):

```bash
cd tool
npm install
npm run check:sql
```

Esta prueba crea un `auth.users`/`auth.uid()` mínimo, ejecuta la migración real, carga ejemplos y verifica RLS, permisos, solapamientos, horarios, precio histórico y control de versiones. No sustituye una prueba de integración contra tu proyecto Supabase. También puedes ejecutar `supabase/tests/*.sql` en un proyecto de prueba ya inicializado; las pruebas hacen rollback.

## Límites de esta entrega

- **Web compilada y verificada.** Se entrega el proyecto Android listo para compilar, pero no un APK probado: este entorno no tiene Android SDK/emulador. La firma release del proyecto generado es de desarrollo; configura tu propia firma antes de distribuir en tiendas.
- No se creó un proyecto Supabase real ni se verificó un correo de recuperación real. Se probaron los contratos del adaptador con HTTP simulado y las reglas SQL en PostgreSQL embebido.
- Un intervalo de trabajo por barbero y los mismos horarios en sus días elegidos. Sin descansos, festivos, varias sedes, notificaciones, roles adicionales o funcionamiento offline con Supabase.
- Cambiar un horario no mueve citas existentes. Las nuevas reservas y las reactivaciones deben cumplir el horario vigente.
- Servicios y barberos se desactivan; citas se cancelan. No se borran clientes ni historiales desde la UI para conservar las relaciones.
- La agenda se actualiza con el botón de recarga; no hay Realtime. Citas usan control de versión para impedir que una sesión obsoleta sobreescriba otra. Catálogos y fichas usan la última escritura confirmada.
- Paginación de 500 filas con el límite habitual de API de Supabase (1000); si reduces ese límite, mantenlo en al menos 500 o reduce `pageSize` en el repositorio. Para grandes volúmenes conviene cargar por rango de fechas desde el servidor.
- Pagos son **solo esquema**: no hay pasarela, Yape/Plin real, datos de tarjetas, conciliación, facturación ni registro de cobros. Lee `docs/database.md` antes de implementarlos.

Documentación de referencia: [Flutter](https://docs.flutter.dev/) y [Supabase Flutter 2.8.4](https://pub.dev/packages/supabase_flutter/versions/2.8.4). Se fija esta versión para reproducir la API usada, en lugar de depender de un cambio mayor de Supabase.

## Publicación automática de la demo

El repositorio incluye `.github/workflows/pages.yml` para publicar la demo desde `main` en GitHub Pages, ejecutando análisis y pruebas antes de compilar. Configuración: `docs/github-pages.md`. El modo publicado es demo local con datos ficticios y no requiere credenciales.
