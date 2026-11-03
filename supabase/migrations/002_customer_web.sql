-- MAZA Web: clientes autenticados, catálogo público y operaciones propias.
-- Ejecutar después de 001_maza.sql; nunca convierte a un cliente en administrador.
begin;
alter table public.clients add column auth_user_id uuid unique references auth.users(id) on delete set null;
alter table public.beauty_products add column description text not null default '';
alter table public.beauty_products add column category text not null default 'Cuidado';
alter table public.beauty_products add column image_url text not null default '';
alter table public.rental_assets add column description text not null default '';
alter table public.rental_assets add column category text not null default 'Equipamiento';
alter table public.rental_assets add column deposit_cents integer not null default 0 check(deposit_cents>=0);
alter table public.rental_assets add column image_url text not null default '';
create table public.business_settings (
 owner_id uuid primary key references public.app_admin(user_id),
 name text not null check(length(trim(name)) between 1 and 80),
 address text not null check(length(trim(address)) between 1 and 250),
 policy text not null check(length(trim(policy)) between 1 and 1000)
);
alter table public.business_settings enable row level security;
revoke all on public.business_settings from anon,authenticated;
grant select,insert,update on public.business_settings to authenticated;
create policy admin_settings on public.business_settings for all to authenticated using(owner_id=auth.uid() and exists(select 1 from public.app_admin where user_id=auth.uid())) with check(owner_id=auth.uid() and exists(select 1 from public.app_admin where user_id=auth.uid()));
create table public.customer_requests (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.app_admin(user_id),client_id uuid not null,
 product_id uuid,asset_id uuid,
 item_id uuid generated always as(coalesce(product_id,asset_id)) stored,
 item_name text not null,kind text not null check(kind in('product','rental')),
 quantity integer not null check(quantity between 1 and 20),amount_cents integer not null check(amount_cents>=0),
 starts_on date,ends_on date,status text not null default 'pending' check(status in('pending','handled','rejected')),
 created_at timestamptz not null default now(),
 foreign key(owner_id,client_id) references public.clients(owner_id,id),
 foreign key(owner_id,product_id) references public.beauty_products(owner_id,id),
 foreign key(owner_id,asset_id) references public.rental_assets(owner_id,id),
 check((kind='product' and product_id is not null and asset_id is null and starts_on is null and ends_on is null) or (kind='rental' and asset_id is not null and product_id is null and starts_on is not null and ends_on>starts_on))
);
alter table public.customer_requests enable row level security;
revoke all on public.customer_requests from anon,authenticated;
grant select on public.customer_requests to authenticated;
create policy admin_requests_read on public.customer_requests for select to authenticated using(owner_id=auth.uid() and exists(select 1 from public.app_admin where user_id=auth.uid()));
create index customer_requests_client on public.customer_requests(client_id,created_at desc);

create function public.web_catalog() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object(
 'services',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'price_cents',s.price_cents,'duration_minutes',s.duration_minutes,'active',s.active) order by s.name) from public.services s where s.active),'[]'::jsonb),
 'barbers',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'active',b.active,'weekdays',b.weekdays,'open_minute',b.open_minute,'close_minute',b.close_minute) order by b.name) from public.barbers b where b.active),'[]'::jsonb),
 'products',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'description',p.description,'category',p.category,'image_url',p.image_url,'price_cents',p.sale_price_cents,'kind','product','units',greatest(0,(select floor(coalesce(sum(m.quantity_delta),0))::int from public.stock_movements m where m.product_id=p.id))) order by p.name) from public.beauty_products p where p.active),'[]'::jsonb),
 'rentals',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name,'description',r.description,'category',r.category,'image_url',r.image_url,'price_cents',r.daily_rate_cents,'kind','rental','units',1,'deposit_cents',r.deposit_cents) order by r.name) from public.rental_assets r where r.active),'[]'::jsonb),
 'business',(select jsonb_build_object('name',name,'address',address,'policy',policy) from public.business_settings limit 1));
$$;
create function public.web_profile() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('id',id,'name',name,'phone',phone,'notes','') from public.clients where auth_user_id=auth.uid();
$$;
create function public.web_save_profile(p_name text,p_phone text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid(); owner uuid; normalized text;
begin
 if uid is null then raise insufficient_privilege using message='MAZA: Ingresa a tu cuenta.'; end if;
 if length(trim(p_name)) not between 1 and 100 or p_phone !~ '^(\+51\s?)?9[0-9]{8}$' then raise check_violation using message='MAZA: Revisa tu nombre y celular peruano.'; end if;
 select user_id into strict owner from public.app_admin;
 normalized:=regexp_replace(p_phone,'^(\+51\s?)?','');
 -- Nunca reclamar por teléfono la ficha de otra persona, aunque esté sin vincular.
 if exists(select 1 from public.clients where phone_normalized=normalized and auth_user_id is distinct from uid) then raise check_violation using message='MAZA: Ese celular ya tiene una ficha. Contacta al administrador para vincular tu cuenta.'; end if;
 insert into public.clients(owner_id,auth_user_id,name,phone) values(owner,uid,trim(p_name),p_phone)
 on conflict(auth_user_id) do update set name=excluded.name,phone=excluded.phone;
end $$;
create function public.web_my_appointments() returns setof jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select to_jsonb(a)-'owner_id' from public.appointments a join public.clients c on c.id=a.client_id where c.auth_user_id=auth.uid() order by a.starts_at desc;
$$;
create function public.web_slots(p_service uuid,p_day date,p_appointment uuid default null) returns table(barber_id uuid,starts_at timestamptz) language plpgsql stable security definer set search_path=public,pg_temp as $$
declare duration integer; owner uuid; existing public.appointments; only_barber uuid;
begin
 if p_day<(now() at time zone 'America/Lima')::date or p_day>(now() at time zone 'America/Lima')::date+90 then return; end if;
 if p_appointment is not null then
  select a.* into existing from public.appointments a join public.clients c on c.id=a.client_id where a.id=p_appointment and c.auth_user_id=auth.uid() and a.service_id=p_service and a.starts_at>now() and a.status in('pending','confirmed');
  if not found then raise insufficient_privilege using message='MAZA: No tienes acceso a esa cita.'; end if;
  duration:=existing.duration_minutes;owner:=existing.owner_id;only_barber:=existing.barber_id;
 else
  select duration_minutes,owner_id into duration,owner from public.services where id=p_service and active;
  if not found then return; end if;
 end if;
 return query select b.id,t.slot from public.barbers b cross join lateral generate_series(b.open_minute,b.close_minute-duration,15) as g(minute)
 cross join lateral (select (p_day+make_interval(mins=>g.minute)) at time zone 'America/Lima' as slot) t
 where b.owner_id=owner and b.active and (only_barber is null or b.id=only_barber) and extract(isodow from p_day)::int=any(b.weekdays) and t.slot>now()
 and not exists(select 1 from public.appointments a where a.barber_id=b.id and a.id is distinct from p_appointment and a.status in('pending','confirmed','completed') and a.starts_at<t.slot+make_interval(mins=>duration) and a.ends_at>t.slot)
 order by t.slot,b.id;
end $$;
create function public.web_book(p_service uuid,p_barber uuid,p_start timestamptz,p_notes text default '') returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.clients; a public.appointments;
begin
 select * into c from public.clients where auth_user_id=auth.uid();
 if not found then raise insufficient_privilege using message='MAZA: Completa tus datos antes de reservar.'; end if;
 if p_start is null or p_start<=now() or p_start>now()+interval '90 days' then raise check_violation using message='MAZA: Elige una cita futura dentro de 90 días.'; end if;
 if not exists(select 1 from public.web_slots(p_service,(p_start at time zone 'America/Lima')::date) s where s.barber_id=p_barber and s.starts_at=p_start) then raise check_violation using message='MAZA: Ese turno ya no está disponible. Elige otro.'; end if;
 insert into public.appointments(owner_id,client_id,service_id,barber_id,starts_at,notes) values(c.owner_id,c.id,p_service,p_barber,p_start,coalesce(p_notes,'')) returning * into a;
 return to_jsonb(a)-'owner_id';
end $$;
create function public.web_change_booking(p_id uuid,p_version integer,p_cancel boolean default false,p_start timestamptz default null) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare a public.appointments;
begin
 select x.* into a from public.appointments x join public.clients c on c.id=x.client_id where x.id=p_id and c.auth_user_id=auth.uid() for update of x;
 if not found then raise insufficient_privilege using message='MAZA: No tienes acceso a esa cita.'; end if;
 if a.version is distinct from p_version or a.starts_at<=now() or a.status not in('pending','confirmed') then raise check_violation using message='MAZA: Actualiza el historial. Solo puedes cambiar citas futuras pendientes o confirmadas.'; end if;
 if p_cancel then update public.appointments set status='cancelled' where id=a.id;
 else
  if p_start is null or p_start<=now() or p_start>now()+interval '90 days' then raise check_violation using message='MAZA: Elige un turno futuro dentro de 90 días.'; end if;
  if not exists(select 1 from public.web_slots(a.service_id,(p_start at time zone 'America/Lima')::date,a.id) s where s.barber_id=a.barber_id and s.starts_at=p_start) then raise check_violation using message='MAZA: Ese turno ya no está disponible.'; end if;
  update public.appointments set starts_at=p_start where id=a.id;
 end if;
end $$;
create function public.web_my_requests() returns setof jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select to_jsonb(r)-'owner_id' from public.customer_requests r join public.clients c on c.id=r.client_id where c.auth_user_id=auth.uid() order by r.created_at desc;
$$;
create function public.web_request_item(p_item uuid,p_kind text,p_quantity integer default 1,p_start date default null,p_end date default null) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.clients;p public.beauty_products;r public.rental_assets;request public.customer_requests;amount integer;label text;stock numeric;
begin
 select * into c from public.clients where auth_user_id=auth.uid();
 if not found then raise insufficient_privilege using message='MAZA: Completa tus datos antes de continuar.'; end if;
 if p_quantity is null or p_quantity not between 1 and 20 then raise check_violation using message='MAZA: Revisa la cantidad.'; end if;
 if p_kind='product' then
  select * into p from public.beauty_products where id=p_item and owner_id=c.owner_id and active;
  if not found then raise check_violation using message='MAZA: Producto no disponible.'; end if;
  select coalesce(sum(quantity_delta),0) into stock from public.stock_movements where product_id=p.id;
  if stock<p_quantity then raise check_violation using message='MAZA: No hay esa cantidad disponible.'; end if;
  amount:=p.sale_price_cents*p_quantity;label:=p.name;p_start:=null;p_end:=null;
 elsif p_kind='rental' then
  select * into r from public.rental_assets where id=p_item and owner_id=c.owner_id and active;
  if not found or p_quantity<>1 or p_start is null or p_end is null or p_start<(now() at time zone 'America/Lima')::date or p_end<=p_start or p_end-p_start>90 then raise check_violation using message='MAZA: Revisa el equipo y las fechas del alquiler.'; end if;
  if exists(select 1 from public.rental_bookings b where b.asset_id=r.id and b.status in('reserved','out','returned') and tstzrange(b.starts_at,b.ends_at,'[)')&&tstzrange(p_start::timestamp at time zone 'America/Lima',p_end::timestamp at time zone 'America/Lima','[)')) then raise check_violation using message='MAZA: El equipo no está disponible en esas fechas.'; end if;
  amount:=r.daily_rate_cents*(p_end-p_start);label:=r.name;
 else raise check_violation using message='MAZA: Tipo de solicitud no válido.';
 end if;
 insert into public.customer_requests(owner_id,client_id,product_id,asset_id,item_name,kind,quantity,amount_cents,starts_on,ends_on)
 values(c.owner_id,c.id,case when p_kind='product' then p_item end,case when p_kind='rental' then p_item end,label,p_kind,p_quantity,amount,p_start,p_end) returning * into request;
 return to_jsonb(request)-'owner_id';
end $$;
create function public.web_resolve_request(p_id uuid,p_status text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not exists(select 1 from public.app_admin where user_id=auth.uid()) then raise insufficient_privilege using message='MAZA: Solo el administrador puede atender solicitudes.'; end if;
 if p_status not in('handled','rejected') or p_status is null then raise check_violation using message='MAZA: Estado no válido.'; end if;
 update public.customer_requests set status=p_status where id=p_id and owner_id=auth.uid() and status='pending';
 if not found then raise check_violation using message='MAZA: La solicitud ya se atendió. Actualiza el panel.'; end if;
end $$;
-- Sin concesiones implícitas de EXECUTE a PUBLIC.
do $$ declare r record; begin
 for r in select p.oid::regprocedure as signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('web_catalog','web_profile','web_save_profile','web_my_appointments','web_slots','web_book','web_change_booking','web_my_requests','web_request_item','web_resolve_request') loop
 execute format('revoke all on function %s from public,anon,authenticated',r.signature);
 execute format('grant execute on function %s to authenticated',r.signature);
 if r.proname in('web_catalog','web_slots') then execute format('grant execute on function %s to anon',r.signature); end if;
 end loop;
end $$;
commit;
