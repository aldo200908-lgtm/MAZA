-- 1. Crea tu usuario desde Supabase > Authentication > Users > Add user.
-- 2. Sustituye el UUID aquí. No se crean usuarios ni contraseñas desde SQL.
-- 3. Ejecuta este bloque una vez, después de 001_maza.sql.
insert into public.app_admin(singleton,user_id,display_name)
values(true,'REEMPLAZA_POR_UUID_DE_AUTH_USERS'::uuid,'Administrador MAZA');
-- No hacer ON CONFLICT UPDATE: evitar reemplazar al dueño por accidente.
