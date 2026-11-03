# MAZA Web v2 — registro de ejecución
Diseño aprobado en docs/superpowers/specs/2026-11-02-maza-web.md. Implementación en rama feat/maza-public-web; publicación autorizada en MAZA/main.
Decisión: únicamente Flutter Web. No modificar ni compilar Android; futura app aparte.
Decisión: conservar demo pública con acceso administrativo identificado como demo; autenticación real requiere Supabase configurado por el usuario.
Decisión: Stock/Alquileres muestran catálogo y solicitudes, sin inventar movimientos ni contratos; Pagos sin cobros.
Revisión independiente: se corrigen horarios antiguos mientras carga otra consulta, propagación de cambios admin en modo conectado y errores posteriores a una solicitud ya guardada. También se separan alertas de productos/alquileres y se invalida disponibilidad al cambiar la cita en la URL.
Verificación SQL: ambas migraciones, semillas, RLS, reserva con identidad propia, bloqueo de cita ajena, dos clientes aislados y no apropiación por teléfono probados en PostgreSQL embebido.
Validación final: 30 pruebas locales (una de QA visual), análisis sin incidencias, migraciones/pruebas SQL correctas y build release /MAZA/ correcto. El SDK falló en su optimizador de fuentes de iconos; se conserva la fuente completa con --no-tree-shake-icons y se usa la misma opción en CI.

Regresión de navegación: volver a tocar Inicio o Gestión restablece la raíz de esa pestaña, evitando quedar atrapado en búsqueda o una ficha. Prueba RED→GREEN añadida.
