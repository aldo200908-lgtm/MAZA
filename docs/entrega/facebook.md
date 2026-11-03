# Activar Facebook en MAZA

El código está preparado. El botón aparece solo cuando el endpoint público de Supabase informa que Facebook está habilitado. El acceso por correo sigue disponible. No incluir el App Secret de Meta en Flutter, GitHub, capturas ni conversaciones.

1. Crear o abrir una app de MAZA en Meta for Developers y agregar Facebook Login / el caso de uso de autenticación y creación de cuentas.
2. Habilitar los permisos `public_profile` y `email` en el caso de uso. La cuenta de prueba debe tener correo confirmado en Facebook y ser administradora/desarrolladora/tester de la app mientras esté en desarrollo.
3. En Facebook Login, añadir exactamente esta URI de redirección OAuth válida (sin barra final):

   `https://mfztfrgypemdchmyfknr.supabase.co/auth/v1/callback`

4. En Supabase, proyecto MAZA → Authentication → Sign In / Providers → Facebook, activar el proveedor y escribir allí el App ID y App Secret de Meta. Guardar. No compartir el secreto con el desarrollador por chat.
5. En Supabase → Authentication → URL Configuration, conservar Site URL y la URL permitida de redirección de MAZA:

   `https://aldo200908-lgtm.github.io/MAZA/`

6. Recargar la web: aparecerá «Continuar con Facebook». Probar desde Mi cuenta; elegir un servicio, iniciar sesión con Facebook y verificar que vuelve a la reserva. Confirmar una cita y revisar que solo aparecen los datos propios. Probar también cancelar el consentimiento y volver a entrar por correo.
7. Para permitir el acceso a clientes ajenos al equipo de prueba, completar los requisitos que Meta muestre (dominio, icono, política de privacidad publicada y los requisitos de datos/eliminación que correspondan), revisión/verificación si se solicita, y poner la app disponible para el público. Habilitar el proveedor en Supabase no publica por sí mismo la app de Meta.

El login social no concede permisos administrativos: el servidor conserva el UUID único del administrador. Una cuenta de Facebook distinta no se convierte en administradora por conocer el correo. Si el titular necesita entrar como administrador por Facebook, verificar que la identidad quede vinculada al usuario administrador existente; no sustituir el administrador ni asignar permisos basados en datos de perfil editables.

El retorno guarda únicamente una ruta interna durante 15 minutos; no guarda tokens de Facebook ni secretos de Meta. El SDK de Supabase valida la sesión al regresar. Esta integración no está comprobada contra Meta hasta configurar las credenciales y completar una entrada real.

Referencia: https://supabase.com/docs/guides/auth/social-sign-in/auth-facebook
