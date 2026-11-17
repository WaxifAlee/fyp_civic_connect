-- Plan-review amendments; append-only so the first deployment of 001..003 can
-- safely receive the concurrency, durable cleanup, and international-name fixes.
BEGIN;
ALTER TABLE public.profiles DROP CONSTRAINT profiles_full_name_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_full_name_check
  CHECK (char_length(btrim(full_name)) BETWEEN 3 AND 100);

CREATE FUNCTION civic_private.lock_media_object(p_bucket text,p_path text) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('civic-media:'||p_bucket||'/'||p_path,0));
END $$;
REVOKE ALL ON FUNCTION civic_private.lock_media_object(text,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION civic_private.media_is_referenced(p_bucket text,p_path text) RETURNS boolean
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
 SELECT CASE p_bucket
  WHEN 'reports-images' THEN EXISTS (SELECT 1 FROM public.reports WHERE media_paths @> ARRAY[p_path])
  WHEN 'profile-pictures' THEN EXISTS (SELECT 1 FROM public.profiles WHERE profile_picture=p_path)
  ELSE false END;
$$;
REVOKE ALL ON FUNCTION civic_private.media_is_referenced(text,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION civic_private.storage_access(p_bucket text,p_path text,p_owner text,p_delete boolean DEFAULT false)
RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT coalesce(p_bucket IN ('reports-images','profile-pictures')
      AND p_owner=auth.uid()::text AND civic_private.verified_owner(auth.uid())
      AND civic_private.own_media_path(p_path,auth.uid()),false) THEN RETURN false; END IF;
  IF p_delete THEN
    -- Same lock as attachment, before any reference check. A volatile query
    -- gets a fresh snapshot after waiting for another transaction to commit.
    PERFORM civic_private.lock_media_object(p_bucket,p_path);
    RETURN NOT civic_private.media_is_referenced(p_bucket,p_path);
  END IF;
  RETURN true;
END $$;
REVOKE ALL ON FUNCTION civic_private.storage_access(text,text,text,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION civic_private.storage_access(text,text,text,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION civic_private.lock_owned_media(p_bucket text,p_paths text[],p_uid uuid) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE path text;
BEGIN
  IF p_paths IS NULL OR array_ndims(p_paths) IS DISTINCT FROM 1
     OR array_lower(p_paths,1) IS DISTINCT FROM 1 OR cardinality(p_paths)<1
     OR array_position(p_paths,NULL) IS NOT NULL
     OR (SELECT count(DISTINCT x.value) FROM unnest(p_paths) AS x(value))<>cardinality(p_paths) THEN
    RAISE EXCEPTION 'Invalid photo paths' USING ERRCODE='23514';
  END IF;
  FOR path IN SELECT x.value FROM unnest(p_paths) AS x(value) ORDER BY x.value COLLATE "C" LOOP
    IF NOT civic_private.own_media_path(path,p_uid) THEN
      RAISE EXCEPTION 'Invalid photo paths' USING ERRCODE='23514';
    END IF;
    PERFORM civic_private.lock_media_object(p_bucket,path);
  END LOOP;
  -- All object locks are held BEFORE existence checks and reference writes.
  -- No tuple lock is needed: admin deletion also enters the trigger below,
  -- avoiding an advisory-lock/tuple-lock inversion with that privileged path.
  FOR path IN SELECT x.value FROM unnest(p_paths) AS x(value) ORDER BY x.value COLLATE "C" LOOP
    PERFORM 1 FROM storage.objects o WHERE o.bucket_id=p_bucket AND o.name=path AND o.owner_id=p_uid::text;
    IF NOT FOUND THEN RAISE EXCEPTION 'Invalid photo paths' USING ERRCODE='23514'; END IF;
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION civic_private.lock_owned_media(text,text[],uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION civic_private.protect_referenced_media() RETURNS trigger
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF OLD.bucket_id IN ('reports-images','profile-pictures') THEN
    PERFORM civic_private.lock_media_object(OLD.bucket_id,OLD.name);
    IF civic_private.media_is_referenced(OLD.bucket_id,OLD.name) THEN
      RAISE EXCEPTION 'Photo is still referenced' USING ERRCODE='23503';
    END IF;
  END IF;
  RETURN OLD;
END $$;
REVOKE ALL ON FUNCTION civic_private.protect_referenced_media() FROM PUBLIC,anon,authenticated;

CREATE TABLE public.report_cleanup (
  owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  report_id uuid PRIMARY KEY,
  media_paths text[] NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX report_cleanup_owner_idx ON public.report_cleanup(owner_id,created_at,report_id);
ALTER TABLE public.report_cleanup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.report_cleanup FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.delete_report(p_report_id uuid) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); paths text[];
BEGIN
  IF p_report_id IS NULL THEN RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501'; END IF;
  -- Also serializes create/retry/delete for this request UUID.
  PERFORM pg_advisory_xact_lock(hashtextextended('civic-report:'||p_report_id::text,0));
  DELETE FROM public.reports WHERE id=p_report_id AND reporter_id=uid RETURNING media_paths INTO paths;
  IF FOUND THEN
    INSERT INTO public.report_cleanup(owner_id,report_id,media_paths) VALUES (uid,p_report_id,paths);
  ELSE
    SELECT media_paths INTO paths FROM public.report_cleanup WHERE report_id=p_report_id AND owner_id=uid;
    IF NOT FOUND THEN RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501'; END IF;
  END IF;
  RETURN to_jsonb(paths);
END $$;
REVOKE ALL ON FUNCTION public.delete_report(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.delete_report(uuid) TO authenticated;

CREATE FUNCTION public.list_report_cleanup() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); result jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(jsonb_build_object('reportId',report_id,'paths',to_jsonb(media_paths))
    ORDER BY created_at,report_id),'[]'::jsonb) INTO result
  FROM public.report_cleanup WHERE owner_id=uid;
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.list_report_cleanup() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.list_report_cleanup() TO authenticated;

CREATE FUNCTION public.complete_report_cleanup(p_report_id uuid) RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); paths text[]; path text;
BEGIN
  SELECT media_paths INTO paths FROM public.report_cleanup WHERE report_id=p_report_id AND owner_id=uid FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  FOR path IN SELECT x.value FROM unnest(paths) AS x(value) ORDER BY x.value COLLATE "C" LOOP
    PERFORM civic_private.lock_media_object('reports-images',path);
  END LOOP;
  IF EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='reports-images' AND name=ANY(paths)) THEN RETURN false; END IF;
  DELETE FROM public.report_cleanup WHERE report_id=p_report_id AND owner_id=uid;
  RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.complete_report_cleanup(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.complete_report_cleanup(uuid) TO authenticated;
COMMIT;
