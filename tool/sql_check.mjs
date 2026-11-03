import {PGlite} from '@electric-sql/pglite';
import {btree_gist} from '@electric-sql/pglite/contrib/btree_gist';
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
const db=new PGlite({extensions:{btree_gist}});
await db.exec(`create schema auth; create schema extensions; create role anon; create role authenticated;
create table auth.users(id uuid primary key);
insert into auth.users values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema public,auth to authenticated,anon; grant execute on function auth.uid() to authenticated,anon;`);
const root=fileURLToPath(new URL('../',import.meta.url));
try {
 await db.exec(fs.readFileSync(root+'supabase/migrations/001_maza.sql','utf8')); console.log('Migración SQL OK');
 await db.exec(`insert into public.app_admin(user_id) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');`);
 await db.exec(fs.readFileSync(root+'supabase/seed_demo.sql','utf8')); console.log('Seed OK');
 await db.exec(fs.readFileSync(root+'supabase/tests/invariants.sql','utf8')); console.log('Horarios, conflictos e historial OK');
 await db.exec(fs.readFileSync(root+'supabase/tests/access.sql','utf8')); console.log('RLS admin/ajeno y permisos módulos futuros OK');
} catch(e){console.error(e.message); console.error('code',e.code);process.exitCode=1;}finally{await db.close();}
