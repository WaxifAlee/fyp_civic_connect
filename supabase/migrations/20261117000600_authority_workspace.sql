-- Trusted service-team membership and bounded RPCs. Citizen RPCs/ACLs stay intact.
BEGIN;

CREATE TABLE civic_private.authority_members (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('admin','department')),
  department text,
  active boolean NOT NULL DEFAULT true,
  CHECK ((role='admin' AND department IS NULL) OR
    (role='department' AND department IS NOT NULL AND department IN (
      'Municipal Corportaion','Police Department','Fire & Emergency Services',
      'Electricity & Gas Department','Public Works Department (PWD)')))
);
ALTER TABLE civic_private.authority_members ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE civic_private.authority_members FROM PUBLIC,anon,authenticated,service_role;

ALTER TABLE public.reports
  ADD COLUMN version integer NOT NULL DEFAULT 0 CHECK (version>=0),
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
CREATE INDEX reports_authority_queue_idx ON public.reports(category,created_at,id);

CREATE TABLE civic_private.authority_report_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL UNIQUE,
  -- Deliberately no cascading report/actor FKs: immutable audit and request
  -- identities survive existing citizen report/account deletion workflows.
  report_id uuid NOT NULL,
  actor_id uuid NOT NULL,
  from_status text NOT NULL CHECK (from_status IN ('pending','inprogress','resolved','rejected')),
  to_status text NOT NULL CHECK (to_status IN ('pending','inprogress','resolved','rejected')),
  note text NOT NULL CHECK (
    note=regexp_replace(note,'^[[:space:]]+|[[:space:]]+$','','g')
    AND char_length(note) BETWEEN 10 AND 1000),
  expected_version integer NOT NULL CHECK (expected_version>=0),
  new_version integer NOT NULL CHECK (new_version::bigint=expected_version::bigint+1),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (report_id,new_version),
  CHECK (from_status=to_status OR
    (from_status='pending' AND to_status IN ('inprogress','rejected')) OR
    (from_status='inprogress' AND to_status IN ('resolved','rejected')) OR
    (from_status IN ('resolved','rejected') AND to_status='inprogress'))
);
CREATE INDEX authority_report_events_history_idx
  ON civic_private.authority_report_events(report_id,created_at DESC,new_version DESC,id DESC);
ALTER TABLE civic_private.authority_report_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE civic_private.authority_report_events FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION civic_private.protect_authority_history() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION 'Authority progress history is immutable' USING ERRCODE='23514';
END $$;
REVOKE ALL ON FUNCTION civic_private.protect_authority_history() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER authority_history_immutable BEFORE UPDATE OR DELETE
  ON civic_private.authority_report_events FOR EACH ROW
  EXECUTE FUNCTION civic_private.protect_authority_history();
CREATE TRIGGER authority_history_no_truncate BEFORE TRUNCATE
  ON civic_private.authority_report_events FOR EACH STATEMENT
  EXECUTE FUNCTION civic_private.protect_authority_history();

-- Audit identities outlive reporter deletion. Even when Auth cascades remove
-- the report tombstone, a client-selected UUID must not inherit old history.
CREATE FUNCTION civic_private.protect_authority_report_identity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM civic_private.authority_report_events e WHERE e.report_id=NEW.id) THEN
    RAISE EXCEPTION 'Report identity has been retired' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION civic_private.protect_authority_report_identity() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER authority_report_identity BEFORE INSERT ON public.reports
  FOR EACH ROW EXECUTE FUNCTION civic_private.protect_authority_report_identity();

CREATE FUNCTION public.get_authority_access() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); result jsonb;
BEGIN
  SELECT jsonb_build_object('role',m.role,'department',m.department) INTO result
  FROM civic_private.authority_members m WHERE m.user_id=uid AND m.active;
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.get_authority_access() FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_authority_access() TO authenticated;

CREATE FUNCTION civic_private.require_authority_member()
RETURNS civic_private.authority_members
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); member civic_private.authority_members%ROWTYPE;
BEGIN
  SELECT * INTO member FROM civic_private.authority_members m WHERE m.user_id=uid AND m.active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active authority membership required' USING ERRCODE='42501'; END IF;
  RETURN member;
END $$;
REVOKE ALL ON FUNCTION civic_private.require_authority_member() FROM PUBLIC,anon,authenticated,service_role;

-- This projection intentionally matches list_reports, adding only the version
-- and update timestamp. It never serializes an entire profile or audit row.
CREATE FUNCTION civic_private.authority_report_json(p_report public.reports,p_uid uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'id',(p_report).id,'title',(p_report).title,'description',(p_report).description,
    'category',(p_report).category,'status',(p_report).status,
    'location',(p_report).latitude::text||', '||(p_report).longitude::text,
    'images',to_jsonb((p_report).media_paths),'reporterId',(p_report).reporter_id,
    'reporterName',p.full_name,'avatar',p.profile_picture,'timestamp',(p_report).created_at,
    'reportCode',(p_report).report_code,'upvotes',(p_report).support_count,
    'upvotedBy',CASE WHEN EXISTS (SELECT 1 FROM public.report_supports s
      WHERE s.report_id=(p_report).id AND s.user_id=p_uid)
      THEN jsonb_build_array(p_uid) ELSE '[]'::jsonb END,
    'version',(p_report).version,'updatedAt',(p_report).updated_at)
  FROM public.profiles p WHERE p.id=(p_report).reporter_id;
$$;
REVOKE ALL ON FUNCTION civic_private.authority_report_json(public.reports,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION civic_private.authority_public_history(p_report_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',e.id,'fromStatus',e.from_status,'toStatus',e.to_status,'note',e.note,
    'createdAt',e.created_at,'version',e.new_version)
    ORDER BY e.created_at DESC,e.new_version DESC,e.id DESC),'[]'::jsonb)
  FROM (SELECT id,from_status,to_status,note,created_at,new_version
    FROM civic_private.authority_report_events WHERE report_id=p_report_id
    ORDER BY created_at DESC,new_version DESC,id DESC LIMIT 100) e;
$$;
REVOKE ALL ON FUNCTION civic_private.authority_public_history(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.authority_dashboard(
  p_query text DEFAULT '',p_status text DEFAULT NULL,p_category text DEFAULT NULL,
  p_sort text DEFAULT 'oldest',p_limit integer DEFAULT 20,p_offset integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE member civic_private.authority_members := civic_private.require_authority_member(); result jsonb;
BEGIN
  IF p_query IS NULL OR char_length(p_query)>120
    OR (p_status IS NOT NULL AND p_status NOT IN ('pending','inprogress','resolved','rejected'))
    OR (p_category IS NOT NULL AND p_category NOT IN (
      'Municipal Corportaion','Police Department','Fire & Emergency Services',
      'Electricity & Gas Department','Public Works Department (PWD)'))
    OR p_sort IS NULL OR p_sort NOT IN ('oldest','newest','support')
    OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50
    OR p_offset IS NULL OR p_offset<0 THEN
    RAISE EXCEPTION 'Invalid authority queue filters or pagination' USING ERRCODE='23514';
  END IF;
  WITH scoped AS MATERIALIZED (
    SELECT r.* FROM public.reports r WHERE member.role='admin' OR r.category=member.department
  ), filtered AS MATERIALIZED (
    SELECT r.* FROM scoped r
    WHERE (p_status IS NULL OR r.status=p_status) AND (p_category IS NULL OR r.category=p_category)
      -- strpos is literal, including %, _ and backslashes; no dynamic SQL.
      AND (p_query='' OR strpos(lower(r.title),lower(p_query))>0
        OR strpos(lower(r.report_code),lower(p_query))>0
        OR strpos(lower(r.description),lower(p_query))>0)
  ), page AS (
    SELECT r.id,row_number() OVER (ORDER BY
      CASE WHEN p_sort='support' THEN r.support_count END DESC,
      CASE WHEN p_sort='newest' THEN r.created_at END DESC,
      CASE WHEN p_sort IN ('oldest','support') THEN r.created_at END ASC,
      CASE WHEN p_sort='newest' THEN r.id END DESC,r.id ASC) AS ordinal
    FROM filtered r ORDER BY ordinal LIMIT p_limit OFFSET p_offset
  )
  SELECT jsonb_build_object(
    'reports',(SELECT coalesce(jsonb_agg(civic_private.authority_report_json(r,member.user_id)
      ORDER BY page.ordinal),'[]'::jsonb) FROM page JOIN public.reports r ON r.id=page.id),
    'total',(SELECT count(*) FROM filtered),
    'counts',(SELECT jsonb_build_object('total',count(*),
      'pending',count(*) FILTER (WHERE status='pending'),
      'inprogress',count(*) FILTER (WHERE status='inprogress'),
      'resolved',count(*) FILTER (WHERE status='resolved'),
      'rejected',count(*) FILTER (WHERE status='rejected')) FROM scoped)) INTO result;
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.authority_dashboard(text,text,text,text,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.authority_dashboard(text,text,text,text,integer,integer) TO authenticated;

CREATE FUNCTION public.authority_report_detail(p_report_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE member civic_private.authority_members := civic_private.require_authority_member(); report public.reports%ROWTYPE;
BEGIN
  IF p_report_id IS NULL THEN RAISE EXCEPTION 'Report UUID required' USING ERRCODE='23514'; END IF;
  SELECT * INTO report FROM public.reports r
  WHERE r.id=p_report_id AND (member.role='admin' OR r.category=member.department);
  IF NOT FOUND THEN RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object('report',civic_private.authority_report_json(report,member.user_id),
    'history',civic_private.authority_public_history(report.id));
END $$;
REVOKE ALL ON FUNCTION public.authority_report_detail(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.authority_report_detail(uuid) TO authenticated;

CREATE FUNCTION public.authority_update_report(
  p_report_id uuid,p_expected_version integer,p_status text,p_note text,p_request_id uuid
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := civic_private.require_verified_user();
  member civic_private.authority_members%ROWTYPE;
  report public.reports%ROWTYPE;
  event civic_private.authority_report_events%ROWTYPE;
  canonical_note text := regexp_replace(p_note,'^[[:space:]]+|[[:space:]]+$','','g');
  committed_at timestamptz;
BEGIN
  -- FOR SHARE, not KEY SHARE: revoking active or changing department is a
  -- non-key UPDATE. Both it and DELETE must wait until this mutation commits.
  -- Conversely, after waiting on an administration transaction this VOLATILE
  -- function checks the newly committed membership, never a cached JWT role.
  SELECT * INTO member FROM civic_private.authority_members m WHERE m.user_id=uid FOR SHARE;
  IF NOT FOUND OR NOT member.active THEN
    RAISE EXCEPTION 'Active authority membership required' USING ERRCODE='42501';
  END IF;
  IF p_report_id IS NULL OR p_expected_version IS NULL OR p_expected_version<0
    OR p_status IS NULL OR p_status NOT IN ('pending','inprogress','resolved','rejected')
    OR canonical_note IS NULL OR char_length(canonical_note) NOT BETWEEN 10 AND 1000
    OR p_request_id IS NULL THEN
    RAISE EXCEPTION 'Invalid authority update' USING ERRCODE='23514';
  END IF;
  -- A global request namespace serializes retries across actors/reports before
  -- looking up the durable request ledger. Hash collisions only add contention.
  PERFORM pg_advisory_xact_lock(hashtextextended('civic-authority-request:'||p_request_id::text,0));
  SELECT * INTO report FROM public.reports r
    WHERE r.id=p_report_id AND (member.role='admin' OR r.category=member.department) FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501'; END IF;
  SELECT * INTO event FROM civic_private.authority_report_events e WHERE e.request_id=p_request_id;
  IF FOUND THEN
    IF (event.actor_id,event.report_id,event.expected_version,event.to_status,event.note)
      IS DISTINCT FROM (uid,p_report_id,p_expected_version,p_status,canonical_note) THEN
      RAISE EXCEPTION 'Request cannot be reused for this update' USING ERRCODE='23514';
    END IF;
    RETURN jsonb_build_object('id',event.report_id,'status',event.to_status,
      'version',event.new_version,'updatedAt',event.created_at);
  END IF;
  IF report.version<>p_expected_version THEN
    RAISE EXCEPTION 'Report version changed; reload before updating' USING ERRCODE='40001';
  END IF;
  IF NOT (report.status=p_status OR
    (report.status='pending' AND p_status IN ('inprogress','rejected')) OR
    (report.status='inprogress' AND p_status IN ('resolved','rejected')) OR
    (report.status IN ('resolved','rejected') AND p_status='inprogress')) THEN
    RAISE EXCEPTION 'Invalid report status transition' USING ERRCODE='23514';
  END IF;
  IF report.version=2147483647 THEN
    RAISE EXCEPTION 'Report version limit reached' USING ERRCODE='23514';
  END IF;
  committed_at := clock_timestamp();
  UPDATE public.reports SET status=p_status,version=report.version+1,updated_at=committed_at WHERE id=report.id;
  INSERT INTO civic_private.authority_report_events(
    request_id,report_id,actor_id,from_status,to_status,note,expected_version,new_version,created_at)
  VALUES (p_request_id,report.id,uid,report.status,p_status,canonical_note,report.version,report.version+1,committed_at);
  RETURN jsonb_build_object('id',report.id,'status',p_status,'version',report.version+1,'updatedAt',committed_at);
END $$;
REVOKE ALL ON FUNCTION public.authority_update_report(uuid,integer,text,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.authority_update_report(uuid,integer,text,text,uuid) TO authenticated;

CREATE FUNCTION public.get_report_progress(p_report_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user();
BEGIN
  IF p_report_id IS NULL THEN RAISE EXCEPTION 'Report UUID required' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.reports WHERE id=p_report_id) THEN
    RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501';
  END IF;
  RETURN civic_private.authority_public_history(p_report_id);
END $$;
REVOKE ALL ON FUNCTION public.get_report_progress(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_report_progress(uuid) TO authenticated;

COMMIT;
