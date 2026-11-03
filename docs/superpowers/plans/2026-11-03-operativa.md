# MAZA operativa: implementación

Objetivo: conservar las pantallas aprobadas y convertir las acciones de stock, alquileres y abonos en operaciones persistentes de un único administrador. Web Flutter y Supabase existentes; sin pasarela bancaria. Los datos de demostración permanecen separados de producción.

- Base: migración de comandos administrativos atómicos e idempotentes; lectura privada del estado. Reutilizar RLS existente. Bloquear stock negativo, reservas superpuestas y abonos superiores al saldo. Crear cuentas al completar citas, vender productos y reservar equipos. Anular solo alquileres sin abonos; la garantía queda indicada, no contabilizada como ingreso.
- Pruebas SQL primero: permisos de anónimo/cliente, persistencia entre lecturas, precios del servidor, reintentos, sobreventa, alquileres y pagos parciales. Ejecutar en Postgres embebido; comprobar migración en Supabase con rollback para las pruebas.
- Flutter: repositorio administrativo conectado que implementa las mismas operaciones que el modo demo. Formularios asíncronos con bloqueo de doble envío, errores recuperables y claves estables por envío. Clientes existentes seleccionables para ventas y alquileres; vacíos seguros. Panel protegido, limpiar estado privado al cerrar sesión.
- Integración: todas las rutas administrativas usan las pantallas completas. Solicitudes públicas se confirman atómicamente en ventas o reservas; pueden rechazarse. Reportes derivados de los cobros registrados. No presentar avisos ficticios como reales.
- Validar: flutter analyze/test, SQL, build conectado y demo independiente. Publicar con CI y verificar catálogo y rutas en móvil. La validación del acceso real necesita que el titular use su propia contraseña; nunca pedirla ni modificarla desde el servidor.

Riesgos a revisar: reintento tras pérdida de conexión, formularios con catálogo vacío, sesión renovada/cerrada durante una petición, stock tomado por dos solicitudes, importes/categorías falsificados, citas completadas con cuenta existente.
