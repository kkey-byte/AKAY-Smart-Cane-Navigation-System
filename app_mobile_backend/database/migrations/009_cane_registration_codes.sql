-- Server-issued registration challenges. Never stores plaintext claim/code secrets.
BEGIN;
CREATE TABLE IF NOT EXISTS akay_cane_registration_codes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES akay_devices(id),
 navigator_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 code_hash text NOT NULL,
 claim_hash text NOT NULL,
 expires_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '5 minutes',
 consumed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS akay_cane_registration_pending
 ON akay_cane_registration_codes(navigator_id,device_id) WHERE consumed_at IS NULL;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='akay_runtime') THEN
  GRANT SELECT,INSERT,UPDATE(expires_at,consumed_at) ON akay_cane_registration_codes TO akay_runtime;
 END IF;
END $$;
COMMIT;
