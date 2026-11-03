# Google en MAZA

La web muestra «Continuar con Google» cuando Supabase informa que el proveedor está habilitado. El acceso por correo permanece disponible. Google autentica al usuario; los permisos de administrador siguen ligados exclusivamente al usuario asignado en `app_admin`.

## Configuración

Crear o utilizar un cliente OAuth de tipo Aplicación web en Google Cloud / Google Auth Platform. Configurar nombre MAZA, audiencia externa y los permisos básicos `openid`, correo y perfil.

Origen JavaScript autorizado:

`https://aldo200908-lgtm.github.io`

URI de redirección autorizada en Google (sin barra final):

`https://mfztfrgypemdchmyfknr.supabase.co/auth/v1/callback`

En Supabase → Authentication → Sign In / Providers → Google: habilitar el proveedor y guardar el Client ID y Client Secret directamente allí. Nunca introducir el secreto en GitHub, Flutter, capturas o conversaciones.

En Supabase → Authentication → URL Configuration: Site URL y URL de redirección permitida:

`https://aldo200908-lgtm.github.io/MAZA/`

El proveedor aparece habilitado en la comprobación pública del 3 de noviembre de 2026. Según la configuración comunicada por el titular, Google está en modo de prueba con su correo permitido; la consola y los requisitos de publicación de Google deben revisarse antes de anunciar acceso para todos los clientes.

## Prueba con el titular

1. Recargar la web y abrir el acceso del panel.
2. Pulsar «Continuar con Google» y seleccionar la cuenta administradora existente.
3. Autorizar el acceso y comprobar el regreso a MAZA y la entrada al panel.
4. Crear una operación, recargar y verificar persistencia.
5. Probar también desde la reserva pública: elegir servicio y turno, identificarse y comprobar que se conserva la selección.

Abrir Google no equivale a iniciar sesión: Supabase valida el retorno y MAZA vuelve a comprobar los permisos en el servidor. Si Google devuelve otra identidad, no se asignan privilegios automáticamente ni se reemplaza al administrador.

El retorno guarda una ruta interna durante un máximo de 15 minutos, no la sesión ni los tokens recibidos de Google. La demo separada no se conecta a Google.

Referencia: https://supabase.com/docs/guides/auth/social-sign-in/auth-google
