# MAZA — diseño aprobado
Demo Flutter para web y teléfono, un administrador, interfaz en español, moneda PEN y horario America/Lima (UTC−05 sin horario estacional).
Base: login Supabase, recuperación, sesión, navegación inferior/adaptada y tema marfil/carbón/naranja.
Citas: día/semana, filtros, creación, reprogramación y estados. Impedir solapamientos en cliente y servidor. Precio y duración históricos inmutables.
Barbería: servicios, barberos, horarios semanales, clientes e historial.
Stock, Alquileres y Pagos: solo pantallas vacías y esquema separado, sin movimientos ni cobros.
Arquitectura elegida: Flutter Material 3 con repositorio intercambiable (demo local persistente / Supabase), ChangeNotifier y módulos. Evita una segunda implementación de UI. No se usa una web separada ni backends distintos para teléfono y web.
Modo demo explícito y sin credenciales; no pretende autenticar. Modo conectado sin acceso anónimo a datos, un administrador provisionado por SQL y RLS en todas las tablas.
Entrega: fuente completa, proyectos Android/web, SQL, pruebas y guía. No publicar ni conectar cuentas externas.
