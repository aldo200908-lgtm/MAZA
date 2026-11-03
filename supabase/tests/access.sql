-- Después de migration + bootstrap + seed. Rollback, no crea cuentas.
begin;
set local role authenticated;
-- JWT de usuario ajeno al administrador.
select set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',true);
do $$ begin
 if (select count(*) from public.clients)<>0 then raise exception 'RLS: fuga de clientes'; end if;
 if (select count(*) from public.app_admin)<>0 then raise exception 'RLS: fuga de administrador'; end if;
 begin
   insert into public.clients(owner_id,name,phone) values('99999999-9999-4999-8999-999999999999','Ajeno','999222333');
   raise exception 'RLS: escritura no autorizada';
 exception when insufficient_privilege then null; end;
 raise notice 'MAZA: usuario ajeno sin acceso';
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select user_id::text from public.app_admin),true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.clients)=0 then raise exception 'RLS: administrador sin lectura'; end if;
 insert into public.appointments(owner_id,client_id,barber_id,service_id,starts_at)
 values(auth.uid(),'30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','2030-01-07 18:00:00+00');
 if not exists(select 1 from public.appointments where starts_at='2030-01-07 18:00:00+00' and price_cents=2500) then raise exception 'RLS: cita no persistida con trigger'; end if;
 begin
   insert into public.app_admin(singleton,user_id) values(true,auth.uid());
   raise exception 'RLS: administrador puede cambiar autorización';
 exception when insufficient_privilege then null; end;
 begin
   insert into public.beauty_products(owner_id,sku,name) values(auth.uid(),'NO','No permitido');
   raise exception 'RLS: módulo futuro editable';
 exception when insufficient_privilege then null; end;
 raise notice 'MAZA: admin autorizado y módulos futuros protegidos';
end $$;
rollback;
