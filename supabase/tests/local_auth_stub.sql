-- Minimal stand-in for Supabase's auth schema and roles, so the migrations can be
-- smoke-tested on a plain PostgreSQL 15+ without Docker. NOT a migration.
-- Real RLS tests (pgTAP via `supabase test db`) replace this in Phase 7.
do $$ begin
  if not exists (select from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end $$;
create schema auth;
create table auth.users (id uuid primary key, raw_user_meta_data jsonb default '{}');
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
grant usage on schema auth to authenticated, anon;
grant usage on schema public to authenticated, anon;
alter default privileges in schema public grant all on tables to anon, authenticated;
