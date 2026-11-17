-- Public discussions are projected by verified RPCs; API roles never read rows.
BEGIN;
CREATE TABLE civic_private.report_comments (
  -- Public comment identity also serves as the idempotency key, never a secret.
  id uuid PRIMARY KEY,
  report_id uuid NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body text,
  body_digest bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  CHECK ((deleted_at IS NULL AND body IS NOT NULL AND char_length(body) BETWEEN 1 AND 1000)
    OR (deleted_at IS NOT NULL AND body IS NULL))
);
CREATE INDEX report_comments_page_idx
  ON civic_private.report_comments(report_id,created_at DESC,id DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX report_comments_author_idx ON civic_private.report_comments(author_id);
ALTER TABLE civic_private.report_comments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE civic_private.report_comments FROM PUBLIC,anon,authenticated,service_role;

-- Matches Dart String.trim's Unicode whitespace, including NBSP and BOM.
CREATE FUNCTION civic_private.canonical_comment(p_body text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT btrim(p_body,E' \t\n\r\v\f'||U&'\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF');
$$;
REVOKE ALL ON FUNCTION civic_private.canonical_comment(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.list_report_comments(
  p_report_id uuid,p_limit integer DEFAULT 20,
  p_before_at timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user(); result jsonb;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.reports WHERE id=p_report_id) THEN
    RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501';
  END IF;
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50
    OR ((p_before_at IS NULL)<>(p_before_id IS NULL))
    OR (p_before_at IS NOT NULL AND NOT isfinite(p_before_at)) THEN
    RAISE EXCEPTION 'Invalid comments page' USING ERRCODE='23514';
  END IF;
  WITH page AS MATERIALIZED (
    SELECT c.id,c.body,c.author_id,c.created_at,p.full_name
    FROM civic_private.report_comments c JOIN public.profiles p ON p.id=c.author_id
    WHERE c.report_id=p_report_id AND c.deleted_at IS NULL
      AND (p_before_at IS NULL OR (c.created_at,c.id)<(p_before_at,p_before_id))
    ORDER BY c.created_at DESC,c.id DESC LIMIT p_limit+1
  ), visible AS (SELECT * FROM page ORDER BY created_at DESC,id DESC LIMIT p_limit)
  SELECT jsonb_build_object('comments',coalesce((SELECT jsonb_agg(jsonb_build_object(
    'id',id,'reportId',p_report_id,'body',body,'authorName',full_name,
    'createdAt',created_at,'isMine',author_id=uid) ORDER BY created_at DESC,id DESC) FROM visible),'[]'::jsonb),
    'hasMore',(SELECT count(*)>p_limit FROM page)) INTO result;
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.list_report_comments(uuid,integer,timestamptz,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.list_report_comments(uuid,integer,timestamptz,uuid) TO authenticated;

CREATE FUNCTION public.add_report_comment(p_report_id uuid,p_body text,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user();
  canonical text := civic_private.canonical_comment(p_body);
  existing civic_private.report_comments%ROWTYPE; display_name text;
BEGIN
  IF p_request_id IS NULL OR canonical IS NULL OR char_length(canonical) NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'Write between 1 and 1000 characters' USING ERRCODE='23514';
  END IF;
  -- Shared by add/remove; identical simultaneous retries become one comment.
  PERFORM pg_advisory_xact_lock(hashtextextended('civic-comment:'||p_request_id::text,0));
  PERFORM 1 FROM public.reports WHERE id=p_report_id FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501'; END IF;
  SELECT full_name INTO display_name FROM public.profiles WHERE id=uid FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Verified citizen session required' USING ERRCODE='42501'; END IF;
  SELECT * INTO existing FROM civic_private.report_comments WHERE id=p_request_id FOR UPDATE;
  IF FOUND THEN
    IF (existing.author_id,existing.report_id,existing.body_digest) IS DISTINCT FROM
       (uid,p_report_id,sha256(convert_to(canonical,'UTF8'))) THEN
      RAISE EXCEPTION 'Request cannot be reused' USING ERRCODE='23514';
    END IF;
    IF existing.deleted_at IS NOT NULL THEN
      -- Terminal business conflict, never a retryable transaction SQLSTATE.
      RAISE EXCEPTION 'Comment was removed' USING ERRCODE='PT409';
    END IF;
  ELSE
    INSERT INTO civic_private.report_comments(id,report_id,author_id,body,body_digest)
      VALUES(p_request_id,p_report_id,uid,canonical,sha256(convert_to(canonical,'UTF8')))
      RETURNING * INTO existing;
  END IF;
  RETURN jsonb_build_object('id',existing.id,'reportId',existing.report_id,
    'body',existing.body,'authorName',display_name,'createdAt',existing.created_at,'isMine',true);
END $$;
REVOKE ALL ON FUNCTION public.add_report_comment(uuid,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.add_report_comment(uuid,text,uuid) TO authenticated;

CREATE FUNCTION public.delete_report_comment(p_report_id uuid,p_comment_id uuid)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := civic_private.require_verified_user();
BEGIN
  IF p_comment_id IS NULL THEN RAISE EXCEPTION 'Comment unavailable' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('civic-comment:'||p_comment_id::text,0));
  PERFORM 1 FROM public.reports WHERE id=p_report_id FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Report unavailable' USING ERRCODE='42501'; END IF;
  -- Tombstones retain no public body and make deletion retries idempotent.
  UPDATE civic_private.report_comments SET body=NULL,deleted_at=coalesce(deleted_at,clock_timestamp())
    WHERE id=p_comment_id AND report_id=p_report_id AND author_id=uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comment unavailable' USING ERRCODE='42501'; END IF;
  RETURN jsonb_build_object('id',p_comment_id,'deleted',true);
END $$;
REVOKE ALL ON FUNCTION public.delete_report_comment(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.delete_report_comment(uuid,uuid) TO authenticated;
COMMIT;
