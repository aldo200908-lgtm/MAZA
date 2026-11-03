# MAZA · Demo visual completa

Alcance: web de cliente y panel de administrador. Se conserva la identidad crema/carbón/naranja y el código Flutter por módulos. La futura app móvil es independiente.

- Público: inicio adaptable con tarjeta de próxima visita, catálogo/búsqueda, perfiles del equipo y horarios, reserva, solicitudes y cuenta con accesos rápidos.
- Administración: resumen operativo, agenda, barbería, clientes, stock con editor/ajustes/movimientos, equipos con tarifas/garantías y reservas por fechas, estados de entrega/devolución, solicitudes, pagos de ejemplo con saldos/abonos/detalle, reportes por actividad, avisos y preferencias visuales.
- La edición de inventario se refleja en el catálogo de la misma sesión. Los alquileres comprueban solapamientos; los abonos no pueden superar el saldo. Un abono simulado actualiza el resumen y los reportes.
- La demostración se publica en la URL principal, sin inicializar Supabase y con identidades ficticias. La configuración de autenticación principal se conserva para retomar al final.

Los módulos nuevos no escriben pagos, contratos o inventario reales. No se presentan simulaciones como operaciones efectivas. Los cambios de esos módulos son locales a la sesión y se restablecen al recargar; la persistencia de citas/perfil de ejemplo ya existente se conserva.
