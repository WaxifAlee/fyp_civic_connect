-- Run as postgres against a disposable/migrated Supabase database:
-- psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f supabase/tests/backend_security.sql
-- No image bytes are uploaded: storage.objects entries are rollback-only fixtures.
BEGIN;
-- This suite creates metadata-only fixtures and rolls every change back.
-- Permit test DELETE statements on recent hosted Storage schemas; production
-- clients still use the Storage API and retain all application RLS/triggers.
SET LOCAL storage.allow_delete_query = 'true';
CREATE FUNCTION pg_temp.check_true(ok boolean, label text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %', label; END IF;
END $$;
CREATE FUNCTION pg_temp.denied(statement text, states text[] DEFAULT ARRAY['42501']) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  BEGIN EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = ANY(states) THEN RETURN; END IF;
    RAISE EXCEPTION 'Unexpected SQLSTATE % for %: %', SQLSTATE, statement, SQLERRM;
  END;
  RAISE EXCEPTION 'FAIL: accepted forbidden statement: %', statement;
END $$;

-- Catch missing schema before any fixture writes (the initial RED check).
SELECT pg_temp.check_true(to_regprocedure('public.create_report(text,text,text,double precision,double precision,text[],uuid)') IS NOT NULL, 'required idempotent RPC exists');

-- Metadata is synthetic; duplicate or malformed identities must roll back signup.
INSERT INTO auth.users(id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
SELECT id::uuid, '00000000-0000-0000-0000-000000000000'::uuid, 'authenticated', 'authenticated', email,
       CASE WHEN verified THEN now() ELSE NULL END, '{"provider":"email","providers":["email"]}'::jsonb,
       jsonb_build_object('full_name',name,'phone',phone,'cnic',cnic,'locations','Fateh Jang','gender',gender), now(), now()
FROM (VALUES
 ('a1000000-0000-4000-8000-000000000001','sql-owner@example.invalid','Test Owner','+923001110001','12345-1110001-1','Male',true),
 ('a1000000-0000-4000-8000-000000000002','sql-peer@example.invalid','Test Peer','+923001110002','12345-1110002-1','Female',true),
 ('a1000000-0000-4000-8000-000000000003','sql-pending@example.invalid','Test Pending','+923001110003','12345-1110003-1','Other',false),
 ('a1000000-0000-4000-8000-000000000005','sql-voter@example.invalid','Test Voter','+923001110005','12345-1110005-1','Other',true)
) AS f(id,email,name,phone,cnic,gender,verified);
SELECT pg_temp.denied($s$ INSERT INTO auth.users(id,raw_user_meta_data) VALUES ('a1000000-0000-4000-8000-000000000004','{}') $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ INSERT INTO auth.users(id,raw_user_meta_data) VALUES ('a1000000-0000-4000-8000-000000000004','{"full_name":"Valid Name","phone":"+923001110001","cnic":"12345-1110004-1","locations":"Fateh Jang","gender":"Other"}') $s$,ARRAY['23505']);
SELECT pg_temp.denied($s$ INSERT INTO auth.users(id,raw_user_meta_data) VALUES ('a1000000-0000-4000-8000-000000000004','{"full_name":"Valid Name","phone":"+923001110004","cnic":"12345-1110001-1","locations":"Fateh Jang","gender":"Other"}') $s$,ARRAY['23505']);
SELECT pg_temp.denied($s$ INSERT INTO auth.users(id,raw_user_meta_data) VALUES ('a1000000-0000-4000-8000-000000000004','{"full_name":"Valid Name","phone":"+923001110004","cnic":"12345-1110004-1","locations":"Fateh Jang","gender":"male"}') $s$,ARRAY['23514']);
-- Even privileged accidental changes must not rewrite established identity.
SELECT pg_temp.denied($s$ UPDATE public.profiles SET cnic='12345-9999999-1' WHERE id='a1000000-0000-4000-8000-000000000001' $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ UPDATE public.profiles SET gender='Other' WHERE id='a1000000-0000-4000-8000-000000000001' $s$,ARRAY['23514']);

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{"role":"anon"}',true);
SELECT pg_temp.denied('SELECT public.list_reports()');
SELECT pg_temp.denied('SELECT public.list_report_cleanup()');
SELECT pg_temp.denied('SELECT * FROM public.profiles');
SELECT pg_temp.denied($s$ INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES ('reports-images','anon/no.jpg','anon') $s$);
RESET ROLE;

-- Metadata claims cannot turn an unconfirmed user into a verified citizen.
UPDATE auth.users SET raw_user_meta_data=raw_user_meta_data || '{"email_verified":true,"role":"service_role"}' WHERE id='a1000000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000003","role":"authenticated","email_verified":true}',true);
SELECT pg_temp.check_true((SELECT count(*)=0 FROM public.profiles),'unverified profile hidden');
SELECT pg_temp.denied('SELECT public.list_reports()');
SELECT pg_temp.denied('SELECT public.list_report_cleanup()');
SELECT pg_temp.denied($s$ SELECT public.get_report_submission('b1000000-0000-4000-8000-000000000001') $s$);
SELECT pg_temp.denied($s$ SELECT public.update_profile('Test Pending','+923001110003','Fateh Jang',NULL) $s$);
SELECT pg_temp.denied($s$ INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES ('reports-images','a1000000-0000-4000-8000-000000000003/c1000000-0000-4000-8000-000000000001.jpg','a1000000-0000-4000-8000-000000000003') $s$);

SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
SELECT pg_temp.check_true((SELECT count(*)=1 FROM public.profiles),'verified owner sees only self');
SELECT pg_temp.denied('SELECT * FROM public.reports');
SELECT pg_temp.denied('SELECT * FROM public.report_supports');
SELECT pg_temp.denied('SELECT * FROM public.report_counters');
SELECT pg_temp.denied('SELECT * FROM public.report_cleanup');
SELECT pg_temp.denied($s$ UPDATE public.profiles SET cnic='12345-9999999-1' $s$);
SELECT pg_temp.denied($s$ UPDATE public.profiles SET full_name='Forged Name' $s$);
SELECT pg_temp.denied($s$ INSERT INTO public.report_counters VALUES ('MC',999) $s$);
SELECT pg_temp.denied($s$ SELECT civic_private.require_verified_user() $s$);
-- Own storage fixtures follow the same policy as API uploads.
INSERT INTO storage.objects(bucket_id,name,owner_id,metadata) VALUES
 ('reports-images','a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg','a1000000-0000-4000-8000-000000000001','{"mimetype":"image/jpeg","size":100}'),
 ('profile-pictures','a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000002.png','a1000000-0000-4000-8000-000000000001','{"mimetype":"image/png","size":100}');
SELECT pg_temp.denied($s$ INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES ('reports-images','a1000000-0000-4000-8000-000000000002/c1000000-0000-4000-8000-000000000003.jpg','a1000000-0000-4000-8000-000000000001') $s$);
SELECT pg_temp.denied($s$ INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES ('reports-images','a1000000-0000-4000-8000-000000000001/not-a-uuid.jpg','a1000000-0000-4000-8000-000000000001') $s$);
-- No UPDATE policy: even an owner cannot overwrite/rename an object.
WITH changed AS (UPDATE storage.objects SET metadata='{}' WHERE bucket_id='reports-images' RETURNING 1)
SELECT pg_temp.check_true((SELECT count(*)=0 FROM changed),'storage overwrite denied');

SELECT public.update_profile('پاکستانی شہری','+923001110001','Fateh Jang',NULL);
SELECT pg_temp.check_true((SELECT full_name='پاکستانی شہری' FROM public.profiles),'international citizen name accepted');
SELECT public.update_profile('Updated Owner','+923001110001','Fateh Jang','a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000002.png');
WITH removed AS (DELETE FROM storage.objects WHERE bucket_id='profile-pictures' RETURNING 1)
SELECT pg_temp.check_true((SELECT count(*)=0 FROM removed),'referenced avatar protected');
SELECT public.update_profile('Updated Owner','+923001110001','Fateh Jang',NULL);
SELECT pg_temp.check_true((SELECT profile_picture<>'' FROM public.profiles),'null avatar preserves');
SELECT pg_temp.denied($s$ SELECT public.update_profile('Updated Owner','+923001110002','Fateh Jang',NULL) $s$,ARRAY['23505']);
SELECT pg_temp.denied($s$ SELECT public.update_profile('Updated Owner','invalid','Fateh Jang',NULL) $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ SELECT public.update_profile('Updated Owner','+923001110001','Fateh Jang','https://evil.invalid/avatar.jpg') $s$,ARRAY['23514']);

-- Malformed payloads fail before allocating a counter or report.
DO $$
DECLARE path text := 'a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg';
        stmt text;
BEGIN
  FOREACH stmt IN ARRAY ARRAY[
    format('SELECT public.create_report(%L,%L,%L,33.55,72.63,ARRAY[%L],NULL)','Valid title','Long enough description for security tests','Municipal Corportaion',path),
    format('SELECT public.create_report(%L,%L,%L,''NaN''::float8,72.63,ARRAY[%L],gen_random_uuid())','Valid title','Long enough description for security tests','Municipal Corportaion',path),
    format('SELECT public.create_report(%L,%L,%L,33.55,''Infinity''::float8,ARRAY[%L],gen_random_uuid())','Valid title','Long enough description for security tests','Municipal Corportaion',path),
    format('SELECT public.create_report(%L,%L,%L,NULL,72.63,ARRAY[%L],gen_random_uuid())','Valid title','Long enough description for security tests','Municipal Corportaion',path),
    format('SELECT public.create_report(%L,%L,%L,34,72.63,ARRAY[%L],gen_random_uuid())','Valid title','Long enough description for security tests','Municipal Corportaion',path),
    format('SELECT public.create_report(%L,%L,%L,33.55,72.63,ARRAY[%L],gen_random_uuid())','tiny','Long enough description for security tests','Municipal Corportaion',path),
    format('SELECT public.create_report(%L,%L,%L,33.55,72.63,ARRAY[%L],gen_random_uuid())','Valid title','short','Municipal Corportaion',path),
    format('SELECT public.create_report(%L,%L,%L,33.55,72.63,ARRAY[%L],gen_random_uuid())','Valid title','Long enough description for security tests','Municipal Corporation',path),
    format('SELECT public.create_report(%L,%L,%L,33.55,72.63,ARRAY[]::text[],gen_random_uuid())','Valid title','Long enough description for security tests','Municipal Corportaion'),
    format('SELECT public.create_report(%L,%L,%L,33.55,72.63,ARRAY[%L,%L],gen_random_uuid())','Valid title','Long enough description for security tests','Municipal Corportaion',path,path),
    format('SELECT public.create_report(%L,%L,%L,33.55,72.63,ARRAY[NULL]::text[],gen_random_uuid())','Valid title','Long enough description for security tests','Municipal Corportaion'),
    format('SELECT public.create_report(%L,%L,%L,33.55,72.63,ARRAY[%L],gen_random_uuid())','Valid title','Long enough description for security tests','Municipal Corportaion','a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000099.jpg')
  ] LOOP PERFORM pg_temp.denied(stmt,ARRAY['23514']); END LOOP;
END $$;

SELECT pg_temp.check_true(public.create_report('  Road needs repair  ','  A damaged road needs urgent repair today.  ','Municipal Corportaion',33.55,72.63,ARRAY['a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg'],'b1000000-0000-4000-8000-000000000001')->>'id'='b1000000-0000-4000-8000-000000000001','create uses request id');
SELECT pg_temp.check_true(public.create_report('Road needs repair','A damaged road needs urgent repair today.','Municipal Corportaion',33.55,72.63,ARRAY['a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg'],'b1000000-0000-4000-8000-000000000001')=public.get_report_submission('b1000000-0000-4000-8000-000000000001')-'images','canonical retry returns original');
SELECT pg_temp.check_true(jsonb_array_length(public.list_reports(true))=1,'retry does not duplicate report');
SELECT pg_temp.denied($s$ SELECT public.create_report('Changed title','A damaged road needs urgent repair today.','Municipal Corportaion',33.55,72.63,ARRAY['a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg'],'b1000000-0000-4000-8000-000000000001') $s$,ARRAY['23514']);
WITH removed AS (DELETE FROM storage.objects WHERE bucket_id='reports-images' RETURNING 1)
SELECT pg_temp.check_true((SELECT count(*)=0 FROM removed),'referenced report photo protected');
SELECT pg_temp.check_true(public.toggle_report_support('b1000000-0000-4000-8000-000000000001')->>'count'='1','support once increments');
SELECT pg_temp.check_true(public.toggle_report_support('b1000000-0000-4000-8000-000000000001')='{"count":0,"voters":[]}'::jsonb,'support twice removes support');
SELECT pg_temp.check_true(public.list_reports(false,1,0)->0->>'reporterName'='Updated Owner','feed public name');
SELECT public.update_avatar('a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000002.png');
SELECT pg_temp.check_true((SELECT full_name='Updated Owner' AND phone='+923001110001' FROM public.profiles),'avatar update preserves committed name and contact');
SELECT pg_temp.check_true(NOT (public.list_reports()->0 ?| ARRAY['cnic','phone','email','gender','locations']),'feed hides identity');
SELECT pg_temp.denied('SELECT public.list_reports(false,201,0)',ARRAY['23514']);
SELECT pg_temp.denied('SELECT public.list_reports(false,1,-1)',ARRAY['23514']);
SELECT pg_temp.denied($s$ DELETE FROM public.reports WHERE id='b1000000-0000-4000-8000-000000000001' $s$);

SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
SELECT pg_temp.check_true(public.get_report_submission('b1000000-0000-4000-8000-000000000001') IS NULL,'submission lookup hides another owner');
SELECT pg_temp.check_true(jsonb_array_length(public.list_reports(true))=0,'mine scoped to owner');
SELECT pg_temp.denied($s$ SELECT public.delete_report('b1000000-0000-4000-8000-000000000001') $s$);
SELECT pg_temp.denied($s$ SELECT public.create_report('Road needs repair','A damaged road needs urgent repair today.','Municipal Corportaion',33.55,72.63,ARRAY['a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg'],'b1000000-0000-4000-8000-000000000001') $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ SELECT public.update_profile('Test Peer','+923001110002','Fateh Jang','a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000002.png') $s$,ARRAY['23514']);
WITH removed AS (DELETE FROM storage.objects WHERE bucket_id IN ('reports-images','profile-pictures') RETURNING 1)
SELECT pg_temp.check_true((SELECT count(*)=0 FROM removed),'cross owner cannot delete photos');
SELECT pg_temp.check_true(public.toggle_report_support('b1000000-0000-4000-8000-000000000001')->'voters'='["a1000000-0000-4000-8000-000000000002"]'::jsonb,'voters exposes caller only');
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
SELECT pg_temp.check_true(public.list_reports()->0->'upvotedBy'='[]'::jsonb,'feed hides other voters');
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000005","role":"authenticated"}',true);
SELECT pg_temp.check_true(public.toggle_report_support('b1000000-0000-4000-8000-000000000001')->>'count'='2','second voter counted');
RESET ROLE;
DELETE FROM auth.users WHERE id='a1000000-0000-4000-8000-000000000005';
SELECT pg_temp.check_true((SELECT support_count=1 FROM public.reports WHERE id='b1000000-0000-4000-8000-000000000001'),'account deletion decrements support');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
SELECT pg_temp.check_true(public.delete_report('b1000000-0000-4000-8000-000000000001')='["a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg"]'::jsonb,'owner delete returns cleanup paths');
SELECT pg_temp.check_true(public.delete_report('b1000000-0000-4000-8000-000000000001')='["a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg"]'::jsonb,'repeat delete returns durable manifest');
SELECT pg_temp.denied($s$ SELECT public.create_report('Road needs repair','A damaged road needs urgent repair today.','Municipal Corportaion',33.55,72.63,ARRAY['a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg'],'b1000000-0000-4000-8000-000000000001') $s$,ARRAY['P0002']);
SELECT pg_temp.check_true(public.get_report_submission('b1000000-0000-4000-8000-000000000001')->>'deleted'='true','deleted submission has terminal owner outcome');
SELECT pg_temp.check_true(public.list_report_cleanup()='[{"reportId":"b1000000-0000-4000-8000-000000000001","paths":["a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg"]}]'::jsonb,'cleanup manifest owner listing');
SELECT pg_temp.check_true(NOT public.complete_report_cleanup('b1000000-0000-4000-8000-000000000001'),'completion blocked while object exists');
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
SELECT pg_temp.check_true(public.list_report_cleanup()='[]'::jsonb,'cleanup listing excludes other owners');
SELECT pg_temp.check_true(NOT public.complete_report_cleanup('b1000000-0000-4000-8000-000000000001'),'other owner cannot complete manifest');
SELECT pg_temp.denied($s$ SELECT public.delete_report('b1000000-0000-4000-8000-000000000001') $s$);
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
SELECT public.update_profile('Updated Owner','+923001110001','Fateh Jang','');
WITH removed AS (DELETE FROM storage.objects WHERE bucket_id IN ('reports-images','profile-pictures') RETURNING 1)
SELECT pg_temp.check_true((SELECT count(*)=2 FROM removed),'unreferenced owner photos deletable');
SELECT pg_temp.check_true(public.complete_report_cleanup('b1000000-0000-4000-8000-000000000001'),'completion removes manifest after objects absent');
SELECT pg_temp.check_true(public.list_report_cleanup()='[]'::jsonb,'completed manifest absent');
SELECT pg_temp.denied($s$ SELECT public.create_report('Road needs repair','A damaged road needs urgent repair today.','Municipal Corportaion',33.55,72.63,ARRAY['a1000000-0000-4000-8000-000000000001/c1000000-0000-4000-8000-000000000001.jpg'],'b1000000-0000-4000-8000-000000000001') $s$,ARRAY['P0002']);
SELECT pg_temp.check_true(public.get_report_submission('b1000000-0000-4000-8000-000000000001')->>'deleted'='true','deleted submission has terminal outcome survives cleanup');
SELECT pg_temp.check_true(NOT public.complete_report_cleanup('b1000000-0000-4000-8000-000000000001'),'repeat complete harmless');
RESET ROLE;

-- Independently specified vertices, all edge midpoints, inside and outside.
SELECT pg_temp.check_true(civic_private.in_service_area(lat,lon)=expected,'polygon point '||lat||','||lon)
FROM (VALUES (33.6013,72.5843,true),(33.5765,72.6912,true),(33.4857,72.6903,true),(33.4701,72.5750,true),
 (33.5889,72.63775,true),(33.5311,72.69075,true),(33.4779,72.63265,true),(33.5357,72.57965,true),
 (33.55,72.63,true),(33.61,72.63,false),(33.55,72.70,false),(33.46,72.63,false),(33.55,72.57,false)) AS p(lat,lon,expected);
SELECT pg_temp.check_true(NOT civic_private.in_service_area('NaN',72.63) AND NOT civic_private.in_service_area(33.55,'Infinity') AND NOT civic_private.in_service_area(NULL,72.63),'nonfinite/null coordinates denied');
SELECT pg_temp.check_true((SELECT count(*)=0 FROM public.report_supports WHERE report_id='b1000000-0000-4000-8000-000000000001'),'delete cascades support');
-- Security definer helpers must have a sealed path and no blanket PUBLIC execution.
SELECT pg_temp.check_true(NOT EXISTS (
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
 LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
 WHERE n.nspname IN ('public','civic_private') AND p.prosecdef
 AND (NOT ('search_path=""'=ANY(coalesce(p.proconfig,ARRAY[]::text[]))) OR (a.grantee=0 AND a.privilege_type='EXECUTE'))
),'security definer permissions and search paths sealed');
ROLLBACK;
