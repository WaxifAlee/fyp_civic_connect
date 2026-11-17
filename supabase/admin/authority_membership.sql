-- TRUSTED ADMINISTRATION ONLY. Run in Supabase SQL Editor or with db query.
-- First register and verify the staff account through the normal Auth flow.
-- Replace these three values. Registration metadata never grants staff access.
BEGIN;
DO $$
DECLARE
  staff_email text := 'REPLACE_WITH_VERIFIED_STAFF_EMAIL';
  staff_role text := 'department'; -- 'admin' or 'department'
  staff_department text := 'Municipal Corportaion'; -- NULL for admin
  staff_id uuid;
BEGIN
  SELECT id INTO STRICT staff_id FROM auth.users
  WHERE lower(email)=lower(staff_email) AND email_confirmed_at IS NOT NULL;
  INSERT INTO civic_private.authority_members(user_id,role,department,active)
  VALUES(staff_id,staff_role,staff_department,true)
  ON CONFLICT(user_id) DO UPDATE
    SET role=EXCLUDED.role,department=EXCLUDED.department,active=true;
END $$;
COMMIT;

-- To revoke access, use the verified account's exact UUID:
-- UPDATE civic_private.authority_members SET active=false WHERE user_id='UUID';
-- Do not grant authenticated/anon table access or expose administration keys.
