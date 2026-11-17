-- Retired request identifiers outlive storage cleanup, preventing delayed
-- retries from recreating an issue after the citizen has deleted it.
BEGIN;
CREATE TABLE civic_private.report_tombstones (
  request_id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  deleted_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX report_tombstones_owner_idx ON civic_private.report_tombstones(owner_id);
ALTER TABLE civic_private.report_tombstones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE civic_private.report_tombstones FROM PUBLIC,anon,authenticated;
INSERT INTO civic_private.report_tombstones(request_id,owner_id)
SELECT report_id,owner_id FROM public.report_cleanup;

CREATE OR REPLACE FUNCTION public.create_report(
  p_title text,p_description text,p_category text,
  p_latitude double precision,p_longitude double precision,p_media_paths text[],
  p_request_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := civic_private.require_verified_user();
  canonical_title text := btrim(p_title);
  canonical_description text := btrim(p_description);
  existing public.reports%ROWTYPE;
  prefix text; next_counter bigint; code text;
BEGIN
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'Request UUID required' USING ERRCODE='23514'; END IF;
  -- MUST precede lookup, including for retries that raced the original call.
  -- The prefix separates this lock namespace from other application locks.
  PERFORM pg_advisory_xact_lock(hashtextextended('civic-report:'||p_request_id::text,0));
  IF EXISTS (SELECT 1 FROM civic_private.report_tombstones WHERE request_id=p_request_id) THEN
    IF EXISTS (SELECT 1 FROM civic_private.report_tombstones WHERE request_id=p_request_id AND owner_id=uid) THEN
      RAISE EXCEPTION 'Submission was deleted' USING ERRCODE='P0002';
    END IF;
    RAISE EXCEPTION 'Request cannot be reused for this submission' USING ERRCODE='23514';
  END IF;
  SELECT * INTO existing FROM public.reports WHERE id=p_request_id;
  IF FOUND THEN
    IF existing.reporter_id=uid AND
       (existing.title,existing.description,existing.category,existing.latitude,existing.longitude,existing.media_paths)
       IS NOT DISTINCT FROM
       (canonical_title,canonical_description,p_category,p_latitude,p_longitude,p_media_paths) THEN
      RETURN jsonb_build_object('id',existing.id,'reportCode',existing.report_code);
    END IF;
    -- Same rejection for someone else's UUID and a mismatched own payload.
    RAISE EXCEPTION 'Request cannot be reused for this submission' USING ERRCODE='23514';
  END IF;
  prefix := CASE p_category
    WHEN 'Municipal Corportaion' THEN 'MC'
    WHEN 'Police Department' THEN 'PD'
    WHEN 'Fire & Emergency Services' THEN 'FE'
    WHEN 'Electricity & Gas Department' THEN 'EG'
    WHEN 'Public Works Department (PWD)' THEN 'PW' END;
  IF canonical_title IS NULL OR char_length(canonical_title) NOT BETWEEN 5 AND 120
     OR canonical_description IS NULL OR char_length(canonical_description) NOT BETWEEN 20 AND 2000
     OR prefix IS NULL OR NOT civic_private.in_service_area(p_latitude,p_longitude)
     OR p_media_paths IS NULL OR cardinality(p_media_paths) NOT BETWEEN 1 AND 3 THEN
    RAISE EXCEPTION 'Invalid report submission' USING ERRCODE='23514';
  END IF;
  PERFORM civic_private.lock_owned_media('reports-images',p_media_paths,uid);
  INSERT INTO public.report_counters AS c(prefix,counter) VALUES (prefix,1)
  ON CONFLICT ON CONSTRAINT report_counters_pkey DO UPDATE SET counter=c.counter+1
  RETURNING c.counter INTO next_counter;
  code := prefix||lpad(next_counter::text,greatest(5,char_length(next_counter::text)),'0');
  INSERT INTO public.reports(id,reporter_id,title,description,category,latitude,longitude,media_paths,report_code)
  VALUES (p_request_id,uid,canonical_title,canonical_description,p_category,p_latitude,p_longitude,p_media_paths,code);
  RETURN jsonb_build_object('id',p_request_id,'reportCode',code);
END $$;
REVOKE ALL ON FUNCTION public.create_report(text,text,text,double precision,double precision,text[],uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.create_report(text,text,text,double precision,double precision,text[],uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_report_submission(p_request_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); result jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM civic_private.report_tombstones WHERE request_id=p_request_id AND owner_id=uid) THEN
    RETURN jsonb_build_object('id',p_request_id,'deleted',true,'images','[]'::jsonb);
  END IF;
  SELECT jsonb_build_object('id',r.id,'reportCode',r.report_code,'images',to_jsonb(r.media_paths))
  INTO result FROM public.reports r WHERE r.id=p_request_id AND r.reporter_id=uid;
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.get_report_submission(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_report_submission(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_report(p_report_id uuid) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); paths text[];
BEGIN
  IF p_report_id IS NULL THEN RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('civic-report:'||p_report_id::text,0));
  DELETE FROM public.reports WHERE id=p_report_id AND reporter_id=uid RETURNING media_paths INTO paths;
  IF FOUND THEN
    INSERT INTO civic_private.report_tombstones(request_id,owner_id) VALUES(p_report_id,uid)
    ON CONFLICT(request_id) DO NOTHING;
    INSERT INTO public.report_cleanup(owner_id,report_id,media_paths) VALUES(uid,p_report_id,paths)
    ON CONFLICT(report_id) DO NOTHING;
  ELSE
    SELECT media_paths INTO paths FROM public.report_cleanup WHERE report_id=p_report_id AND owner_id=uid;
    IF NOT FOUND THEN
      IF EXISTS (SELECT 1 FROM civic_private.report_tombstones WHERE request_id=p_report_id AND owner_id=uid) THEN
        RETURN '[]'::jsonb;
      END IF;
      RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501';
    END IF;
  END IF;
  RETURN to_jsonb(paths);
END $$;
REVOKE ALL ON FUNCTION public.delete_report(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.delete_report(uuid) TO authenticated;

-- Avatar changes do not replay stale name/contact fields from a client cache.
CREATE FUNCTION public.update_avatar(p_profile_picture text) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user();
BEGIN
  IF p_profile_picture IS NULL THEN RAISE EXCEPTION 'Avatar path required' USING ERRCODE='23514'; END IF;
  PERFORM 1 FROM public.profiles WHERE id=uid FOR UPDATE;
  IF p_profile_picture<>'' THEN
    PERFORM civic_private.lock_owned_media('profile-pictures',ARRAY[p_profile_picture],uid);
  END IF;
  UPDATE public.profiles SET profile_picture=p_profile_picture WHERE id=uid;
END $$;
REVOKE ALL ON FUNCTION public.update_avatar(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.update_avatar(text) TO authenticated;

CREATE OR REPLACE FUNCTION civic_private.in_service_area(p_lat double precision, p_lon double precision)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE
  lats constant double precision[] := ARRAY[33.6013,33.5765,33.4857,33.4701,33.6013];
  lons constant double precision[] := ARRAY[72.5843,72.6912,72.6903,72.5750,72.5843];
  dx double precision; dy double precision; px double precision; py double precision;
  cross_product double precision; dot_product double precision;
  inside boolean := false;
BEGIN
  -- PostgreSQL considers NaN greater than other floats; the range checks also
  -- reject NaN and infinities. Explicit NULL handling prevents CHECK bypass.
  IF p_lat IS NULL OR p_lon IS NULL OR NOT (p_lat BETWEEN -90 AND 90)
     OR NOT (p_lon BETWEEN -180 AND 180) THEN RETURN false; END IF;
  FOR i IN 1..4 LOOP
    dx := lons[i+1]-lons[i]; dy := lats[i+1]-lats[i];
    px := p_lon-lons[i]; py := p_lat-lats[i];
    cross_product := dx*py-dy*px; dot_product := px*dx+py*dy;
    -- Exact Dart algorithm, including its inclusive 1e-10 boundary tolerance.
    IF abs(cross_product)<=1e-10 AND dot_product>=0 AND dot_product<=dx*dx+dy*dy THEN RETURN true; END IF;
    IF (lats[i]>p_lat)<>(lats[i+1]>p_lat) THEN
      IF p_lon<dx*(p_lat-lats[i])/dy+lons[i] THEN inside := NOT inside; END IF;
    END IF;
  END LOOP;
  RETURN inside;
END $$;
REVOKE ALL ON FUNCTION civic_private.in_service_area(double precision,double precision) FROM PUBLIC, anon, authenticated;

COMMIT;
