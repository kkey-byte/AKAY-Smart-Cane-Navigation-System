BEGIN;
CREATE TABLE IF NOT EXISTS akay_cane_registration_authorizations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL UNIQUE REFERENCES akay_devices(id),
 navigator_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 expires_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '24 hours',
 consumed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE akay_cane_registration_codes ADD COLUMN IF NOT EXISTS authorization_id uuid
 REFERENCES akay_cane_registration_authorizations(id);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='akay_runtime') THEN
  GRANT SELECT,UPDATE(consumed_at) ON akay_cane_registration_authorizations TO akay_runtime;
 END IF;
END $$;
COMMIT;
