-- Ejecutar después de migración + bootstrap + seed_demo en proyecto de prueba.
-- Usa datos del seed, hace rollback; errores inesperados abortan la prueba.
begin;
do $$
declare a uuid; b uuid; c uuid; s uuid; first_id uuid; original_price int; owner uuid; previous_version int; affected int;
begin
 select user_id into strict owner from public.app_admin;
 select id into strict b from public.barbers where name='Diego Mamani';
 select id into strict c from public.clients where name='Luis Quispe';
 select id into strict s from public.services where name='Corte clásico';
 insert into public.appointments(owner_id,client_id,barber_id,service_id,starts_at)
 values(owner,c,b,s,'2030-01-07 15:00:00+00') returning id,price_cents into first_id, original_price;
 begin
   insert into public.appointments(owner_id,client_id,barber_id,service_id,starts_at)
   values(owner,c,b,s,'2030-01-07 15:15:00+00');
   raise exception 'TEST FAILED: se permitió solapamiento';
 exception when exclusion_violation then null; end;
 insert into public.appointments(owner_id,client_id,barber_id,service_id,starts_at)
 values(owner,c,b,s,'2030-01-07 15:30:00+00');
 select version into previous_version from public.appointments where id=first_id;
 update public.appointments set status='confirmed' where id=first_id and version=previous_version;
 if (select version from public.appointments where id=first_id)<>previous_version+1 then raise exception 'TEST FAILED: versión no incrementada'; end if;
 update public.appointments set notes='stale' where id=first_id and version=previous_version;
 get diagnostics affected=row_count;
 if affected<>0 then raise exception 'TEST FAILED: sesión obsoleta actualizó la cita'; end if;
 update public.services set price_cents=9900,duration_minutes=90 where id=s;
 if (select price_cents from public.appointments where id=first_id)<>original_price then
   raise exception 'TEST FAILED: precio histórico alterado'; end if;
 begin
   update public.appointments set price_cents=1 where id=first_id;
   raise exception 'TEST FAILED: instantánea editable';
 exception when check_violation then null; end;
 begin
   insert into public.appointments(owner_id,client_id,barber_id,service_id,starts_at)
   values(owner,c,b,s,'2030-01-08 00:50:00+00');
   raise exception 'TEST FAILED: reserva fuera de horario';
 exception when check_violation then null; end;
 raise notice 'MAZA: invariantes correctas';
end $$;
rollback;
