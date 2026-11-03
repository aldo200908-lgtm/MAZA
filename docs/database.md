# Esquema MAZA v1

Cinco módulos operativos (**Citas, Barbería, Stock de belleza, Alquileres, Pagos**) más la Base de acceso. La migración completa es `supabase/migrations/001_maza.sql`; este documento describe sus límites, no sustituye el SQL.

| Área | Tablas | Relaciones y regla principal |
|---|---|---|
| Base | `app_admin`, `clients` | Un solo UUID de Auth; clientes comunes a los módulos. Teléfono peruano normalizado y único por dueño. |
| Barbería | `services`, `barbers` | Precio en céntimos, duración, activo; días ISO 1–7 y un intervalo diario por barbero. |
| Citas | `appointments` | Cliente, barbero y servicio con FK; instantánea de nombre, precio y duración; inicio/fin UTC; estado, notas y versión. |
| Stock | `beauty_products`, `stock_movements` | El producto se relaciona solo con su libro de entradas/salidas. No hay `appointment_id` en el stock. Saldo futuro = suma de movimientos. |
| Alquileres | `rental_assets`, `rental_contracts`, `rental_bookings` | Cada activo es un bien físico, no un producto consumible. Contrato por cliente y reservas por activo con rango temporal independiente. |
| Pagos | `receivables`, `payments`, `refunds`, `payment_events` | Cuenta por cobrar con exactamente un origen tipado: cita, contrato o movimiento de venta. Abonos/devoluciones/eventos separados. |

## Integridad y acceso

- Todas las tablas usan UUID. Las entidades de negocio llevan `owner_id` y claves compuestas `(owner_id,id)` en las referencias: evita enlazar registros de otro dueño.
- `app_admin.singleton` es booleano, clave primaria y solo admite `true`. No puede haber un segundo administrador. Los usuarios autenticados solo leen su propia autorización y no pueden cambiarla.
- RLS activo en **todas** las tablas. `anon` no recibe permisos. Las políticas exigen que `auth.uid()` sea el administrador y coincida con `owner_id`.
- El cliente puede leer/insertar/actualizar Base/Barbería/Citas. No hay DELETE. Los módulos futuros son de solo lectura desde la app, hasta tener funciones transaccionales seguras.
- La sesión y la autorización son cosas distintas: un usuario de Auth sin fila en `app_admin` no tiene acceso a MAZA.

## Citas

`appointments` almacena la instantánea del servicio al reservar. Un trigger obtiene nombre/precio/duración desde un servicio activo; el cliente no decide esos valores. Después son inmutables, al igual que cliente, barbero, servicio y propietario. Para cambiar esos vínculos se cancela y se crea una nueva cita.

El trigger fija `ends_at`, comprueba días/horas en `America/Lima` y evita cambiar la fecha de una cita completada. Una exclusión GiST aplica rangos **[inicio, fin)** por barbero: 10:00–10:30 y 10:30–11:00 pueden coexistir; 10:15 no. La restricción se aplica incluso con escrituras concurrentes. Pendiente, confirmada y completada ocupan el intervalo; cancelada/no asistió lo liberan. Reactivar una cita vuelve a validar el horario y el conflicto.

Cada modificación incrementa `version`. El adaptador actualiza por `id + version` y exige una fila devuelta; una sesión obsoleta recibe un aviso para recargar en lugar de sobrescribir cambios ajenos. Dentro de una sesión se coordinan las recargas y escrituras.

`starts_at`/`ends_at` son `timestamptz`, y la app envía UTC. La UI convierte explícitamente a Perú (UTC−05), sin depender de la zona del teléfono. El calendario y las métricas agrupan por fecha peruana.

## Por qué stock y alquileres no se mezclan con citas

Compartir `clients` y el propietario es suficiente. Stock lleva cantidades y unidades; alquileres lleva bienes físicos y periodos; citas llevan tiempo de barbero y servicio. No se usa una tabla universal `reservas` ni identificadores polimórficos sin FK.

Los alquileres tienen su propia exclusión de periodos para un activo físico. El estado `returned` conserva el periodo histórico reservado; una cancelación lo libera. Todavía no hay lógica de entrega, prórroga, devolución anticipada, depósito o cobro; se implementará dentro de ese módulo.

El stock está vacío y su ledger es solo una base. Antes de habilitar ventas/consumos, añadir una función transaccional que valide saldo, signo/tipo del movimiento, costo y reversión; el esquema no anuncia que ya exista control de stock negativo.

## Preparar pagos al final sin rehacer el resto

Se mantiene Flutter + Supabase. El orden será: **datos y reglas → citas/barbería → operaciones de stock/alquileres → cuentas y pagos → pasarela**. No se integra un cobro real en esta versión.

El riesgo de dejar todo el diseño financiero para el final es confundir «servicio completado» con «pagado», perder el precio acordado, contar dos veces un webhook o no poder representar un abono/devolución. Aquí ya hay instantáneas monetarias, orígenes con FK, una moneda PEN, claves de idempotencia y eventos únicos por proveedor.

`receivables` representa una cuenta; `payments` permite varios abonos; `refunds` permite devoluciones ligadas al abono original. No se crea una cuenta automáticamente por completar una cita. El panel muestra **valor atendido**, nunca ingresos cobrados.

Antes de activar pagos faltará implementar:

1. Funciones transaccionales o Edge Functions que comprueben saldo, moneda, consistencia del cliente/origen, abonos máximos y devoluciones acumuladas. Estos checks entre filas no están implementados en esta demo.
2. Webhooks verificados con firma y claves secretas solo en servidor; el teléfono nunca puede declarar un pago liquidado.
3. Idempotencia de eventos, transiciones permitidas, conciliación, auditoría y reintentos. Un índice único es una base, no un procesador de eventos completo.
4. Política para anticipos de alquiler, garantías/devolución de depósitos, cancelaciones, descuentos e impuestos. Configurar la pasarela y documentos aplicables cuando se defina el negocio.

Las tablas futuras no admiten escrituras del rol `authenticated`; por eso sus reglas aún pendientes no quedan expuestas como funcionalidades operativas.

## Pruebas entregadas

- `invariants.sql`: solapamiento, turno contiguo, horario, instantánea histórica, versión y sesión obsoleta.
- `access.sql`: usuario ajeno sin lectura/escritura, administrador autorizado y prohibición de modificar permisos/módulos futuros.
- `tool/sql_check.mjs`: ejecuta migración/seed/pruebas en PostgreSQL embebido; prepara un `auth` mínimo exclusivamente en memoria.

## Ampliación Web v2

`002_customer_web.sql` añade vínculo único `clients.auth_user_id`, datos públicos de negocio y fichas descriptivas de catálogo. `customer_requests` representa consultas de producto o alquiler con claves foráneas tipadas, instantánea de artículo/importe y estado pendiente/atendida/no disponible; no representa un cobro ni un contrato confirmado.

Los clientes usan funciones RPC con propiedad explícita por `auth.uid()`. No se amplía la lectura directa de clientes/citas: sus notas internas siguen restringidas al administrador. Solo `web_catalog` y `web_slots` se conceden a `anon`. Se revoca EXECUTE de PUBLIC en las funciones web. Las funciones se ejecutan con search_path fijado y no aceptan identidad del cliente en los parámetros.

La reprogramación usa la duración original, incluso si cambia el catálogo, y solo admite el mismo barbero. Una sesión obsoleta, una cita ajena, completada, cancelada o pasada no puede modificarse por el cliente.

Pendiente antes de operar stock/alquileres completos: edición de catálogo, funciones de movimientos y saldo, contratos, entrega/devolución y garantías. La web permite enviar y atender solicitudes sin habilitar esas operaciones ni pagos.
