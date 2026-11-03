-- Opcional, solo negocio de demostración. Ejecutar tras 002_customer_web.sql y bootstrap.
begin;
do $$ declare owner uuid;begin
 select user_id into strict owner from public.app_admin;
 insert into public.business_settings(owner_id,name,address,policy) values(owner,'MAZA','Puno, Perú · local de demostración','Puedes cancelar o reprogramar antes del inicio de tu cita. Las solicitudes de productos y alquileres requieren confirmación.') on conflict do nothing;
 insert into public.beauty_products(id,owner_id,sku,name,sale_price_cents,description,category) values
 ('50000000-0000-4000-8000-000000000001',owner,'POM-100','Pomada mate',3500,'Fijación media y acabado natural. Envase de 100 g.','Peinado'),
 ('50000000-0000-4000-8000-000000000002',owner,'BAR-030','Aceite para barba',2800,'Aceite ligero de 30 ml para suavizar y acondicionar.','Barba'),
 ('50000000-0000-4000-8000-000000000003',owner,'SHA-250','Champú de uso diario',3200,'Limpieza para tu rutina. Presentación de 250 ml.','Cuidado'),
 ('50000000-0000-4000-8000-000000000004',owner,'PEI-001','Peine de bolsillo',1200,'Peine compacto de dientes finos.','Accesorios') on conflict(id) do nothing;
 insert into public.stock_movements(owner_id,product_id,quantity_delta,kind,notes)
 select owner,p.id,case p.sku when 'POM-100' then 12 when 'BAR-030' then 3 when 'SHA-250' then 8 else 2 end,'opening','Apertura demo web'
 from public.beauty_products p where p.owner_id=owner and not exists(select 1 from public.stock_movements m where m.product_id=p.id);
 insert into public.rental_assets(id,owner_id,code,name,daily_rate_cents,deposit_cents,description,category) values
 ('60000000-0000-4000-8000-000000000001',owner,'SIL-001','Sillón de barbería',6500,15000,'Sillón hidráulico individual. Recogida coordinada en Puno.','Equipamiento'),
 ('60000000-0000-4000-8000-000000000002',owner,'LUZ-001','Aro de luz profesional',2500,8000,'Aro de 18 pulgadas con trípode.','Iluminación'),
 ('60000000-0000-4000-8000-000000000003',owner,'EST-001','Estación de trabajo',4500,10000,'Estación portátil con espejo y bandeja.','Equipamiento') on conflict(id) do nothing;
end $$;
commit;
