-- OFFLINE HARNESS ONLY: minimal Supabase-owned schema on an empty PostgreSQL.
-- Never run this file against any Supabase project. It is not a migration.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users (
 id uuid PRIMARY KEY, instance_id uuid, aud text, role text, email text,
 email_confirmed_at timestamptz, raw_app_meta_data jsonb, raw_user_meta_data jsonb,
 created_at timestamptz, updated_at timestamptz
);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
 nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid
$$;
GRANT USAGE ON SCHEMA auth TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon,authenticated,service_role;
CREATE SCHEMA storage;
CREATE TABLE storage.buckets (
 id text PRIMARY KEY, name text NOT NULL UNIQUE, public boolean NOT NULL DEFAULT false,
 file_size_limit bigint, allowed_mime_types text[]
);
CREATE TABLE storage.objects (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text REFERENCES storage.buckets(id),
 name text, owner uuid, owner_id text, metadata jsonb, UNIQUE(bucket_id,name)
);
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA storage TO anon,authenticated,service_role;
GRANT ALL ON storage.objects TO anon,authenticated,service_role;
GRANT SELECT ON storage.buckets TO anon,authenticated,service_role;
-- Match broad public defaults so migrations must explicitly seal every object.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon,authenticated,service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon,authenticated,service_role;
