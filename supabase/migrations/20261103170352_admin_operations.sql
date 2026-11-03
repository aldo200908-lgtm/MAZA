-- Operaciones administrativas. Todos los importes se calculan en el servidor.
begin;
create schema if not exists maza_private;
revoke all on schema maza_private from public,anon,authenticated;
create table maza_private.commands (
 owner_id uuid not null references public.app_admin(user_id),
 key uuid not null, action text not null, data jsonb not null,
 created_at timestamptz not null default now(), primary key(owner_id,key)
);
alter table maza_private.commands enable row level security;
revoke all on maza_private.commands from public,anon,authenticated;

create function public.admin_snapshot() returns jsonb
language plpgsql security definer set search_path='' as $$
declare o uuid:=auth.uid(); result jsonb;
begin
 if o is null or not exists(select 1 from public.app_admin where user_id=o) then
  raise insufficient_privilege using message='MAZA: Acceso exclusivo del administrador.';
 end if;
 select jsonb_build_object(
  'products',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'description',p.description,'category',p.category,'image_url',p.image_url,'kind','product','price_cents',p.sale_price_cents,'units',coalesce((select sum(m.quantity_delta)::int from public.stock_movements m where m.owner_id=o and m.product_id=p.id),0))) from public.beauty_products p where p.owner_id=o and p.active),'[]'::jsonb),
  'rental_items',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'description',a.description,'category',a.category,'image_url',a.image_url,'kind','rental','price_cents',a.daily_rate_cents,'deposit_cents',a.deposit_cents,'units',1)) from public.rental_assets a where a.owner_id=o and a.active),'[]'::jsonb),
  'movements',coalesce((select jsonb_agg(x order by x.occurred_at desc) from (select p.name as item,m.quantity_delta::int as delta,m.notes as reason,m.occurred_at from public.stock_movements m join public.beauty_products p on p.id=m.product_id and p.owner_id=m.owner_id where m.owner_id=o) x),'[]'::jsonb),
  'rentals',coalesce((select jsonb_agg(x order by x.starts_at desc) from (select b.id,c.name as client,b.asset_id,b.asset_name,b.starts_at,b.ends_at,b.rate_cents*greatest(1,ceil(extract(epoch from(b.ends_at-b.starts_at))/86400))::int as amount,ct.deposit_cents,b.status from public.rental_bookings b join public.rental_contracts ct on ct.id=b.contract_id and ct.owner_id=b.owner_id join public.clients c on c.id=ct.client_id and c.owner_id=ct.owner_id where b.owner_id=o) x),'[]'::jsonb),
  'payment_history',coalesce((select jsonb_agg(jsonb_build_object('receivable_id',py.receivable_id,'amount',py.amount_cents,'method',py.method,'paid_at',py.paid_at) order by py.paid_at desc,py.id) from public.payments py where py.owner_id=o and py.status='settled'),'[]'::jsonb),
  'charges',coalesce((select jsonb_agg(x order by x.created_at desc) from (select r.id,c.name as client,r.description as detail,r.amount_cents as total,coalesce((select sum(p.amount_cents) from public.payments p where p.owner_id=o and p.receivable_id=r.id and p.status='settled'),0)::int as paid,coalesce((select p.method from public.payments p where p.owner_id=o and p.receivable_id=r.id and p.status='settled' order by p.paid_at desc,p.id limit 1),'') as method,case when r.appointment_id is not null then 'Barbería' when r.rental_contract_id is not null then 'Alquileres' else 'Productos' end as category,r.created_at from public.receivables r join public.clients c on c.id=r.client_id and c.owner_id=r.owner_id where r.owner_id=o) x),'[]'::jsonb)
 ) into result;
 return result;
end $$;
revoke all on function public.admin_snapshot() from public,anon,authenticated;
grant execute on function public.admin_snapshot() to authenticated;

create function public.admin_operate(p_key uuid,p_action text,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 o uuid:=auth.uid(); previous maza_private.commands; v_id uuid; client uuid; asset uuid;
 p public.beauty_products; a public.rental_assets; b public.rental_bookings;
 r public.receivables; req public.customer_requests;
 delta int; qty int; price int; guarantee int; stock numeric; paid bigint; amount bigint;
 start_day date; end_day date; contract uuid; movement uuid;
 rental boolean; state text; action text:=p_action; d jsonb:=p_data;
begin
 -- Un único administrador; este bloqueo serializa todos sus comandos y reintentos.
 perform 1 from public.app_admin where user_id=o for update;
 if not found then raise insufficient_privilege using message='MAZA: Acceso exclusivo del administrador.'; end if;
 if p_key is null or p_data is null or jsonb_typeof(p_data)<>'object' then
  raise check_violation using message='MAZA: Solicitud incompleta.';
 end if;
 select * into previous from maza_private.commands where owner_id=o and key=p_key;
 if found then
  if previous.action is distinct from p_action or previous.data is distinct from p_data then
   raise check_violation using message='MAZA: Este envío ya fue utilizado. Abre el formulario otra vez.';
  end if;
  return public.admin_snapshot();
 end if;
 if action='fulfill_request' then
  select * into req from public.customer_requests where id=(d->>'id')::uuid and owner_id=o for update;
  if not found or req.status<>'pending' then raise check_violation using message='MAZA: La solicitud ya fue atendida o no existe.'; end if;
  if req.kind='product' then
   action:='sale'; d:=jsonb_build_object('id',req.product_id,'client',req.client_id,'quantity',req.quantity);
  else
   action:='rental_create'; d:=jsonb_build_object('asset',req.asset_id,'client',req.client_id,'start',req.starts_on,'end',req.ends_on);
  end if;
 end if;
 case action
 when 'save_item' then
  v_id:=(d->>'id')::uuid; rental:=(d->>'rental')::boolean; price:=(d->>'price')::int; guarantee:=(d->>'deposit')::int; qty:=(d->>'units')::int;
  if v_id is null or rental is null or price is null or price<0 or price>99999999 or guarantee is null or guarantee<0 or guarantee>99999999 or qty is null or qty<0 or qty>1000000 or nullif(trim(d->>'name'),'') is null or length(d->>'name')>100 or length(d->>'description')>2000 or length(d->>'category')>100 then
   raise check_violation using message='MAZA: Revisa el nombre, las unidades y los importes.';
  end if;
  if rental then
   insert into public.rental_assets(id,owner_id,code,name,daily_rate_cents,description,category,deposit_cents)
   values(v_id,o,v_id::text,trim(d->>'name'),price,coalesce(d->>'description',''),coalesce(d->>'category',''),guarantee)
   on conflict(id) do update set name=excluded.name,daily_rate_cents=excluded.daily_rate_cents,description=excluded.description,category=excluded.category,deposit_cents=excluded.deposit_cents where public.rental_assets.owner_id=o;
  else
   select * into p from public.beauty_products where beauty_products.id=v_id and owner_id=o;
   if found then
    update public.beauty_products set name=trim(d->>'name'),sale_price_cents=price,description=coalesce(d->>'description',''),category=coalesce(d->>'category','') where beauty_products.id=v_id and owner_id=o;
   else
    insert into public.beauty_products(id,owner_id,sku,name,sale_price_cents,description,category,reorder_level) values(v_id,o,v_id::text,trim(d->>'name'),price,coalesce(d->>'description',''),coalesce(d->>'category',''),3);
    if qty>0 then insert into public.stock_movements(owner_id,product_id,quantity_delta,kind,notes) values(o,v_id,qty,'opening','Stock inicial'); end if;
   end if;
  end if;
 when 'adjust_stock' then
  v_id:=(d->>'id')::uuid; delta:=(d->>'delta')::int;
  perform 1 from public.beauty_products where beauty_products.id=v_id and owner_id=o and active for update;
  if not found or delta is null or delta=0 or abs(delta::bigint)>1000000 or nullif(trim(d->>'reason'),'') is null or length(d->>'reason')>500 then raise check_violation using message='MAZA: Indica producto, cantidad y motivo válidos.'; end if;
  select coalesce(sum(quantity_delta),0) into stock from public.stock_movements where owner_id=o and product_id=v_id;
  if stock+delta<0 then raise check_violation using message='MAZA: No puedes retirar más unidades de las disponibles.'; end if;
  insert into public.stock_movements(owner_id,product_id,quantity_delta,kind,notes) values(o,v_id,delta,'adjustment',trim(d->>'reason'));
 when 'sale' then
  v_id:=(d->>'id')::uuid; client:=(d->>'client')::uuid; qty:=(d->>'quantity')::int;
  select * into p from public.beauty_products where beauty_products.id=v_id and owner_id=o and active for update;
  if not found or qty is null or qty<1 or qty>1000000 or not exists(select 1 from public.clients where clients.id=client and owner_id=o) then raise check_violation using message='MAZA: Selecciona producto, cliente y cantidad.'; end if;
  select coalesce(sum(quantity_delta),0) into stock from public.stock_movements where owner_id=o and product_id=v_id;
  if stock<qty then raise check_violation using message='MAZA: No hay stock suficiente para esta venta.'; end if;
  amount:=p.sale_price_cents::bigint*qty;
  if req.id is not null and req.amount_cents<>amount then raise check_violation using message='MAZA: Cambió el precio. Rechaza esta solicitud y coordina una nueva con el cliente.'; end if;
  if amount>2147483647 then raise check_violation using message='MAZA: El importe excede el límite por operación.'; end if;
  insert into public.stock_movements(owner_id,product_id,quantity_delta,kind,notes) values(o,v_id,-qty,'sale','Venta · '||qty||' × '||p.name) returning stock_movements.id into movement;
  if amount>0 then insert into public.receivables(owner_id,client_id,stock_sale_movement_id,amount_cents,description) values(o,client,movement,amount::int,qty||' × '||p.name); end if;
 when 'rental_create' then
  asset:=(d->>'asset')::uuid; client:=(d->>'client')::uuid; start_day:=(d->>'start')::date; end_day:=(d->>'end')::date;
  select * into a from public.rental_assets where rental_assets.id=asset and owner_id=o and active for update;
  if not found or start_day is null or end_day is null or end_day<=start_day or start_day<(now() at time zone 'America/Lima')::date or end_day-start_day>366 or not exists(select 1 from public.clients where clients.id=client and owner_id=o) then raise check_violation using message='MAZA: Selecciona equipo, cliente y fechas válidas (máximo un año).'; end if;
  -- Un equipo aún entregado no puede volver a entregarse a otra persona.
  if exists(select 1 from public.rental_bookings where owner_id=o and asset_id=asset and status='out' and ends_at<=now()) then raise check_violation using message='MAZA: Este equipo tiene una devolución pendiente.'; end if;
  amount:=a.daily_rate_cents::bigint*(end_day-start_day);
  if amount>2147483647 then raise check_violation using message='MAZA: El importe excede el límite por operación.'; end if;
  if req.id is not null and req.amount_cents<>amount then raise check_violation using message='MAZA: Cambió el precio. Rechaza esta solicitud y coordina una nueva con el cliente.'; end if;
  insert into public.rental_contracts(owner_id,client_id,status,deposit_cents) values(o,client,'confirmed',a.deposit_cents) returning rental_contracts.id into contract;
  insert into public.rental_bookings(owner_id,contract_id,asset_id,starts_at,ends_at,asset_name,rate_cents)
   values(o,contract,asset,start_day::timestamp at time zone 'America/Lima',end_day::timestamp at time zone 'America/Lima',a.name,a.daily_rate_cents);
  if amount>0 then insert into public.receivables(owner_id,client_id,rental_contract_id,amount_cents,description) values(o,client,contract,amount::int,'Alquiler · '||a.name||' · '||start_day||' → '||end_day); end if;
 when 'rental_status' then
  v_id:=(d->>'id')::uuid; state:=d->>'status';
  select * into b from public.rental_bookings where rental_bookings.id=v_id and owner_id=o for update;
  if not found or not ((b.status='reserved' and state in ('out','cancelled')) or (b.status='out' and state='returned')) then raise check_violation using message='MAZA: Ese cambio de estado ya no está disponible.'; end if;
  if state='cancelled' then
   if exists(select 1 from public.payments py join public.receivables rc on rc.id=py.receivable_id and rc.owner_id=py.owner_id where rc.owner_id=o and rc.rental_contract_id=b.contract_id) then raise check_violation using message='MAZA: El alquiler tiene abonos. Coordina su devolución antes de cancelar; no se pueden borrar cobros.'; end if;
   delete from public.receivables where owner_id=o and rental_contract_id=b.contract_id;
  elsif state='out' then
   if exists(select 1 from public.rental_bookings where owner_id=o and asset_id=b.asset_id and status='out' and rental_bookings.id<>v_id) then raise check_violation using message='MAZA: Registra primero la devolución del equipo.'; end if;
  end if;
  update public.rental_bookings set status=state,returned_at=case when state='returned' then now() else null end where rental_bookings.id=v_id and owner_id=o;
  update public.rental_contracts set status=case state when 'out' then 'active' when 'returned' then 'returned' else 'cancelled' end where rental_contracts.id=b.contract_id and owner_id=o;
 when 'payment' then
  v_id:=(d->>'id')::uuid; amount:=(d->>'amount')::bigint;
  select * into r from public.receivables where receivables.id=v_id and owner_id=o for update;
  if not found or amount is null or amount<=0 or coalesce(d->>'method','') not in ('cash','yape','plin','transfer') then raise check_violation using message='MAZA: Selecciona una cuenta, un método y un importe válidos.'; end if;
  select coalesce(sum(amount_cents),0) into paid from public.payments where owner_id=o and receivable_id=v_id and status='settled';
  if amount>r.amount_cents-paid then raise check_violation using message='MAZA: El abono supera el saldo pendiente. Actualiza los datos.'; end if;
  insert into public.payments(owner_id,receivable_id,amount_cents,method,status,idempotency_key,paid_at) values(o,v_id,amount::int,d->>'method','settled',p_key,now());
 else raise check_violation using message='MAZA: Operación no disponible.';
 end case;
 if req.id is not null then update public.customer_requests set status='handled' where customer_requests.id=req.id and owner_id=o; end if;
 insert into maza_private.commands(owner_id,key,action,data) values(o,p_key,p_action,p_data);
 return public.admin_snapshot();
end $$;
revoke all on function public.admin_operate(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.admin_operate(uuid,text,jsonb) to authenticated;

-- Compatibilidad: ninguna llamada antigua puede marcar atendida sin registrar la operación.
create or replace function public.web_resolve_request(p_id uuid,p_status text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.app_admin where user_id=auth.uid()) then raise insufficient_privilege using message='MAZA: Acceso exclusivo del administrador.'; end if;
 if p_status='handled' then
  perform public.admin_operate(p_id,'fulfill_request',jsonb_build_object('id',p_id));
 elsif p_status='rejected' then
  update public.customer_requests set status='rejected' where id=p_id and owner_id=auth.uid() and status='pending';
  if not found then raise check_violation using message='MAZA: La solicitud ya fue atendida.'; end if;
 else raise check_violation using message='MAZA: Estado no válido.';
 end if;
end $$;
revoke all on function public.web_resolve_request(uuid,text) from public,anon,authenticated;
grant execute on function public.web_resolve_request(uuid,text) to authenticated;

-- La cuenta se crea una sola vez al completar una cita. El precio histórico no cambia.
create function maza_private.invoice_appointment() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and old.status='completed' and new.status<>'completed' then
  raise check_violation using message='MAZA: Una cita completada conserva su estado y su cuenta.';
 end if;
 if new.status='completed' and new.price_cents>0 then
  insert into public.receivables(owner_id,client_id,appointment_id,amount_cents,description)
  values(new.owner_id,new.client_id,new.id,new.price_cents,new.service_name)
  on conflict(appointment_id) where appointment_id is not null do nothing;
 end if;
 return new;
end $$;
revoke all on function maza_private.invoice_appointment() from public,anon,authenticated;
create trigger invoice_appointment after insert or update on public.appointments for each row execute function maza_private.invoice_appointment();
-- Compatibilidad con citas reales que ya estuvieran completadas.
insert into public.receivables(owner_id,client_id,appointment_id,amount_cents,description)
 select owner_id,client_id,id,price_cents,service_name from public.appointments where status='completed' and price_cents>0
 on conflict(appointment_id) where appointment_id is not null do nothing;
commit;
