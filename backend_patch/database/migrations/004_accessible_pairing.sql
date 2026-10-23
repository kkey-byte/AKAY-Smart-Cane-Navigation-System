-- Pairing-only installation. No authentication, patientprofiles or device changes.
-- __USERS_TABLE__ is supplied by the trusted migration runner.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE IF NOT EXISTS akay_invitations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 navigator_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 code_hash text NOT NULL UNIQUE,
 expires_at timestamptz NOT NULL,
 redeemed_by uuid REFERENCES __USERS_TABLE__(user_id),
 redeemed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS akay_connections (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 navigator_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 caregiver_id uuid NOT NULL REFERENCES __USERS_TABLE__(user_id),
 status text NOT NULL CHECK(status IN ('pending','active','rejected','revoked','expired')),
 invitation_id uuid NOT NULL REFERENCES akay_invitations(id),
 requested_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL,
 consented_at timestamptz,
 revoked_at timestamptz,
 UNIQUE(navigator_id,caregiver_id), CHECK(navigator_id<>caregiver_id)
);
CREATE INDEX IF NOT EXISTS akay_connections_caregiver ON akay_connections(caregiver_id);
CREATE TABLE IF NOT EXISTS akay_rate_limits (
 actor text NOT NULL, action text NOT NULL, bucket bigint NOT NULL,
 attempts integer NOT NULL, PRIMARY KEY(actor,action,bucket)
);
CREATE TABLE IF NOT EXISTS akay_audit_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_id uuid REFERENCES __USERS_TABLE__(user_id),
 action text NOT NULL, record_id uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
COMMIT;
