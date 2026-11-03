-- Instalación opcional de propietario pendiente. Requiere migraciones 001 y 002.
-- Configurar el correo solo por SQL de administración; nunca desde el cliente.
begin;
create schema if not exists maza_private;
revoke all on schema maza_private from public,anon,authenticated;
create table maza_private.owner_setup (
 singleton boolean primary key default true check(singleton),
 email text not null check(email=lower(trim(email)) and position('@' in email)>1),
 assigned_user_id uuid references auth.users(id),
 created_at timestamptz not null default now()
);
alter table maza_private.owner_setup enable row level security;
revoke all on maza_private.owner_setup from public,anon,authenticated;
create function maza_private.activate_owner() returns trigger
language plpgsql security definer set search_path='' as $$
declare setup maza_private.owner_setup;
begin
 if new.email_confirmed_at is null or new.is_anonymous is true then return new; end if;
 select * into setup from maza_private.owner_setup
 where singleton and assigned_user_id is null and email=lower(new.email) for update;
 if not found then return new; end if;
 insert into public.app_admin(singleton,user_id,display_name)
 values(true,new.id,'Administrador MAZA') on conflict(singleton) do nothing;
 if exists(select 1 from public.app_admin where user_id=new.id) then
  update maza_private.owner_setup set assigned_user_id=new.id where singleton;
  insert into public.business_settings(owner_id,name,address,policy)
  values(new.id,'MAZA','Puno, Perú · dirección por confirmar',
   'Puedes cancelar o reprogramar antes del inicio de tu cita. Las solicitudes de productos y alquileres requieren confirmación.')
  on conflict(owner_id) do nothing;
 end if;
 return new;
end $$;
revoke all on function maza_private.activate_owner() from public,anon,authenticated;
create trigger maza_activate_owner after insert or update of email,email_confirmed_at on auth.users
for each row execute function maza_private.activate_owner();
commit;
