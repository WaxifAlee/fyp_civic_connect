-- Rollback-only comments authorization, privacy and replay checks after migration 008.
BEGIN;
CREATE FUNCTION pg_temp.check_true(ok boolean, label text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
END $$;
CREATE FUNCTION pg_temp.denied(statement text, states text[] DEFAULT ARRAY['42501']) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
 BEGIN EXECUTE statement;
 EXCEPTION WHEN OTHERS THEN
  IF SQLSTATE=ANY(states) THEN RETURN; END IF;
  RAISE EXCEPTION 'Unexpected %: %',SQLSTATE,SQLERRM;
 END;
 RAISE EXCEPTION 'FAIL: forbidden statement accepted: %',statement;
END $$;
SELECT pg_temp.check_true(to_regprocedure('public.add_report_comment(uuid,text,uuid)') IS NOT NULL,'comment contract exists');
SELECT pg_temp.check_true(civic_private.canonical_comment('very useful')='very useful'
 AND civic_private.canonical_comment('v')='v'
 AND civic_private.canonical_comment(chr(11))='','canonical trim preserves v and removes vertical tab');
INSERT INTO auth.users(id,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
SELECT ('a8000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'comments-sql-'||n||'@example.invalid',CASE WHEN n<3 THEN now() END,
 '{"provider":"email","providers":["email"]}'::jsonb,
 jsonb_build_object('full_name','Comment Citizen '||n,'phone','+92300888000'||n,
 'cnic','12345-888000'||n||'-1','locations','Fateh Jang','gender','Other')
FROM generate_series(1,3) n;
INSERT INTO public.reports(id,reporter_id,title,description,category,latitude,longitude,media_paths,report_code)
VALUES('b8000000-0000-4000-8000-000000000001','a8000000-0000-4000-8000-000000000001',
 'Comment test issue','A sufficiently detailed issue for comments testing.',
 'Municipal Corportaion',33.55,72.63,ARRAY['a8000000-0000-4000-8000-000000000001/comments.jpg'],'COMMENTSQL1');
SELECT pg_temp.check_true(NOT EXISTS (
 SELECT 1 FROM (VALUES ('anon'),('authenticated'),('service_role')) roles(name)
 WHERE has_table_privilege(roles.name,'civic_private.report_comments','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
 OR has_any_column_privilege(roles.name,'civic_private.report_comments','SELECT,INSERT,UPDATE,REFERENCES')
),'private comment table has no API grants');
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{"role":"anon"}',true);
SELECT pg_temp.denied($s$SELECT public.list_report_comments('b8000000-0000-4000-8000-000000000001')$s$);
SELECT pg_temp.denied($s$SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001','hello','c8000000-0000-4000-8000-000000000001')$s$);
SELECT pg_temp.denied($s$SELECT public.delete_report_comment('b8000000-0000-4000-8000-000000000001','c8000000-0000-4000-8000-000000000001')$s$);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"a8000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
SELECT pg_temp.denied($s$SELECT public.list_report_comments('b8000000-0000-4000-8000-000000000001')$s$);
SELECT pg_temp.denied($s$SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001','hello','c8000000-0000-4000-8000-000000000001')$s$);
SELECT set_config('request.jwt.claims','{"sub":"a8000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
SELECT pg_temp.denied($s$SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001',E' \n\t ','c8000000-0000-4000-8000-000000000001')$s$,ARRAY['23514']);
SELECT pg_temp.denied($s$SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001',repeat('x',1001),'c8000000-0000-4000-8000-000000000001')$s$,ARRAY['23514']);
SELECT pg_temp.denied($s$SELECT public.add_report_comment(NULL,'hello','c8000000-0000-4000-8000-000000000001')$s$);
SELECT pg_temp.denied($s$SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001','hello',NULL)$s$,ARRAY['23514']);
SELECT set_config('civic_test.comment_receipt',public.add_report_comment('b8000000-0000-4000-8000-000000000001','  Site flooded.  ','c8000000-0000-4000-8000-000000000001')::text,true);
SELECT pg_temp.check_true(public.add_report_comment('b8000000-0000-4000-8000-000000000001','Site flooded.','c8000000-0000-4000-8000-000000000001')=current_setting('civic_test.comment_receipt')::jsonb,'identical retry returns same receipt');
SELECT pg_temp.check_true((current_setting('civic_test.comment_receipt')::jsonb->>'body')='Site flooded.','body canonicalized');
SELECT pg_temp.check_true((SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(current_setting('civic_test.comment_receipt')::jsonb) k)=ARRAY['authorName','body','createdAt','id','isMine','reportId'],'only public comment fields projected');
SELECT pg_temp.denied($s$SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001','Changed payload','c8000000-0000-4000-8000-000000000001')$s$,ARRAY['23514']);
SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001',repeat('🌳',1000),'c8000000-0000-4000-8000-000000000002');
SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001',chr(160)||'Unicode trim'||chr(160),'c8000000-0000-4000-8000-000000000003');
SELECT pg_temp.check_true(public.add_report_comment('b8000000-0000-4000-8000-000000000001','Unicode trim','c8000000-0000-4000-8000-000000000003')->>'body'='Unicode trim','Unicode whitespace uses the same canonical digest');
SELECT pg_temp.check_true((public.list_report_comments('b8000000-0000-4000-8000-000000000001',2)->>'hasMore')::boolean,'bounded first page has more');
SELECT pg_temp.denied($s$SELECT public.list_report_comments('b8000000-0000-4000-8000-000000000001',51)$s$,ARRAY['23514']);
SELECT pg_temp.denied($s$SELECT public.list_report_comments('b8000000-0000-4000-8000-000000000001',20,now(),NULL)$s$,ARRAY['23514']);
SELECT set_config('request.jwt.claims','{"sub":"a8000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
SELECT pg_temp.check_true(NOT (public.list_report_comments('b8000000-0000-4000-8000-000000000001')->'comments'->0->>'isMine')::boolean,'other readers are not owners');
SELECT pg_temp.denied($s$SELECT public.delete_report_comment('b8000000-0000-4000-8000-000000000001','c8000000-0000-4000-8000-000000000001')$s$);
SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001','Second citizen comment','c8000000-0000-4000-8000-000000000004');
SELECT pg_temp.denied($s$SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001','Site flooded.','c8000000-0000-4000-8000-000000000001')$s$,ARRAY['23514']);
SELECT set_config('request.jwt.claims','{"sub":"a8000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
SELECT public.delete_report_comment('b8000000-0000-4000-8000-000000000001','c8000000-0000-4000-8000-000000000001');
SELECT public.delete_report_comment('b8000000-0000-4000-8000-000000000001','c8000000-0000-4000-8000-000000000001');
SELECT pg_temp.denied($s$SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001','Site flooded.','c8000000-0000-4000-8000-000000000001')$s$,ARRAY['PT409']);
SELECT pg_temp.check_true(jsonb_array_length(public.list_report_comments('b8000000-0000-4000-8000-000000000001')->'comments')=3,'removed comment excluded from public listing');
RESET ROLE;
SELECT pg_temp.check_true((SELECT body IS NULL AND deleted_at IS NOT NULL FROM civic_private.report_comments WHERE id='c8000000-0000-4000-8000-000000000001'),'removal erases body and retains private tombstone');
DELETE FROM auth.users WHERE id='a8000000-0000-4000-8000-000000000002';
SELECT pg_temp.check_true(NOT EXISTS(SELECT 1 FROM civic_private.report_comments WHERE id='c8000000-0000-4000-8000-000000000004'),'author account deletion cascades own comments on other reports');
-- Equal timestamps still page deterministically by id.
UPDATE civic_private.report_comments SET created_at='2026-01-01';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"a8000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
SELECT pg_temp.check_true(public.list_report_comments('b8000000-0000-4000-8000-000000000001',1)->'comments'->0->>'id'='c8000000-0000-4000-8000-000000000003','keyset first id tie break');
SELECT pg_temp.check_true(public.list_report_comments('b8000000-0000-4000-8000-000000000001',1,'2026-01-01','c8000000-0000-4000-8000-000000000003')->'comments'->0->>'id'='c8000000-0000-4000-8000-000000000002','keyset next id tie break');
SELECT public.delete_report('b8000000-0000-4000-8000-000000000001');
SELECT pg_temp.denied($s$SELECT public.list_report_comments('b8000000-0000-4000-8000-000000000001')$s$);
SELECT pg_temp.denied($s$SELECT public.add_report_comment('b8000000-0000-4000-8000-000000000001','Late retry','c8000000-0000-4000-8000-000000000004')$s$);
RESET ROLE;
SELECT pg_temp.check_true(NOT EXISTS(SELECT 1 FROM civic_private.report_comments WHERE report_id='b8000000-0000-4000-8000-000000000001'),'report deletion cascades all comment rows');
ROLLBACK;
