-- Opcional: solo para un proyecto de demostración. No ejecutar sobre clientes reales.
-- Todos los teléfonos son ficticios. Stock, alquileres y pagos permanecen vacíos.
begin;
do $$
declare owner uuid; today date;
begin
 select user_id into strict owner from public.app_admin;
 today:=(now() at time zone 'America/Lima')::date;
 if extract(isodow from today)=7 then today:=today+1; end if;
 insert into public.services(id,owner_id,name,price_cents,duration_minutes) values
 ('10000000-0000-4000-8000-000000000001',owner,'Corte clásico',2500,30),
 ('10000000-0000-4000-8000-000000000002',owner,'Degradado + diseño',3500,45),
 ('10000000-0000-4000-8000-000000000003',owner,'Corte + barba',4500,60),
 ('10000000-0000-4000-8000-000000000004',owner,'Perfilado de barba',2000,20) on conflict(id) do nothing;
 insert into public.barbers(id,owner_id,name,open_minute,close_minute) values
 ('20000000-0000-4000-8000-000000000001',owner,'Diego Mamani',540,1200),
 ('20000000-0000-4000-8000-000000000002',owner,'Joaquín Flores',600,1140) on conflict(id) do nothing;
 insert into public.clients(id,owner_id,name,phone,notes) values
 ('30000000-0000-4000-8000-000000000001',owner,'Luis Quispe','999111201','Prefiere degradado bajo. Cliente de Puno.'),
 ('30000000-0000-4000-8000-000000000002',owner,'Marco Condori','999111202','Corte a tijera en la parte superior.'),
 ('30000000-0000-4000-8000-000000000003',owner,'André Huanca','999111203','Avisar cambios de horario.'),
 ('30000000-0000-4000-8000-000000000004',owner,'Renato Apaza','999111204','') on conflict(id) do nothing;
 insert into public.appointments(id,owner_id,client_id,barber_id,service_id,starts_at,status) values
 ('40000000-0000-4000-8000-000000000001',owner,'30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',(today+time '09:30') at time zone 'America/Lima','completed'),
 ('40000000-0000-4000-8000-000000000002',owner,'30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000003',(today+time '11:00') at time zone 'America/Lima','confirmed'),
 ('40000000-0000-4000-8000-000000000003',owner,'30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002',(today+time '15:00') at time zone 'America/Lima','pending'),
 ('40000000-0000-4000-8000-000000000004',owner,'30000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001',(today+time '17:30') at time zone 'America/Lima','confirmed'),
 ('40000000-0000-4000-8000-000000000005',owner,'30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003',(today-7+time '10:00') at time zone 'America/Lima','completed') on conflict(id) do nothing;
end $$;
commit;
