-- Todo se revierte: jamás crea operaciones de ejemplo en producción.
begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.app_admin),true);
set local role authenticated;
do $$
declare p uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); k uuid:=gen_random_uuid(); c uuid; b jsonb; n int; r uuid; charge uuid; request jsonb; rid uuid;
begin
 select id into c from public.clients order by id limit 1;
 perform public.admin_operate(k,'save_item',jsonb_build_object('id',p,'rental',false,'name','Producto prueba','category','Cuidado','description','Prueba','price',3500,'units',3,'deposit',0));
 -- Repetir el mismo envío no duplica el ingreso inicial.
 perform public.admin_operate(k,'save_item',jsonb_build_object('id',p,'rental',false,'name','Producto prueba','category','Cuidado','description','Prueba','price',3500,'units',3,'deposit',0));
 select sum(quantity_delta)::int into n from public.stock_movements where product_id=p;
 if n<>3 then raise exception 'Stock inicial duplicado'; end if;
 begin
  perform public.admin_operate(gen_random_uuid(),'adjust_stock',jsonb_build_object('id',p,'delta',-4,'reason','Retiro'));
  raise exception 'Permitió stock negativo';
 exception when check_violation then null; end;
 perform public.admin_operate(gen_random_uuid(),'sale',jsonb_build_object('id',p,'client',c,'quantity',2,'price',1));
 select id into charge from public.receivables where stock_sale_movement_id in(select id from public.stock_movements where product_id=p);
 if (select amount_cents from public.receivables where id=charge)<>7000 then raise exception 'Precio del cliente aceptado'; end if;
 k:=gen_random_uuid();
 perform public.admin_operate(k,'payment',jsonb_build_object('id',charge,'amount',3000,'method','yape'));
 perform public.admin_operate(k,'payment',jsonb_build_object('id',charge,'amount',3000,'method','yape'));
 if (select sum(amount_cents) from public.payments where receivable_id=charge)<>3000 then raise exception 'Abono duplicado'; end if;
 begin
  perform public.admin_operate(gen_random_uuid(),'payment',jsonb_build_object('id',charge,'amount',4001,'method','cash'));
  raise exception 'Permitió abono superior al saldo';
 exception when check_violation then null; end;
 perform public.admin_operate(gen_random_uuid(),'payment',jsonb_build_object('id',charge,'amount',4000,'method','cash'));
 perform public.admin_operate(gen_random_uuid(),'save_item',jsonb_build_object('id',a,'rental',true,'name','Equipo prueba','category','Equipo','description','Prueba','price',5000,'units',1,'deposit',10000));
 b:=jsonb_build_object('asset',a,'client',c,'start',current_date+10,'end',current_date+12);
 k:=gen_random_uuid(); perform public.admin_operate(k,'rental_create',b); perform public.admin_operate(k,'rental_create',b);
 select id into r from public.rental_bookings where asset_id=a;
 if (select count(*) from public.rental_bookings where asset_id=a)<>1 then raise exception 'Reserva duplicada'; end if;
 begin
  perform public.admin_operate(gen_random_uuid(),'rental_create',b);
  raise exception 'Permitió solapamiento';
 exception when exclusion_violation then null; end;
 perform public.admin_operate(gen_random_uuid(),'rental_status',jsonb_build_object('id',r,'status','out'));
 perform public.admin_operate(gen_random_uuid(),'rental_status',jsonb_build_object('id',r,'status','returned'));
 if not exists(select 1 from public.rental_bookings where id=r and status='returned' and returned_at is not null) then raise exception 'Devolución no persistida'; end if;
 if (select amount_cents from public.receivables where rental_contract_id=(select contract_id from public.rental_bookings where id=r))<>10000 then raise exception 'Importe alquiler/garantía incorrecto'; end if;
 if jsonb_array_length(public.admin_snapshot()->'products')=0 then raise exception 'Snapshot vacío'; end if;
 -- Solicitud pública: al confirmar se descuenta y factura atómicamente, una sola vez.
 perform public.web_save_profile('Cliente prueba operación','999876543');
 request:=public.web_request_item(p,'product',1);
 rid:=(request->>'id')::uuid;
 perform public.web_resolve_request(rid,'handled');
 perform public.web_resolve_request(rid,'handled');
 if (select sum(quantity_delta) from public.stock_movements where product_id=p)<>0 then raise exception 'Solicitud descontó dos veces'; end if;
 if not exists(select 1 from public.customer_requests where id=rid and status='handled') then raise exception 'Solicitud no confirmada'; end if;
 begin
  perform public.admin_operate(k,'payment','{}'); raise exception 'Reutilización incompatible de clave';
 exception when check_violation then null; end;
 -- No se permite cancelar una reserva con dinero registrado.
 perform public.admin_operate(gen_random_uuid(),'rental_create',jsonb_build_object('asset',a,'client',c,'start',current_date+20,'end',current_date+21));
 select id into r from public.rental_bookings where asset_id=a and status='reserved';
 select id into charge from public.receivables where rental_contract_id=(select contract_id from public.rental_bookings where id=r);
 perform public.admin_operate(gen_random_uuid(),'payment',jsonb_build_object('id',charge,'amount',1000,'method','cash'));
 begin
  perform public.admin_operate(gen_random_uuid(),'rental_status',jsonb_build_object('id',r,'status','cancelled'));
  raise exception 'Se borró alquiler abonado';
 exception when check_violation then null; end;
 if jsonb_array_length(public.admin_snapshot()->'payment_history')<>3 then raise exception 'Historial incompleto'; end if;
end $$;
-- Usuario autenticado ajeno: no puede invocar operaciones privilegiadas.
select set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',true);
do $$ begin
 begin
  perform public.admin_snapshot(); raise exception 'Fuga de snapshot';
 exception when insufficient_privilege then null; end;
 begin
  perform public.admin_operate(gen_random_uuid(),'save_item','{}'); raise exception 'Escritura ajena';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin
  perform public.admin_snapshot(); raise exception 'Acceso anónimo';
 exception when insufficient_privilege then null; end;
end $$;
rollback;
