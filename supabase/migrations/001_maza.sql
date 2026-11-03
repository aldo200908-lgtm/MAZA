-- MAZA v1. Ejecutar una vez en un proyecto Supabase vacío.
begin;
create extension if not exists btree_gist with schema extensions;

-- BASE. El administrador se asigna por SQL, nunca desde la aplicación.
create table public.app_admin (
 singleton boolean primary key default true check(singleton),
 user_id uuid not null unique references auth.users(id) on delete restrict,
 display_name text not null default 'Administrador',
 created_at timestamptz not null default now()
);
create table public.clients (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.app_admin(user_id),
 name text not null check(length(trim(name)) between 1 and 100),
 phone text not null check(phone ~ '^(\+51\s?)?9[0-9]{8}$'),
 phone_normalized text generated always as (regexp_replace(phone,'^(\+51\s?)?','')) stored,
 notes text not null default '' check(length(notes)<=1000),
 created_at timestamptz not null default now(),
 unique(owner_id,id), unique(owner_id,phone_normalized)
);
-- BARBERÍA. Un intervalo diario y varios días por barbero en esta versión.
create table public.services (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.app_admin(user_id),
 name text not null check(length(trim(name)) between 1 and 100),
 price_cents integer not null check(price_cents between 0 and 99999999),
 duration_minutes integer not null check(duration_minutes between 5 and 480),
 active boolean not null default true,
 created_at timestamptz not null default now(), unique(owner_id,id)
);
create table public.barbers (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.app_admin(user_id),
 name text not null check(length(trim(name)) between 1 and 100),
 active boolean not null default true,
 weekdays integer[] not null default array[1,2,3,4,5,6]
   check(cardinality(weekdays)>0 and weekdays <@ array[1,2,3,4,5,6,7] and array_position(weekdays,null) is null),
 open_minute integer not null default 540 check(open_minute between 0 and 1438),
 close_minute integer not null default 1200 check(close_minute between 1 and 1439 and close_minute>open_minute),
 created_at timestamptz not null default now(), unique(owner_id,id)
);
-- CITAS. Las instantáneas se completan en el servidor y son inmutables.
create table public.appointments (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.app_admin(user_id),
 client_id uuid not null,
 barber_id uuid not null,
 service_id uuid not null,
 service_name text not null,
 price_cents integer not null check(price_cents>=0),
 duration_minutes integer not null check(duration_minutes between 5 and 480),
 starts_at timestamptz not null,
 ends_at timestamptz not null check(ends_at>starts_at),
 status text not null default 'pending' check(status in ('pending','confirmed','completed','cancelled','no_show')),
 version integer not null default 1 check(version>0),
 notes text not null default '' check(length(notes)<=500),
 created_at timestamptz not null default now(), unique(owner_id,id),
 foreign key(owner_id,client_id) references public.clients(owner_id,id),
 foreign key(owner_id,barber_id) references public.barbers(owner_id,id),
 foreign key(owner_id,service_id) references public.services(owner_id,id),
 constraint no_barber_overlap exclude using gist (barber_id with =,tstzrange(starts_at,ends_at,'[)') with &&)
   where(status in ('pending','confirmed','completed'))
);
create index appointments_day on public.appointments(owner_id,starts_at);
create index appointments_client_history on public.appointments(owner_id,client_id,starts_at desc);

create function public.appointment_guard() returns trigger
language plpgsql set search_path=public,pg_temp as $$
declare s public.services; b public.barbers; local_start timestamp; local_end timestamp; validate_slot boolean;
begin
 if tg_op='INSERT' then
   select * into s from public.services where id=new.service_id and owner_id=new.owner_id and active for share;
   if not found then raise check_violation using message='MAZA: Selecciona un servicio activo.'; end if;
   new.service_name:=s.name; new.price_cents:=s.price_cents; new.duration_minutes:=s.duration_minutes;
   new.version:=1;
   validate_slot:=true;
 else
   if (new.id,new.owner_id,new.client_id,new.barber_id,new.service_id,new.service_name,new.price_cents,new.duration_minutes,new.created_at)
      is distinct from (old.id,old.owner_id,old.client_id,old.barber_id,old.service_id,old.service_name,old.price_cents,old.duration_minutes,old.created_at) then
      raise check_violation using message='MAZA: Los datos históricos de la cita no se pueden cambiar.';
   end if;
   if old.status='completed' and new.starts_at<>old.starts_at then
      raise check_violation using message='MAZA: Una cita completada conserva su fecha histórica.';
   end if;
   new.version:=old.version+1;
   validate_slot:=new.starts_at<>old.starts_at or
     (old.status in ('cancelled','no_show') and new.status in ('pending','confirmed','completed'));
 end if;
 new.ends_at:=new.starts_at+make_interval(mins=>new.duration_minutes);
 if validate_slot then
   select * into b from public.barbers where id=new.barber_id and owner_id=new.owner_id and active for share;
   if not found then raise check_violation using message='MAZA: Selecciona un barbero activo.'; end if;
   local_start:=new.starts_at at time zone 'America/Lima'; local_end:=new.ends_at at time zone 'America/Lima';
   if not (extract(isodow from local_start)::int=any(b.weekdays)) or local_start::date<>local_end::date or
      extract(hour from local_start)*60+extract(minute from local_start)<b.open_minute or
      extract(hour from local_end)*60+extract(minute from local_end)>b.close_minute or
      extract(second from local_start)<>0 then
     raise check_violation using message='MAZA: La cita debe quedar completa dentro del horario del barbero.';
   end if;
 end if;
 return new;
end $$;
create trigger appointment_guard before insert or update on public.appointments for each row execute function public.appointment_guard();

-- STOCK DE BELLEZA. Catálogo + libro de movimientos; sin filas en la demo.
create table public.beauty_products (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.app_admin(user_id),
 sku text not null, name text not null check(length(trim(name))>0), unit text not null default 'unidad',
 sale_price_cents integer not null default 0 check(sale_price_cents>=0), reorder_level numeric(12,3) not null default 0 check(reorder_level>=0),
 active boolean not null default true, unique(owner_id,id), unique(owner_id,sku)
);
create table public.stock_movements (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.app_admin(user_id),
 product_id uuid not null, quantity_delta numeric(12,3) not null check(quantity_delta<>0),
 kind text not null check(kind in ('opening','purchase','sale','consumption','adjustment')),
 unit_cost_cents integer check(unit_cost_cents>=0),notes text not null default '', occurred_at timestamptz not null default now(),
 foreign key(owner_id,product_id) references public.beauty_products(owner_id,id), unique(owner_id,id)
);
create index stock_product_ledger on public.stock_movements(owner_id,product_id,occurred_at);

-- ALQUILERES. Cada activo representa un bien físico individual.
create table public.rental_assets (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.app_admin(user_id),
 code text not null,name text not null check(length(trim(name))>0),daily_rate_cents integer not null default 0 check(daily_rate_cents>=0),
 active boolean not null default true,unique(owner_id,id),unique(owner_id,code)
);
create table public.rental_contracts (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.app_admin(user_id),client_id uuid not null,
 status text not null default 'draft' check(status in ('draft','confirmed','active','returned','cancelled')),
 deposit_cents integer not null default 0 check(deposit_cents>=0),notes text not null default '',created_at timestamptz not null default now(),
 foreign key(owner_id,client_id) references public.clients(owner_id,id),unique(owner_id,id)
);
create table public.rental_bookings (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.app_admin(user_id),
 contract_id uuid not null,asset_id uuid not null,starts_at timestamptz not null,ends_at timestamptz not null check(ends_at>starts_at),
 asset_name text not null,rate_cents integer not null check(rate_cents>=0),returned_at timestamptz,
 status text not null default 'reserved' check(status in ('reserved','out','returned','cancelled')),
 foreign key(owner_id,contract_id) references public.rental_contracts(owner_id,id),
 foreign key(owner_id,asset_id) references public.rental_assets(owner_id,id),unique(owner_id,id),
 constraint no_asset_overlap exclude using gist(asset_id with =,tstzrange(starts_at,ends_at,'[)') with &&) where(status in ('reserved','out','returned'))
);

-- PAGOS. Cuentas por cobrar separadas del medio de pago. Sin pasarela activa.
create table public.receivables (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.app_admin(user_id),client_id uuid not null,
 appointment_id uuid,rental_contract_id uuid,stock_sale_movement_id uuid,
 amount_cents integer not null check(amount_cents>0),currency text not null default 'PEN' check(currency='PEN'),
 description text not null,created_at timestamptz not null default now(),unique(owner_id,id),
 check(num_nonnulls(appointment_id,rental_contract_id,stock_sale_movement_id)=1),
 foreign key(owner_id,client_id) references public.clients(owner_id,id),
 foreign key(owner_id,appointment_id) references public.appointments(owner_id,id),
 foreign key(owner_id,rental_contract_id) references public.rental_contracts(owner_id,id),
 foreign key(owner_id,stock_sale_movement_id) references public.stock_movements(owner_id,id)
);
create unique index one_appointment_receivable on public.receivables(appointment_id) where appointment_id is not null;
create unique index one_rental_receivable on public.receivables(rental_contract_id) where rental_contract_id is not null;
create unique index one_stock_receivable on public.receivables(stock_sale_movement_id) where stock_sale_movement_id is not null;
create table public.payments (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.app_admin(user_id),receivable_id uuid not null,
 amount_cents integer not null check(amount_cents>0),currency text not null default 'PEN' check(currency='PEN'),
 method text not null check(method in ('cash','yape','plin','transfer','gateway')),
 status text not null default 'pending' check(status in ('pending','settled','failed','cancelled')),
 provider text,provider_reference text,idempotency_key uuid not null default gen_random_uuid(),paid_at timestamptz,
 foreign key(owner_id,receivable_id) references public.receivables(owner_id,id),unique(owner_id,id),unique(owner_id,idempotency_key),unique(provider,provider_reference)
);
create table public.refunds (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.app_admin(user_id),payment_id uuid not null,
 amount_cents integer not null check(amount_cents>0),reason text not null,
 status text not null default 'pending' check(status in ('pending','settled','failed')),
 provider_reference text,created_at timestamptz not null default now(),
 foreign key(owner_id,payment_id) references public.payments(owner_id,id),unique(owner_id,id)
);
create table public.payment_events (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.app_admin(user_id),
 payment_id uuid,provider text not null,event_id text not null,payload jsonb not null,received_at timestamptz not null default now(),
 foreign key(owner_id,payment_id) references public.payments(owner_id,id),unique(provider,event_id)
);

-- RLS: ni anon ni otros usuarios autenticados acceden a los datos.
alter table public.app_admin enable row level security;
revoke all on public.app_admin from anon,authenticated;
grant select on public.app_admin to authenticated;
create policy admin_self on public.app_admin for select to authenticated using(user_id=(select auth.uid()));
do $$
declare t text;
begin
 foreach t in array array['clients','services','barbers','appointments','beauty_products','stock_movements','rental_assets','rental_contracts','rental_bookings','receivables','payments','refunds','payment_events'] loop
   execute format('alter table public.%I enable row level security',t);
   execute format('revoke all on public.%I from anon,authenticated',t);
   -- Módulos futuros son de solo lectura desde la app hasta implementar sus operaciones seguras.
   execute format('grant select on public.%I to authenticated',t);
   if t=any(array['clients','services','barbers','appointments']) then
      execute format('grant insert,update on public.%I to authenticated',t);
   end if;
   execute format('create policy admin_owner on public.%I for all to authenticated using (owner_id=(select auth.uid()) and exists(select 1 from public.app_admin where user_id=(select auth.uid()))) with check (owner_id=(select auth.uid()) and exists(select 1 from public.app_admin where user_id=(select auth.uid())))',t);
 end loop;
end $$;
revoke all on function public.appointment_guard() from public,anon,authenticated;
commit;
