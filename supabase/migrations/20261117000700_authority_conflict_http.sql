-- Stale edits are business conflicts, not retryable database serialization errors.
-- PostgREST maps PT409 to HTTP 409 without retrying the transaction.
-- https://supabase.com/kb/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b
BEGIN;
CREATE OR REPLACE FUNCTION public.authority_update_report(
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
    RAISE EXCEPTION 'Report version changed; reload before updating' USING ERRCODE='PT409';
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

COMMIT;
