begin;
insert into auth.users(id) values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),('cccccccc-cccc-4ccc-8ccc-cccccccccccc');
set local role anon;
do $$ declare c jsonb;begin
 c:=public.web_catalog();
 if c ? 'clients' or c ? 'appointments' or c::text like '%Luis Quispe%' or c::text like '%999111201%' then raise exception 'TEST FAILED: catálogo filtra datos privados'; end if;
 if jsonb_array_length(c->'services')=0 or jsonb_array_length(c->'products')<>4 then raise exception 'TEST FAILED: catálogo incompleto'; end if;
 begin perform public.web_profile();raise exception 'TEST FAILED: anon invoca perfil';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
set local role authenticated;
do $$ declare p jsonb;a jsonb;t timestamptz;b uuid;s uuid:='10000000-0000-4000-8000-000000000001';d date;req jsonb;begin
 if (select count(*) from public.clients)<>0 then raise exception 'TEST FAILED: cliente ve fichas internas';end if;
 begin perform public.web_save_profile('Cliente B','999111201');raise exception 'TEST FAILED: reclamó ficha por celular';exception when check_violation then null;end;
 perform public.web_save_profile('Cliente B','999444555');p:=public.web_profile();
 if p->>'name'<>'Cliente B' or p->>'notes'<>'' then raise exception 'TEST FAILED: perfil incorrecto';end if;
 for i in 1..14 loop
  d:=(now() at time zone 'America/Lima')::date+i;
  select barber_id,starts_at into b,t from public.web_slots(s,d) limit 1;
  exit when t is not null;
 end loop;
 if t is null then raise exception 'TEST FAILED: no hay turnos';end if;
 a:=public.web_book(s,b,t,'Consulta de prueba');
 if a->>'client_id'<>p->>'id' or (a->>'price_cents')::int<>2500 then raise exception 'TEST FAILED: identidad/precio de reserva';end if;
 if (select count(*) from public.web_my_appointments())<>1 then raise exception 'TEST FAILED: historial ajeno';end if;
 begin perform public.web_book(s,b,t,'');raise exception 'TEST FAILED: turno doble';exception when check_violation or exclusion_violation then null;end;
 begin perform public.web_change_booking('40000000-0000-4000-8000-000000000001',1,true);raise exception 'TEST FAILED: cambió cita ajena';exception when insufficient_privilege then null;end;
 perform public.web_change_booking((a->>'id')::uuid,(a->>'version')::int,true);
 begin perform public.web_change_booking((a->>'id')::uuid,(a->>'version')::int,false,t);raise exception 'TEST FAILED: reactivó cita cancelada';exception when check_violation then null;end;
 req:=public.web_request_item('50000000-0000-4000-8000-000000000001','product',2);
 if (req->>'amount_cents')::int<>7000 then raise exception 'TEST FAILED: importe de solicitud';end if;
 begin perform public.web_resolve_request((req->>'id')::uuid,'handled');raise exception 'TEST FAILED: cliente atiende solicitudes';exception when insufficient_privilege then null;end;
 if (select count(*) from public.customer_requests)<>0 then raise exception 'TEST FAILED: cliente lee tabla administrativa';end if;
 raise notice 'MAZA Web: perfil, reserva propia, conflictos y permisos correctos';
end $$;
reset role;
select set_config('request.jwt.claim.sub','cccccccc-cccc-4ccc-8ccc-cccccccccccc',true);
set local role authenticated;
do $$ begin
 perform public.web_save_profile('Cliente C','999444556');
 if (select count(*) from public.web_my_appointments())<>0 or (select count(*) from public.web_my_requests())<>0 then raise exception 'TEST FAILED: otro cliente ve historial ajeno';end if;
 raise notice 'MAZA Web: dos clientes aislados';
end $$;
rollback;
