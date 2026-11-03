# Supabase de MAZA Web

Proyecto: `mfztfrgypemdchmyfknr`. La compilación pública usa `config/supabase.web.json` con la URL y la clave publishable. El nombre histórico `SUPABASE_ANON_KEY` es compatible con esa clave. No se distribuye ninguna clave secret/service_role.

Se aplican las migraciones base y web, y `supabase/owner_setup.sql`. Las tablas nuevas quedan vacías. No cargar los seeds de demo en este proyecto conectado.

## Configuración de Auth

En Authentication → URL Configuration establecer Site URL y añadir como Redirect URL exacta:

`https://aldo200908-lgtm.github.io/MAZA/`

Mantener el registro por email y la confirmación de correo activados. El registro y la recuperación incluyen esta URL. El servicio de correo incorporado de Supabase es para pruebas y tiene límites; antes de abrir registros al público configurar SMTP propio. No desactivar la confirmación para saltarse esta configuración.

## Activación del propietario

La instalación privada guarda el correo autorizado en `maza_private.owner_setup`; no forma parte del catálogo, del código cliente ni de los metadatos editables por el usuario. Se configura una vez desde una conexión de administración:

```sql
insert into maza_private.owner_setup(singleton,email)
values(true,'CORREO_DEL_PROPIETARIO_EN_MINUSCULAS');
```

El propietario crea su cuenta en `/#/acceso`, elige su contraseña y confirma el correo. El trigger solo asigna administración cuando Supabase marca ese correo exacto como verificado y la cuenta no es anónima. No sustituye un administrador existente y la configuración queda consumida después de asignarlo. La fila `app_admin` es la fuente de autorización. No se concede administración por `user_metadata` ni por un formulario cliente.

Después de confirmar el correo, ingresar en `/#/admin`. Crear los servicios, precios, barberos y horarios desde el panel y completar la dirección del negocio. Los pagos siguen desactivados.

## Verificación

`supabase/tests/owner_setup.sql` se ejecuta en una base de ensayo sin administrador, dentro de una transacción con rollback. Comprueba que un cliente distinto y un correo sin verificar no reciben acceso, que el propietario confirmado sí lo recibe y que ningún cliente puede reemplazarlo. El esquema privado no concede acceso a anon/authenticated. No ejecutar esta prueba sobre una instalación que ya tenga administrador.

Las tablas públicas tienen RLS. Se comprueba que anon no puede leer clientes ni citas. Las funciones públicas de catálogo y disponibilidad devuelven únicamente información pública; las operaciones de clientes exigen identidad, propiedad y validaciones en el servidor.

Los advisors señalan los endpoints RPC `SECURITY DEFINER` por su ejecución intencional: se revisaron los permisos explícitos, el `search_path` fijo y los filtros. Esos avisos no equivalen a tablas abiertas. Referencias: [RPC público](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable) y [RPC autenticado](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

La comprobación del correo real, inicio de sesión y reserva completa con una cuenta real requiere que su titular complete el registro; las pruebas no simulan haber recibido ese correo.
