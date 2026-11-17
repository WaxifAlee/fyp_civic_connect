BEGIN;
-- The trigger also keeps counts correct if Auth administration removes a voter.
CREATE FUNCTION civic_private.maintain_support_count() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    UPDATE public.reports SET support_count=support_count+1 WHERE id=NEW.report_id;
    RETURN NEW;
  END IF;
  UPDATE public.reports SET support_count=support_count-1 WHERE id=OLD.report_id;
  RETURN OLD;
END $$;
REVOKE ALL ON FUNCTION civic_private.maintain_support_count() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER civic_support_count AFTER INSERT OR DELETE ON public.report_supports
FOR EACH ROW EXECUTE FUNCTION civic_private.maintain_support_count();

CREATE FUNCTION public.create_report(
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

CREATE FUNCTION public.get_report_submission(p_request_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); result jsonb;
BEGIN
  SELECT jsonb_build_object('id',r.id,'reportCode',r.report_code,'images',to_jsonb(r.media_paths))
  INTO result FROM public.reports r WHERE r.id=p_request_id AND r.reporter_id=uid;
  -- Null is deliberately indistinguishable from another owner's request, and
  -- must never be taken as proof that an in-flight create cannot still commit.
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.get_report_submission(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_report_submission(uuid) TO authenticated;

CREATE FUNCTION public.list_reports(p_mine boolean DEFAULT false,p_limit integer DEFAULT 200,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); result jsonb;
BEGIN
  IF p_mine IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 200 OR p_offset IS NULL OR p_offset<0 THEN
    RAISE EXCEPTION 'Invalid report pagination' USING ERRCODE='23514';
  END IF;
  SELECT coalesce(jsonb_agg(feed.item ORDER BY feed.created_at DESC,feed.id DESC),'[]'::jsonb) INTO result
  FROM (
    SELECT r.id,r.created_at,jsonb_build_object(
      'id',r.id,'title',r.title,'description',r.description,'category',r.category,'status',r.status,
      'location',r.latitude::text||', '||r.longitude::text,'images',to_jsonb(r.media_paths),
      'reporterId',r.reporter_id,'reporterName',p.full_name,'avatar',p.profile_picture,
      'timestamp',r.created_at,'reportCode',r.report_code,'upvotes',r.support_count,
      'upvotedBy',CASE WHEN EXISTS(SELECT 1 FROM public.report_supports s WHERE s.report_id=r.id AND s.user_id=uid)
        THEN jsonb_build_array(uid) ELSE '[]'::jsonb END
    ) AS item
    FROM public.reports r JOIN public.profiles p ON p.id=r.reporter_id
    WHERE NOT p_mine OR r.reporter_id=uid
    ORDER BY r.created_at DESC,r.id DESC LIMIT p_limit OFFSET p_offset
  ) feed;
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.list_reports(boolean,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.list_reports(boolean,integer,integer) TO authenticated;

CREATE FUNCTION public.toggle_report_support(p_report_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); total integer; supported boolean;
BEGIN
  -- Lock before deciding membership: two toggles serialize even when there is
  -- no support row yet. Delete-report competes for the same lock.
  PERFORM 1 FROM public.reports WHERE id=p_report_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501'; END IF;
  DELETE FROM public.report_supports WHERE report_id=p_report_id AND user_id=uid;
  supported := NOT FOUND;
  IF supported THEN INSERT INTO public.report_supports(report_id,user_id) VALUES (p_report_id,uid); END IF;
  SELECT support_count INTO total FROM public.reports WHERE id=p_report_id;
  RETURN jsonb_build_object('count',total,'voters',CASE WHEN supported THEN jsonb_build_array(uid) ELSE '[]'::jsonb END);
END $$;
REVOKE ALL ON FUNCTION public.toggle_report_support(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_report_support(uuid) TO authenticated;

CREATE FUNCTION public.delete_report(p_report_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); paths text[];
BEGIN
  DELETE FROM public.reports WHERE id=p_report_id AND reporter_id=uid RETURNING media_paths INTO paths;
  IF NOT FOUND THEN RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501'; END IF;
  RETURN to_jsonb(paths);
END $$;
REVOKE ALL ON FUNCTION public.delete_report(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.delete_report(uuid) TO authenticated;

CREATE FUNCTION public.update_profile(p_full_name text,p_phone text,p_locations text,p_profile_picture text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user();
BEGIN
  IF p_full_name IS NULL OR p_phone IS NULL OR p_locations IS NULL THEN
    RAISE EXCEPTION 'Profile fields required' USING ERRCODE='23514';
  END IF;
  -- Serialize avatar replacement/removal, then hold the media row lock until
  -- the profile points at it. NULL preserves, empty removes, path replaces.
  PERFORM 1 FROM public.profiles WHERE id=uid FOR UPDATE;
  IF p_profile_picture IS NOT NULL AND p_profile_picture<>'' THEN
    PERFORM civic_private.lock_owned_media('profile-pictures',ARRAY[p_profile_picture],uid);
  END IF;
  UPDATE public.profiles SET full_name=btrim(p_full_name),phone=btrim(p_phone),locations=btrim(p_locations),
    profile_picture=coalesce(p_profile_picture,profile_picture) WHERE id=uid;
END $$;
REVOKE ALL ON FUNCTION public.update_profile(text,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.update_profile(text,text,text,text) TO authenticated;
COMMIT;
