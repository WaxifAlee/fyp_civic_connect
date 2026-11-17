-- Civic Connect: private identity and transactional report data.
BEGIN;
CREATE SCHEMA civic_private;
REVOKE ALL ON SCHEMA civic_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA civic_private TO authenticated;
-- Supabase may grant new public objects to API roles by default. Each object
-- below receives explicit privileges; never depend on hosted default ACLs.

CREATE FUNCTION civic_private.in_service_area(p_lat double precision, p_lon double precision)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE
  lats constant double precision[] := ARRAY[33.6013,33.5765,33.4857,33.4701,33.6013];
  lons constant double precision[] := ARRAY[72.5843,72.6912,72.6903,72.5750,72.5843];
  dx double precision; dy double precision; px double precision; py double precision;
  cross_product double precision; dot_product double precision;
  inside boolean := false; i integer;
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

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL CHECK (char_length(full_name) BETWEEN 3 AND 100 AND full_name ~ '^[A-Za-z[:space:]]+$'),
  phone text NOT NULL UNIQUE CHECK (phone ~ '^\+923[0-9]{9}$'),
  cnic text NOT NULL UNIQUE CHECK (cnic ~ '^[0-9]{5}-[0-9]{7}-[0-9]$'),
  locations text NOT NULL CHECK (char_length(btrim(locations)) BETWEEN 3 AND 250),
  gender text NOT NULL CHECK (gender IN ('Male','Female','Other')),
  profile_picture text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.report_counters (
  prefix text PRIMARY KEY CHECK (prefix IN ('MC','PD','FE','EG','PW')),
  counter bigint NOT NULL CHECK (counter>0)
);
CREATE TABLE public.reports (
  id uuid PRIMARY KEY,
  reporter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 5 AND 120),
  description text NOT NULL CHECK (char_length(btrim(description)) BETWEEN 20 AND 2000),
  category text NOT NULL CHECK (category IN ('Municipal Corportaion','Police Department','Fire & Emergency Services','Electricity & Gas Department','Public Works Department (PWD)')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','inprogress','resolved','rejected')),
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  media_paths text[] NOT NULL CHECK (coalesce(array_ndims(media_paths)=1 AND array_lower(media_paths,1)=1 AND cardinality(media_paths) BETWEEN 1 AND 3 AND array_position(media_paths,NULL) IS NULL,false)),
  report_code text NOT NULL UNIQUE,
  support_count integer NOT NULL DEFAULT 0 CHECK (support_count>=0),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (civic_private.in_service_area(latitude,longitude))
);
CREATE TABLE public.report_supports (
  report_id uuid NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (report_id,user_id)
);
CREATE INDEX reports_feed_idx ON public.reports(created_at DESC,id DESC);
CREATE INDEX reports_owner_feed_idx ON public.reports(reporter_id,created_at DESC,id DESC);
CREATE INDEX report_supports_user_idx ON public.report_supports(user_id);
CREATE INDEX reports_media_idx ON public.reports USING gin(media_paths);
CREATE INDEX profiles_picture_idx ON public.profiles(profile_picture) WHERE profile_picture<>'';

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_supports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.profiles,public.reports,public.report_counters,public.report_supports FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.profiles TO authenticated;

CREATE FUNCTION civic_private.verified_owner(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p_id=auth.uid() AND EXISTS (
    SELECT 1 FROM auth.users u WHERE u.id=auth.uid() AND u.email_confirmed_at IS NOT NULL
  );
$$;
REVOKE ALL ON FUNCTION civic_private.verified_owner(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION civic_private.verified_owner(uuid) TO authenticated;
CREATE POLICY profiles_owner_read ON public.profiles FOR SELECT TO authenticated
USING (civic_private.verified_owner(id));

CREATE FUNCTION civic_private.require_verified_user() RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL OR NOT civic_private.verified_owner(uid)
     OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id=uid) THEN
    RAISE EXCEPTION 'Verified citizen session required' USING ERRCODE='42501';
  END IF;
  RETURN uid;
END $$;
REVOKE ALL ON FUNCTION civic_private.require_verified_user() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION civic_private.on_citizen_signup() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE m jsonb := NEW.raw_user_meta_data;
BEGIN
  -- Validate in the same transaction as Auth insertion. Roles/verification in
  -- user metadata are deliberately ignored. Table constraints validate syntax.
  IF m IS NULL OR jsonb_typeof(m)<>'object' OR EXISTS (
    SELECT 1 FROM unnest(ARRAY['full_name','phone','cnic','locations','gender']) AS f(key)
    WHERE jsonb_typeof(m->f.key) IS DISTINCT FROM 'string'
  ) THEN RAISE EXCEPTION 'Valid citizen registration metadata required' USING ERRCODE='23514'; END IF;
  INSERT INTO public.profiles(id,full_name,phone,cnic,locations,gender)
  VALUES (NEW.id,btrim(m->>'full_name'),btrim(m->>'phone'),btrim(m->>'cnic'),btrim(m->>'locations'),m->>'gender');
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION civic_private.on_citizen_signup() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER civic_citizen_signup AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION civic_private.on_citizen_signup();

CREATE FUNCTION civic_private.protect_profile_identity() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF (NEW.id,NEW.cnic,NEW.gender,NEW.created_at) IS DISTINCT FROM (OLD.id,OLD.cnic,OLD.gender,OLD.created_at) THEN
    RAISE EXCEPTION 'Citizen identity is immutable' USING ERRCODE='23514';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION civic_private.protect_profile_identity() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER civic_profile_identity BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION civic_private.protect_profile_identity();

CREATE FUNCTION civic_private.protect_report_identity() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF (NEW.id,NEW.reporter_id,NEW.report_code,NEW.created_at) IS DISTINCT FROM (OLD.id,OLD.reporter_id,OLD.report_code,OLD.created_at) THEN
    RAISE EXCEPTION 'Report identity is immutable' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION civic_private.protect_report_identity() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER civic_report_identity BEFORE UPDATE ON public.reports
FOR EACH ROW EXECUTE FUNCTION civic_private.protect_report_identity();
COMMIT;
