-- Run as postgres on a disposable database after migrations 001..007:
-- psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f supabase/tests/authority_security.sql
-- For offline PostgreSQL, first apply local_platform_fixture.sql, then migrations.
-- All fixtures and assertions roll back; no cloud credentials are required.
BEGIN;
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
SELECT pg_temp.check_true(to_regprocedure('public.authority_update_report(uuid,integer,text,text,uuid)') IS NOT NULL,
  'authority mutation contract exists');

-- Capture existing scope counts so this rollback-only suite also works on a
-- populated project without deleting or modifying its existing reports.
SELECT set_config('civic_test.baseline_municipal',(SELECT jsonb_build_object(
 'total',count(*),'pending',count(*) FILTER(WHERE status='pending'),
 'inprogress',count(*) FILTER(WHERE status='inprogress'),
 'resolved',count(*) FILTER(WHERE status='resolved'),
 'rejected',count(*) FILTER(WHERE status='rejected'))::text
 FROM public.reports WHERE category='Municipal Corportaion'),true);
SELECT set_config('civic_test.baseline_admin',(SELECT jsonb_build_object(
 'total',count(*),'pending',count(*) FILTER(WHERE status='pending'),
 'inprogress',count(*) FILTER(WHERE status='inprogress'),
 'resolved',count(*) FILTER(WHERE status='resolved'),
 'rejected',count(*) FILTER(WHERE status='rejected'))::text FROM public.reports),true);
CREATE FUNCTION pg_temp.expected_counts(scope text, additions jsonb) RETURNS jsonb
LANGUAGE sql AS $$ SELECT jsonb_object_agg(key,value::int +
 (current_setting('civic_test.baseline_'||scope)::jsonb->>key)::int)
 FROM jsonb_each_text(additions) $$;

INSERT INTO auth.users(id,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
SELECT ('a6000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
       'authority-sql-'||n||'@example.invalid', CASE WHEN n<>6 THEN now() END,
       '{"provider":"email","providers":["email"]}'::jsonb,
       jsonb_build_object('full_name','Authority Test Citizen','phone','+92300666000'||n,
         'cnic','12345-666000'||n||'-1','locations','Fateh Jang','gender','Other',
         'role','admin','department','Police Department','active',true,'email_verified',true)
FROM generate_series(1,7) n;
-- 1 citizen, 2 municipal staff, 3 police staff, 4 admin, 5 inactive,
-- 6 unverified admin, 7 a second active municipal staff member.
INSERT INTO civic_private.authority_members(user_id,role,department,active) VALUES
 ('a6000000-0000-4000-8000-000000000002','department','Municipal Corportaion',true),
 ('a6000000-0000-4000-8000-000000000003','department','Police Department',true),
 ('a6000000-0000-4000-8000-000000000004','admin',NULL,true),
 ('a6000000-0000-4000-8000-000000000005','admin',NULL,false),
 ('a6000000-0000-4000-8000-000000000006','admin',NULL,true),
 ('a6000000-0000-4000-8000-000000000007','department','Municipal Corportaion',true);
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_members VALUES
 ('a6000000-0000-4000-8000-000000000001','admin','Police Department',true) $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_members VALUES
 ('a6000000-0000-4000-8000-000000000001','department',NULL,true) $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_members VALUES
 ('a6000000-0000-4000-8000-000000000001','department','Police',true) $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_members VALUES
 ('a6000000-0000-4000-8000-000000000001','superuser',NULL,true) $s$,ARRAY['23514']);

INSERT INTO public.reports(id,reporter_id,title,description,category,status,latitude,longitude,media_paths,report_code,created_at,support_count)
SELECT ('b6000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'a6000000-0000-4000-8000-000000000001',
 CASE n WHEN 1 THEN 'Road 100%_safe repair' ELSE 'Authority test issue '||n END,
 CASE n WHEN 4 THEN 'Searchable description with MixedCase marker.' ELSE 'A sufficiently long public issue description.' END,
 CASE WHEN n=3 THEN 'Police Department' ELSE 'Municipal Corportaion' END,
 CASE WHEN n=4 THEN 'resolved' ELSE 'pending' END,33.55,72.63,
 ARRAY['a6000000-0000-4000-8000-000000000001/c6000000-0000-4000-8000-000000000001.jpg'],
 'AUTHSQL'||n,'2026-01-01'::timestamptz + n*interval '1 day',CASE WHEN n=2 THEN 5 ELSE 0 END
FROM generate_series(1,4) n;

-- Explicit ACL checks also catch broad Supabase default grants and column grants.
SELECT pg_temp.check_true(NOT EXISTS (
 SELECT 1 FROM (VALUES ('anon'),('authenticated'),('service_role')) roles(name),
 (VALUES ('civic_private.authority_members'),('civic_private.authority_report_events')) tables(name)
 WHERE has_table_privilege(roles.name,tables.name,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
    OR has_any_column_privilege(roles.name,tables.name,'SELECT,INSERT,UPDATE,REFERENCES')
),'API roles have no membership or audit table privileges');
SELECT pg_temp.check_true(NOT EXISTS (
 SELECT 1 FROM (VALUES ('anon'),('authenticated')) roles(name)
 WHERE has_table_privilege(roles.name,'public.reports','INSERT,UPDATE,DELETE,TRUNCATE')
    OR has_any_column_privilege(roles.name,'public.reports','INSERT,UPDATE')
),'report writes remain RPC only');

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{"role":"anon"}',true);
SELECT pg_temp.denied('SELECT public.get_authority_access()');
SELECT pg_temp.denied('SELECT public.authority_dashboard()');
SELECT pg_temp.denied($s$ SELECT public.authority_report_detail('b6000000-0000-4000-8000-000000000001') $s$);
SELECT pg_temp.denied($s$ SELECT public.get_report_progress('b6000000-0000-4000-8000-000000000001') $s$);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001') $s$);
RESET ROLE;

SET LOCAL ROLE authenticated;
-- A signed-in API role without a subject is still denied.
SELECT pg_temp.denied('SELECT public.get_authority_access()');
SELECT set_config('request.jwt.claims','{"sub":"a6000000-0000-4000-8000-000000000001","role":"authenticated","user_metadata":{"role":"admin","active":true},"app_metadata":{"role":"admin"}}',true);
SELECT pg_temp.check_true(public.get_authority_access() IS NULL,'signup and JWT metadata never grant staff access');
SELECT pg_temp.denied('SELECT public.authority_dashboard()');
SELECT pg_temp.denied($s$ SELECT public.authority_report_detail('b6000000-0000-4000-8000-000000000001') $s$);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001') $s$);
SELECT pg_temp.check_true(public.get_report_progress('b6000000-0000-4000-8000-000000000001')='[]'::jsonb,'verified citizens see empty public history');
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_members VALUES ('a6000000-0000-4000-8000-000000000001','admin',NULL,true) $s$);
SELECT pg_temp.denied('SELECT * FROM civic_private.authority_members');
SELECT pg_temp.denied('SELECT * FROM civic_private.authority_report_events');
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_report_events(request_id,report_id,actor_id,from_status,to_status,note,expected_version,new_version)
 VALUES ('d6000000-0000-4000-8000-000000000001','b6000000-0000-4000-8000-000000000001','a6000000-0000-4000-8000-000000000004','pending','resolved','Spoofing a trusted admin actor.',0,1) $s$);
SELECT pg_temp.denied('UPDATE civic_private.authority_report_events SET note=''Forging a public progress note.''');
SELECT pg_temp.denied('DELETE FROM civic_private.authority_report_events');
SELECT pg_temp.denied('TRUNCATE civic_private.authority_report_events');
SELECT pg_temp.denied($s$ UPDATE public.reports SET status='resolved',version=9 WHERE id='b6000000-0000-4000-8000-000000000001' $s$);

-- Inactive and unconfirmed members cannot call any authority RPC.
DO $$ DECLARE n integer; BEGIN
 FOR n IN 5..6 LOOP
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub','a6000000-0000-4000-8000-'||lpad(n::text,12,'0'),'role','authenticated','email_verified',true)::text,true);
  IF n=5 THEN
   PERFORM pg_temp.check_true(public.get_authority_access() IS NULL,'inactive membership hidden');
  ELSE
   PERFORM pg_temp.denied('SELECT public.get_authority_access()');
   PERFORM pg_temp.denied($s$ SELECT public.get_report_progress('b6000000-0000-4000-8000-000000000001') $s$);
  END IF;
  PERFORM pg_temp.denied('SELECT public.authority_dashboard()');
  PERFORM pg_temp.denied($s$ SELECT public.authority_report_detail('b6000000-0000-4000-8000-000000000001') $s$);
  PERFORM pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001') $s$);
 END LOOP;
END $$;

SELECT set_config('request.jwt.claims','{"sub":"a6000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
SELECT pg_temp.check_true(public.get_authority_access()='{"role":"department","department":"Municipal Corportaion"}'::jsonb,'exact scoped access response');
SELECT pg_temp.check_true((public.authority_dashboard()->'counts')=pg_temp.expected_counts('municipal','{"total":3,"pending":2,"inprogress":0,"resolved":1,"rejected":0}'),'department counts exclude other scope');
SELECT pg_temp.check_true(public.authority_dashboard(p_query=>'AUTHSQL')->>'total'='3','scoped filtered total');
SELECT pg_temp.check_true(public.authority_dashboard(p_query=>'AUTHSQL',p_status=>'resolved')->>'total'='1' AND public.authority_dashboard(p_status=>'resolved')->'counts'->>'total'=(pg_temp.expected_counts('municipal','{"total":3}')->>'total'),'counts ignore filters');
SELECT pg_temp.check_true(public.authority_dashboard(p_category=>'Police Department')->>'total'='0' AND public.authority_dashboard(p_category=>'Police Department')->'counts'->>'total'=(pg_temp.expected_counts('municipal','{"total":3}')->>'total'),'category filter cannot widen membership');
SELECT pg_temp.check_true(public.authority_dashboard(p_query=>'%_')->>'total'='1' AND public.authority_dashboard(p_query=>'\\')->>'total'='0','search treats SQL wildcard characters literally');
SELECT pg_temp.check_true(public.authority_dashboard(p_query=>'mixedcase')->>'total'='1' AND public.authority_dashboard(p_query=>'authsql2')->>'total'='1','case insensitive description and reference search');
SELECT pg_temp.check_true(public.authority_dashboard(p_query=>'AUTHSQL',p_limit=>1)->'reports'->0->>'id'='b6000000-0000-4000-8000-000000000001','oldest default ordering');
SELECT pg_temp.check_true(public.authority_dashboard(p_query=>'AUTHSQL',p_limit=>1,p_offset=>1)->'reports'->0->>'id'='b6000000-0000-4000-8000-000000000002','bounded offset pagination');
SELECT pg_temp.check_true(public.authority_dashboard(p_sort=>'newest',p_query=>'AUTHSQL',p_limit=>1)->'reports'->0->>'id'='b6000000-0000-4000-8000-000000000004','newest sort');
SELECT pg_temp.check_true(public.authority_dashboard(p_sort=>'support',p_query=>'AUTHSQL',p_limit=>1)->'reports'->0->>'id'='b6000000-0000-4000-8000-000000000002','support sort');
SELECT pg_temp.check_true(public.authority_dashboard(p_query=>'AUTHSQL',p_offset=>100)->'reports'='[]'::jsonb AND public.authority_dashboard(p_query=>'AUTHSQL',p_offset=>100)->>'total'='3','empty page keeps filtered total');
SELECT pg_temp.check_true(((public.authority_dashboard()->'reports'->0) - ARRAY['version','updatedAt'])=(SELECT r FROM jsonb_array_elements(public.list_reports()) r WHERE r->>'id'='b6000000-0000-4000-8000-000000000001'),'authority rows preserve exact citizen public JSON');
SELECT pg_temp.check_true(NOT (public.authority_dashboard()->'reports'->0 ?| ARRAY['phone','cnic','email','gender','locations','actorId','requestId']),'no private profile or audit fields');
SELECT pg_temp.denied($s$ SELECT public.authority_report_detail('b6000000-0000-4000-8000-000000000003') $s$);
SELECT pg_temp.denied($s$ SELECT public.authority_report_detail('b6000000-0000-4000-8000-999999999999') $s$);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000003',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000003') $s$);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-999999999999',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000003') $s$);

DO $$ DECLARE statement text; BEGIN
 FOREACH statement IN ARRAY ARRAY[
  'SELECT public.authority_dashboard(p_query=>NULL)',
  'SELECT public.authority_dashboard(p_query=>repeat(''a'',121))',
  'SELECT public.authority_dashboard(p_limit=>NULL)',
  'SELECT public.authority_dashboard(p_limit=>0)',
  'SELECT public.authority_dashboard(p_limit=>51)',
  'SELECT public.authority_dashboard(p_offset=>NULL)',
  'SELECT public.authority_dashboard(p_offset=>-1)',
  'SELECT public.authority_dashboard(p_sort=>NULL)',
  'SELECT public.authority_dashboard(p_sort=>''oldest;DROP TABLE reports'')',
  'SELECT public.authority_dashboard(p_status=>''inProgress'')',
  'SELECT public.authority_dashboard(p_status=>'''')',
  'SELECT public.authority_dashboard(p_category=>''Police'')',
  'SELECT public.authority_report_detail(NULL)',
  'SELECT public.get_report_progress(NULL)'
 ] LOOP PERFORM pg_temp.denied(statement,ARRAY['23514']); END LOOP;
END $$;
-- NULL and invalid mutation fields must consistently yield the contract state.
DO $$ DECLARE args text; BEGIN
 FOREACH args IN ARRAY ARRAY[
  'NULL,0,''pending'',''A valid public note.'',''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',NULL,''pending'',''A valid public note.'',''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',-1,''pending'',''A valid public note.'',''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',0,NULL,''A valid public note.'',''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',0,''inProgress'',''A valid public note.'',''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',0,''pending'',NULL,''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',0,''pending'',''         '',''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',0,''pending'',repeat(chr(9)||chr(10),10),''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',0,''pending'',''123456789'',''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',0,''pending'',repeat(''x'',1001),''d6000000-0000-4000-8000-000000000001''',
  '''b6000000-0000-4000-8000-000000000001'',0,''pending'',''A valid public note.'',NULL'
 ] LOOP PERFORM pg_temp.denied('SELECT public.authority_update_report('||args||')',ARRAY['23514']); END LOOP;
END $$;
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'resolved','Cannot skip the investigation.','d6000000-0000-4000-8000-000000000001') $s$,ARRAY['23514']);

CREATE TEMP TABLE authority_receipt(receipt jsonb);
INSERT INTO authority_receipt SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','  Investigating this issue.  ','d6000000-0000-4000-8000-000000000001');
SELECT pg_temp.check_true((SELECT receipt->>'status'='inprogress' AND receipt->>'version'='1' AND receipt->>'updatedAt' IS NOT NULL AND receipt - ARRAY['id','status','version','updatedAt']='{}'::jsonb FROM authority_receipt),'exact mutation receipt');
SELECT pg_temp.check_true(public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001')=(SELECT receipt FROM authority_receipt),'canonical identical replay precedes stale version check');
SELECT pg_temp.check_true(public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress',chr(9)||chr(10)||'Investigating this issue.'||chr(13),'d6000000-0000-4000-8000-000000000001')=(SELECT receipt FROM authority_receipt),'canonical notes trim tabs and line endings');
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'rejected','Investigating this issue.','d6000000-0000-4000-8000-000000000001') $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',1,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001') $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','Different note payload.','d6000000-0000-4000-8000-000000000001') $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000002',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001') $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'resolved','A competing stale update.','d6000000-0000-4000-8000-000000000002') $s$,ARRAY['PT409']);
SELECT set_config('request.jwt.claims','{"sub":"a6000000-0000-4000-8000-000000000007","role":"authenticated"}',true);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001') $s$,ARRAY['23514']);
SELECT set_config('request.jwt.claims','{"sub":"a6000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',1,'inprogress','More investigation details.','d6000000-0000-4000-8000-000000000002');
SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',2,'resolved','Repairs have been completed.','d6000000-0000-4000-8000-000000000003');
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',3,'rejected','Invalid resolved transition.','d6000000-0000-4000-8000-000000000004') $s$,ARRAY['23514']);
SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',3,'inprogress','Reopened after further checks.','d6000000-0000-4000-8000-000000000004');
SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',4,'rejected','This requires another process.','d6000000-0000-4000-8000-000000000005');
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',5,'pending','Cannot return to pending state.','d6000000-0000-4000-8000-000000000006') $s$,ARRAY['23514']);
SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',5,'inprogress','Reopened for another review.','d6000000-0000-4000-8000-000000000006');
SELECT pg_temp.check_true(public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001')=(SELECT receipt FROM authority_receipt),'replay returns original receipt after subsequent edits');
SELECT pg_temp.check_true(public.authority_report_detail('b6000000-0000-4000-8000-000000000001')->'history'=public.get_report_progress('b6000000-0000-4000-8000-000000000001'),'staff and citizen history share public contract');
SELECT pg_temp.check_true(public.authority_report_detail('b6000000-0000-4000-8000-000000000001')->'report'->>'version'='6','committed version in detail');
SELECT pg_temp.check_true(jsonb_array_length(public.get_report_progress('b6000000-0000-4000-8000-000000000001'))=6,'one event per committed mutation');
SELECT pg_temp.check_true(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(public.get_report_progress('b6000000-0000-4000-8000-000000000001')) h WHERE h - ARRAY['id','fromStatus','toStatus','note','createdAt','version']<>'{}'::jsonb),'public history excludes actor and request identifiers');
RESET ROLE;

SELECT pg_temp.check_true((SELECT version=6 AND status='inprogress' FROM public.reports WHERE id='b6000000-0000-4000-8000-000000000001'),'failed mutations have no report side effects');
SELECT pg_temp.check_true((SELECT count(*)=6 AND min(expected_version)=0 AND max(new_version)=6 FROM civic_private.authority_report_events WHERE report_id='b6000000-0000-4000-8000-000000000001'),'failed mutations and retries insert no audit events');
SELECT pg_temp.check_true((SELECT note='Investigating this issue.' FROM civic_private.authority_report_events WHERE request_id='d6000000-0000-4000-8000-000000000001'),'audit note is canonical');
SELECT pg_temp.check_true((SELECT r.updated_at=e.created_at FROM public.reports r JOIN civic_private.authority_report_events e ON e.report_id=r.id AND e.new_version=r.version WHERE r.id='b6000000-0000-4000-8000-000000000001'),'receipt, audit and report timestamps agree');
SELECT pg_temp.denied('UPDATE civic_private.authority_report_events SET note=''Rewriting immutable history.''',ARRAY['23514']);
SELECT pg_temp.denied('DELETE FROM civic_private.authority_report_events',ARRAY['23514']);
SELECT pg_temp.denied('TRUNCATE civic_private.authority_report_events',ARRAY['23514']);
-- A malformed privileged insert still cannot bypass audit constraints.
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_report_events(request_id,report_id,actor_id,from_status,to_status,note,expected_version,new_version)
 VALUES ('d6000000-0000-4000-8000-000000000009','b6000000-0000-4000-8000-000000000001','a6000000-0000-4000-8000-000000000002','pending','resolved','Invalid shortcut to resolved.',6,7) $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_report_events(request_id,report_id,actor_id,from_status,to_status,note,expected_version,new_version)
 VALUES ('d6000000-0000-4000-8000-000000000009','b6000000-0000-4000-8000-000000000001','a6000000-0000-4000-8000-000000000002','pending','pending','  Untrimmed public note.  ',6,7) $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_report_events(request_id,report_id,actor_id,from_status,to_status,note,expected_version,new_version)
 VALUES ('d6000000-0000-4000-8000-000000000009','b6000000-0000-4000-8000-000000000001','a6000000-0000-4000-8000-000000000002','pending','pending','A valid public note.',6,9) $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ INSERT INTO civic_private.authority_report_events(request_id,report_id,actor_id,from_status,to_status,note,expected_version,new_version)
 VALUES ('d6000000-0000-4000-8000-000000000001','b6000000-0000-4000-8000-000000000001','a6000000-0000-4000-8000-000000000002','pending','pending','A valid public note.',6,7) $s$,ARRAY['23505']);

-- Current membership is rechecked even when the request has already succeeded.
UPDATE civic_private.authority_members SET active=false WHERE user_id='a6000000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"a6000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001') $s$);
RESET ROLE;
UPDATE civic_private.authority_members SET active=true,department='Police Department' WHERE user_id='a6000000-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied($s$ SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000001',0,'inprogress','Investigating this issue.','d6000000-0000-4000-8000-000000000001') $s$);
SELECT set_config('request.jwt.claims','{"sub":"a6000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
SELECT pg_temp.check_true(public.get_authority_access()='{"role":"admin","department":null}'::jsonb,'admin exact access response');
SELECT pg_temp.check_true(public.authority_dashboard()->'counts'->>'total'=(pg_temp.expected_counts('admin','{"total":4}')->>'total'),'admin sees all departments');
SELECT pg_temp.check_true(public.authority_report_detail('b6000000-0000-4000-8000-000000000003')->'report'->>'category'='Police Department','admin detail crosses departments');
SELECT public.authority_update_report('b6000000-0000-4000-8000-000000000003',0,'rejected','Referral outside this service.','d6000000-0000-4000-8000-000000000007');
-- Generate enough real same-status mutations to exercise history/page bounds.
DO $$ DECLARE n integer; BEGIN
 FOR n IN 1..105 LOOP
  PERFORM public.authority_update_report('b6000000-0000-4000-8000-000000000003',n,'rejected',
    'Public progress note number '||n,('d6000000-0000-4000-8001-'||lpad(n::text,12,'0'))::uuid);
 END LOOP;
END $$;
SELECT pg_temp.check_true(jsonb_array_length(public.get_report_progress('b6000000-0000-4000-8000-000000000003'))=100
 AND public.get_report_progress('b6000000-0000-4000-8000-000000000003')->0->>'version'='106'
 AND public.get_report_progress('b6000000-0000-4000-8000-000000000003')->99->>'version'='7','history bounded newest first');
SELECT pg_temp.check_true(jsonb_array_length(public.authority_report_detail('b6000000-0000-4000-8000-000000000003')->'history')=100,'detail history bounded');
SELECT pg_temp.denied('SELECT * FROM civic_private.authority_report_events');
SELECT pg_temp.denied($s$ DELETE FROM public.reports WHERE id='b6000000-0000-4000-8000-000000000003' $s$);
SELECT set_config('request.jwt.claims','{"sub":"a6000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
SELECT pg_temp.check_true(public.get_report_progress('b6000000-0000-4000-8000-000000000003')->0->>'note'='Public progress note number 105','citizen sees committed public notes');
-- Existing owner deletion remains available, including reports with progress.
SELECT public.delete_report('b6000000-0000-4000-8000-000000000003');
SELECT pg_temp.denied($s$ SELECT public.get_report_progress('b6000000-0000-4000-8000-000000000003') $s$);
RESET ROLE;
SELECT pg_temp.check_true((SELECT count(*)=106 FROM civic_private.authority_report_events WHERE report_id='b6000000-0000-4000-8000-000000000003'),'owner deletion preserves immutable request ledger');

-- Enough rows with equal creation times to verify real bounds and tie ordering.
INSERT INTO public.reports(id,reporter_id,title,description,category,status,latitude,longitude,media_paths,report_code,created_at)
SELECT ('b6000000-0000-4000-8001-'||lpad(n::text,12,'0'))::uuid,
 'a6000000-0000-4000-8000-000000000001','Bounded queue fixture '||n,
 'A sufficiently long description for bounded queue checks.','Police Department',
 CASE n WHEN 1 THEN 'pending' WHEN 2 THEN 'inprogress' WHEN 3 THEN 'resolved' ELSE 'rejected' END,
 33.55,72.63,ARRAY['a6000000-0000-4000-8000-000000000001/c6000000-0000-4000-8000-000000000001.jpg'],
 'AUTHBOUND'||n,'2026-02-01'::timestamptz FROM generate_series(1,55) n;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"a6000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
SELECT pg_temp.check_true(jsonb_array_length(public.authority_dashboard(p_query=>'AUTHBOUND')->'reports')=20
 AND jsonb_array_length(public.authority_dashboard(p_query=>'AUTHBOUND',p_limit=>50)->'reports')=50
 AND public.authority_dashboard(p_query=>'AUTHBOUND')->>'total'='55','default and maximum page bounds on a larger queue');
SELECT pg_temp.check_true(public.authority_dashboard(p_query=>'AUTHBOUND',p_limit=>1,p_offset=>1)->'reports'->0->>'id'='b6000000-0000-4000-8001-000000000002'
 AND public.authority_dashboard(p_query=>'AUTHBOUND',p_sort=>'newest',p_limit=>1)->'reports'->0->>'id'='b6000000-0000-4000-8001-000000000055','creation-time ties have deterministic UUID order');
-- Exercise every canonical transition, rolling successful calls back inside a
-- subtransaction so each source fixture remains at version zero.
DO $$ DECLARE
 from_state text; to_state text; report_id uuid; allowed boolean;
 n integer := 0; states text[] := ARRAY['pending','inprogress','resolved','rejected'];
BEGIN
 FOREACH from_state IN ARRAY states LOOP
  n := n+1;
  report_id := ('b6000000-0000-4000-8001-'||lpad(n::text,12,'0'))::uuid;
  FOREACH to_state IN ARRAY states LOOP
   allowed := from_state=to_state OR (from_state='pending' AND to_state IN ('inprogress','rejected'))
    OR (from_state='inprogress' AND to_state IN ('resolved','rejected'))
    OR (from_state IN ('resolved','rejected') AND to_state='inprogress');
   BEGIN
    PERFORM public.authority_update_report(report_id,0,to_state,'Transition matrix public note.',
      'd6000000-0000-4000-8002-000000000001');
    PERFORM pg_temp.check_true(allowed,'transition unexpectedly allowed: '||from_state||' -> '||to_state);
    RAISE EXCEPTION 'Rollback successful matrix update' USING ERRCODE='Z6000';
   EXCEPTION
    WHEN SQLSTATE 'Z6000' THEN NULL;
    WHEN check_violation THEN
     PERFORM pg_temp.check_true(NOT allowed,'transition unexpectedly denied: '||from_state||' -> '||to_state);
   END;
  END LOOP;
 END LOOP;
END $$;
RESET ROLE;
DELETE FROM auth.users WHERE id='a6000000-0000-4000-8000-000000000002';
SELECT pg_temp.check_true((SELECT count(*)=6 FROM civic_private.authority_report_events WHERE actor_id='a6000000-0000-4000-8000-000000000002'),'account deletion preserves audit actor identifiers');
SELECT pg_temp.check_true(NOT EXISTS (
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace,
 LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
 WHERE n.nspname IN ('public','civic_private') AND p.prosecdef
 AND (NOT ('search_path=""'=ANY(coalesce(p.proconfig,ARRAY[]::text[]))) OR (a.grantee=0 AND a.privilege_type='EXECUTE'))
),'security definer paths and PUBLIC execution sealed');
SELECT pg_temp.check_true(NOT EXISTS (
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='civic_private' AND p.proname LIKE '%authority%'
 AND (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE')
   OR has_function_privilege('service_role',p.oid,'EXECUTE'))
),'authority helpers cannot be invoked by API roles');
-- Reporter account deletion removes old tombstones, but retained progress must
-- still prevent a different citizen from reusing the old report UUID.
DELETE FROM auth.users WHERE id='a6000000-0000-4000-8000-000000000001';
SELECT pg_temp.check_true(NOT EXISTS (SELECT 1 FROM civic_private.report_tombstones WHERE request_id='b6000000-0000-4000-8000-000000000003'), 'account deletion removes owner tombstone fixture');
INSERT INTO storage.objects(bucket_id,name,owner_id,metadata) VALUES
 ('reports-images','a6000000-0000-4000-8000-000000000007/c6000000-0000-4000-8000-000000000099.jpg','a6000000-0000-4000-8000-000000000007','{"mimetype":"image/jpeg","size":100}');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"a6000000-0000-4000-8000-000000000007","role":"authenticated"}',true);
SELECT pg_temp.denied($s$ SELECT public.create_report('Different citizen issue','A different report must not inherit old service history.','Municipal Corportaion',33.55,72.63,
 ARRAY['a6000000-0000-4000-8000-000000000007/c6000000-0000-4000-8000-000000000099.jpg'], 'b6000000-0000-4000-8000-000000000003') $s$,ARRAY['23514']);
SELECT pg_temp.denied($s$ SELECT public.get_report_progress('b6000000-0000-4000-8000-000000000003') $s$);
RESET ROLE;
SELECT pg_temp.check_true(NOT EXISTS (SELECT 1 FROM public.reports WHERE id='b6000000-0000-4000-8000-000000000003'), 'retained progress identity is never reassigned');
ROLLBACK;
