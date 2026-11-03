-- Ejecutar en una base de ensayo sin administrador. No deja usuarios ni datos.
begin;
do $$
declare target uuid := gen_random_uuid(); stranger uuid := gen_random_uuid();
begin
 if exists(select 1 from public.app_admin) then
  raise exception 'Esta prueba necesita una base sin administrador';
 end if;
 if to_regclass('maza_private.owner_setup') is not null then
  execute 'insert into maza_private.owner_setup(singleton,email) values(true,$1) on conflict(singleton) do update set email=excluded.email,assigned_user_id=null'
  using 'owner-test@example.invalid';
 end if;
 insert into auth.users(id,email,email_confirmed_at,is_anonymous)
 values(stranger,'customer-test@example.invalid',now(),false);
 if exists(select 1 from public.app_admin) then
  raise exception 'Un cliente ajeno recibió administración';
 end if;
 insert into auth.users(id,email,is_anonymous)
 values(target,'owner-test@example.invalid',false);
 if exists(select 1 from public.app_admin) then
  raise exception 'Un correo sin verificar recibió administración';
 end if;
 update auth.users set email_confirmed_at=now() where id=target;
 if not exists(select 1 from public.app_admin where user_id=target) then
  raise exception 'El propietario verificado no recibió administración';
 end if;
 update auth.users set email_confirmed_at=now() where id=stranger;
 if (select count(*) from public.app_admin)<>1 or not exists(select 1 from public.app_admin where user_id=target) then
  raise exception 'Se reemplazó al propietario';
 end if;
 if has_schema_privilege('anon','maza_private','usage') or has_schema_privilege('authenticated','maza_private','usage') then
  raise exception 'La configuración privada quedó expuesta';
 end if;
end $$;
rollback;
