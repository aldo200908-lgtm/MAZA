# MAZA Web

Web Flutter con dos caras independientes: clientes y administración. Esta entrega se centra **solo en la web**, adaptable a celular y computadora. La futura app móvil se construirá aparte; no se ha cambiado ni compilado Android en esta versión.

Web: https://aldo200908-lgtm.github.io/MAZA/

La publicación principal se compila conectada a Supabase con `config/supabase.web.json` (solo URL y clave pública). El panel exige la cuenta administradora asignada en la base. La demostración sin datos reales se publica por separado en `/MAZA/demo/`, con `DEMO_MODE=true` y `DESIGN_PREVIEW=true`. No compartir contraseñas por chat.

## Área pública

- Inicio con cuatro bloques: presentación/búsqueda, barbería, productos y alquileres.
- Buscador de servicios, productos y equipos, categorías y fichas de catálogo.
- Reserva con tres elecciones principales: servicio → turno disponible → confirmar. Para una cuenta con datos guardados no hay formularios intermedios. La primera visita necesita identificación y datos.
- Horarios en Perú, filtro opcional de barbero y búsqueda inicial del próximo día disponible dentro de una semana. Fechas manuales hasta 90 días.
- Cuenta con citas propias, cancelación/reprogramación de turnos futuros, solicitudes de productos/alquileres y edición de nombre/celular.
- Solicitudes con estado pendiente; no confirman un contrato ni descuentan dinero.

## Administración

Ruta independiente `/#/admin`. En la demo el acceso está identificado como **panel de demostración público** y contiene solo datos ficticios. No es una protección para datos reales.

Resumen, agenda, servicios/precios/barberos/horarios, clientes/historial, catálogo de stock, equipos/solicitudes, estado de Pagos y configuración del negocio. Navegación móvil: Resumen, Citas, Gestión. En escritorio, menú lateral con los módulos.

Gestión de citas, servicios, barberos y clientes; edición de productos y equipos; entradas/salidas de stock con motivo; ventas vinculadas a cliente; reservas de equipo, entrega, devolución y cancelación sin abonos; confirmación/rechazo de solicitudes públicas. Completar una cita, vender o reservar genera una cuenta por cobrar con precio del servidor. Abonos manuales en efectivo, Yape, Plin o transferencia: se registra dinero recibido externamente, sin ejecutar transferencias. Saldos, historial de abonos y reportes derivados de lo guardado. Las garantías se muestran aparte y no se suman a los ingresos.

Los comandos usan claves de idempotencia, transacciones, bloqueo y comprobación de administrador. No hay stock negativo, doble reserva ni sobrepago. Los abonos no se borran y se bloquea cancelar alquileres abonados. Esta versión no administra reembolsos ni emite comprobantes tributarios; coordinar esos casos fuera del sistema.

## Demo local

El cliente de ejemplo es Luis Quispe. El panel demo se abre por separado desde «Acceso de administración» al pie del inicio o `/#/admin`. Los cambios de clientes/citas/configuración y las solicitudes se guardan en ese navegador. No hay sincronización entre navegadores. No introducir datos personales reales.

```bash
flutter pub get
flutter run -d chrome --dart-define=DEMO_MODE=true
```

Verificado con Flutter 3.35.7/Dart 3.9.2; dependencias exactas en `pubspec.lock`. `go_router` se fija a 16.2.4 por compatibilidad con ese SDK.

## Rutas

Se usa la estrategia hash para recargar enlaces profundos en GitHub Pages sin reescrituras del servidor.

| Público | Administración |
|---|---|
| `/#/` | `/#/admin` |
| `/#/buscar` | `/#/admin/citas` |
| `/#/barberia` | `/#/admin/gestion` |
| `/#/barberia/reservar?servicio=UUID` | `/#/admin/barberia` |
| `/#/barberia/confirmacion/UUID` | `/#/admin/clientes` y `/#/admin/clientes/UUID` |
| `/#/productos` y `/#/productos/UUID` | `/#/admin/stock` |
| `/#/alquileres` y `/#/alquileres/UUID` | `/#/admin/alquileres` |
| `/#/mi-cuenta`, `/citas`, `/solicitudes` | `/#/admin/pagos` |
| `/#/acceso`, `/#/recuperar` | `/#/admin/configuracion`, `/#/admin/acceso` |

Las barras de cliente y administrador pertenecen a dos `StatefulShellRoute.indexedStack` diferentes. Los retornos de acceso admiten solo rutas internas. Servicio/turno/barbero viajan en la URL para conservar la selección al identificarse; el servidor vuelve a comprobarla al confirmar.

## Conectar Supabase real

Para reproducir la instalación en otro proyecto nuevo:

1. Ejecutar `supabase/migrations/001_maza.sql` , después `002_customer_web.sql` y `20261103170352_admin_operations.sql` en SQL Editor.
2. Crear el administrador desde Authentication → Users, copiar su UUID en `supabase/bootstrap.sql` y ejecutar ese bloque una vez. Existe un solo administrador.
3. Para probar con datos ficticios, ejecutar `supabase/seed_demo.sql` y luego `supabase/seed_web.sql`. Nunca ejecutar los seeds sobre datos reales.
4. Permitir registro por correo para clientes en Supabase Auth y configurar la confirmación por correo. El administrador sigue asignándose exclusivamente por SQL. Crear una cuenta cliente nunca concede administración.
5. Copiar `config/supabase.example.json` a `config/supabase.json`, completar URL y clave **publishable pública**, establecer `DEMO_MODE=false` y `AUTH_REDIRECT_URL` a la URL web raíz donde se sirve MAZA. Añadir esa URL exacta a Auth → URL Configuration y configurar Site URL. `SUPABASE_ANON_KEY` conserva su nombre por compatibilidad y admite la clave publishable.
6. No usar claves `service_role` ni claves secretas en Flutter. Los archivos reales de configuración están excluidos de git.

```bash
flutter run -d chrome --web-port=8080 --dart-define-from-file=config/supabase.json
flutter build web --release --no-web-resources-cdn --no-tree-shake-icons --base-href /MAZA/ --dart-define-from-file=config/supabase.json
```

### Protección de datos en modo conectado

- El catálogo anónimo sale de `web_catalog`, que devuelve solo campos públicos. No publica clientes, teléfonos, notas, citas ni contratos.
- `web_profile`, `web_my_appointments` y `web_my_requests` filtran por `auth.uid()` y su ficha vinculada. No hay lecturas anónimas de tablas internas.
- `web_save_profile` no permite apropiarse de una ficha existente por conocer su teléfono; el administrador debe vincularla cuando corresponda. Las notas internas no aparecen en el perfil del cliente.
- `web_book` determina el cliente desde la sesión; el trigger toma precio/duración del catálogo y PostgreSQL impide solapamientos concurrentes.
- `web_change_booking` exige propiedad, versión vigente, estado pendiente/confirmado y cita futura. Conserva barbero, precio y duración históricos.
- `web_request_item` valida artículo/cantidad/fechas y calcula el importe en el servidor; no cobra ni descuenta stock. Confirmar una solicitud registra venta o reserva atómicamente mediante `admin_operate`; `web_resolve_request` conserva esa misma garantía.
- El resto de las tablas conserva RLS de administrador único de v1. El guard de rutas no sustituye esos controles.

## Estructura principal

```text
lib/
  app.dart                  # MaterialApp.router
  main.dart                 # arranque demo/conectado
  web/
    router.dart             # rutas y guards
    shells.dart             # interfaces pública/admin adaptables
    controller.dart         # identidad y coordinación de datos
    gateway.dart            # demo persistente y RPC Supabase
    catalog.dart            # modelos públicos y solicitudes
    components.dart         # tarjetas e ilustraciones propias
    paths.dart              # validación de retornos internos
  core/                     # modelos y reglas reutilizadas de v1
  data/                     # repositorios administrativos
  features/
    public/                 # inicio, búsqueda, reserva, fichas y cuenta
    admin/                  # resumen, gestión, catálogos y configuración
    appointments/           # agenda administrativa
    barbers/                # servicios y equipo
    clients/                # clientes e historial
supabase/
  migrations/               # base + interfaz segura para clientes
  tests/                    # integridad, RLS y aislamiento entre clientes
  seed_demo.sql
  seed_web.sql
```

## Verificación y publicación

```bash
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn --no-tree-shake-icons --base-href /MAZA/ --dart-define-from-file=config/supabase.web.json
cd tool
npm install
npm run check:sql
```

La prueba SQL usa PostgreSQL embebido/PGlite y un `auth` mínimo, sin credenciales ni servicios externos. También se entregan los SQL de prueba para un proyecto de ensayo. El alta y la confirmación por correo del propietario se completan personalmente; nunca se solicita su contraseña por chat.

GitHub Actions verifica análisis y pruebas, compila solo web y despliega en Pages desde `main`. No hay creación de APK, pasarela de pago ni publicación en tiendas. El directorio Android anterior se conserva como antecedente de v1 y está fuera del alcance de esta entrega.

El build conserva las fuentes completas de iconos (`--no-tree-shake-icons`) para evitar un fallo del optimizador de iconos de este SDK con el nuevo bundle. No cambia el comportamiento de la web.

## Demostración independiente

En `/MAZA/demo/` se abre el panel sin login, exclusivamente con datos ficticios. No inicializa Supabase. Citas, fichas y solicitudes de ejemplo se guardan en ese navegador; inventario, alquileres y abonos de ejemplo se reinician al recargar. La app móvil queda fuera del alcance.

## Puesta en marcha desde el celular

1. Entrar en `/MAZA/#/admin` con la cuenta administradora confirmada. Si la contraseña no coincide, usar Recuperar contraseña con el mismo correo y abrir el mensaje más reciente.
2. Completar nombre, dirección y condiciones en Configuración; crear servicios y barberos con precios/horarios reales.
3. Agregar clientes, productos con stock inicial y equipos con tarifa diaria. No cargar los seeds ficticios en el negocio real.
4. Crear una cita, completarla y registrar un abono recibido externamente. Recargar y comprobar que se conserva; probar otro navegador como cliente.
5. Antes de abrir el registro a clientes externos, configurar SMTP propio en Supabase Auth, Site URL y Redirect URL exactas `https://aldo200908-lgtm.github.io/MAZA/`. El envío de correos públicos y la recuperación deben comprobarse con el titular; el proveedor de correo predeterminado tiene restricciones. No desactivar la confirmación para esquivar esa configuración.

Pendiente de validación personal: contraseña del administrador, recepción de correos externos y catálogo/dirección definitivos. No se debe anunciar la puesta en producción completa hasta cerrar esas comprobaciones. No hay pasarela bancaria, facturación electrónica, control de devolución de garantías ni recordatorios enviados. Una solicitud pública queda por confirmar hasta que el administrador registra la venta o reserva.
