BEGIN;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES
 ('reports-images','reports-images',true,8388608,ARRAY['image/jpeg','image/png','image/webp']),
 ('profile-pictures','profile-pictures',true,5242880,ARRAY['image/jpeg','image/png','image/webp']);
-- Deliberately no ON CONFLICT overwrite: deploying into a reused project must
-- fail for review instead of silently replacing an existing bucket's settings.

CREATE FUNCTION civic_private.own_media_path(p_path text,p_uid uuid) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT coalesce(p_path ~ ('^'||p_uid::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$'),false);
$$;
REVOKE ALL ON FUNCTION civic_private.own_media_path(text,uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION civic_private.media_is_referenced(p_bucket text,p_path text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT CASE p_bucket
  WHEN 'reports-images' THEN EXISTS (SELECT 1 FROM public.reports WHERE media_paths @> ARRAY[p_path])
  WHEN 'profile-pictures' THEN EXISTS (SELECT 1 FROM public.profiles WHERE profile_picture=p_path)
  ELSE false END;
$$;
REVOKE ALL ON FUNCTION civic_private.media_is_referenced(text,text) FROM PUBLIC,anon,authenticated;

-- RLS cannot read the private tables directly. This narrowly scoped definer
-- performs reference checks without granting callers any table access.
CREATE FUNCTION civic_private.storage_access(p_bucket text,p_path text,p_owner text,p_delete boolean DEFAULT false)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT coalesce(p_bucket IN ('reports-images','profile-pictures')
   AND p_owner=auth.uid()::text AND civic_private.verified_owner(auth.uid())
   AND civic_private.own_media_path(p_path,auth.uid())
   AND (NOT p_delete OR NOT civic_private.media_is_referenced(p_bucket,p_path)),false);
$$;
REVOKE ALL ON FUNCTION civic_private.storage_access(text,text,text,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION civic_private.storage_access(text,text,text,boolean) TO authenticated;
CREATE POLICY civic_media_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (civic_private.storage_access(bucket_id,name,owner_id,false));
CREATE POLICY civic_media_select ON storage.objects FOR SELECT TO authenticated
USING (civic_private.storage_access(bucket_id,name,owner_id,false));
CREATE POLICY civic_media_delete ON storage.objects FOR DELETE TO authenticated
USING (civic_private.storage_access(bucket_id,name,owner_id,true));
-- No UPDATE policy: overwrite/upsert/move is intentionally unavailable.

CREATE FUNCTION civic_private.lock_owned_media(p_bucket text,p_paths text[],p_uid uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE path text;
BEGIN
  IF p_paths IS NULL OR array_ndims(p_paths) IS DISTINCT FROM 1
     OR array_lower(p_paths,1) IS DISTINCT FROM 1
     OR cardinality(p_paths)<1 OR array_position(p_paths,NULL) IS NOT NULL
     OR (SELECT count(DISTINCT x.value) FROM unnest(p_paths) AS x(value))<>cardinality(p_paths) THEN
    RAISE EXCEPTION 'Invalid photo paths' USING ERRCODE='23514';
  END IF;
  -- Deterministic order avoids deadlocks. SHARE prevents a concurrent deletion
  -- until the report/avatar reference commits. Two reports can share a photo.
  FOR path IN SELECT x.value FROM unnest(p_paths) AS x(value) ORDER BY x.value LOOP
    IF NOT civic_private.own_media_path(path,p_uid) THEN
      RAISE EXCEPTION 'Invalid photo paths' USING ERRCODE='23514';
    END IF;
    PERFORM 1 FROM storage.objects o WHERE o.bucket_id=p_bucket AND o.name=path AND o.owner_id=p_uid::text FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Invalid photo paths' USING ERRCODE='23514'; END IF;
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION civic_private.lock_owned_media(text,text[],uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION civic_private.protect_referenced_media() RETURNS trigger
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- DELETE owns a row lock before this trigger. A fresh query in this volatile
  -- function sees references committed while DELETE waited for an attaching RPC.
  IF OLD.bucket_id IN ('reports-images','profile-pictures')
     AND civic_private.media_is_referenced(OLD.bucket_id,OLD.name) THEN
    RAISE EXCEPTION 'Photo is still referenced' USING ERRCODE='23503';
  END IF;
  RETURN OLD;
END $$;
REVOKE ALL ON FUNCTION civic_private.protect_referenced_media() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER civic_protect_referenced_media BEFORE DELETE ON storage.objects
FOR EACH ROW EXECUTE FUNCTION civic_private.protect_referenced_media();
COMMIT;
