-- REVIEW ONLY until target-specific approval. Requires 001_pairing.sql.
-- No rows are deleted, reassigned, merged or repaired. Any violation aborts.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';

-- Cross-table attribution must hold even for an operator/import SQL write.
CREATE UNIQUE INDEX IF NOT EXISTS akay_credential_device_identity ON akay_device_credentials(id,device_id);
CREATE UNIQUE INDEX IF NOT EXISTS akay_reading_identity ON akay_readings(id,device_id,assignment_id,navigator_id);
CREATE UNIQUE INDEX IF NOT EXISTS akay_alert_event_unique ON akay_alerts(reading_id,kind);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='__USERS_TABLE__'::regclass AND conname='akay_account_role') THEN
  ALTER TABLE __USERS_TABLE__ ADD CONSTRAINT akay_account_role CHECK(role IN ('visually_impaired','caregiver')) NOT VALID;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='akay_readings'::regclass AND conname='akay_reading_credential_device') THEN
  ALTER TABLE akay_readings ADD CONSTRAINT akay_reading_credential_device FOREIGN KEY(credential_id,device_id) REFERENCES akay_device_credentials(id,device_id) NOT VALID;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='akay_alerts'::regclass AND conname='akay_alert_reading_identity') THEN
  ALTER TABLE akay_alerts ADD CONSTRAINT akay_alert_reading_identity FOREIGN KEY(reading_id,device_id,assignment_id,navigator_id) REFERENCES akay_readings(id,device_id,assignment_id,navigator_id) NOT VALID;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='akay_readings'::regclass AND conname='akay_sequence_nonnegative') THEN
  ALTER TABLE akay_readings ADD CONSTRAINT akay_sequence_nonnegative CHECK(sequence>=0) NOT VALID;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='akay_assignments'::regclass AND conname='akay_assignment_time_order') THEN
  ALTER TABLE akay_assignments ADD CONSTRAINT akay_assignment_time_order CHECK(ended_at IS NULL OR ended_at>=started_at) NOT VALID;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='akay_ownership_history'::regclass AND conname='akay_ownership_time_order') THEN
  ALTER TABLE akay_ownership_history ADD CONSTRAINT akay_ownership_time_order CHECK(ended_at IS NULL OR ended_at>=started_at) NOT VALID;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='akay_connections'::regclass AND conname='akay_consent_state') THEN
  ALTER TABLE akay_connections ADD CONSTRAINT akay_consent_state CHECK((status<>'active' OR consented_at IS NOT NULL) AND (status<>'revoked' OR revoked_at IS NOT NULL)) NOT VALID;
 END IF;
END $$;
ALTER TABLE akay_readings VALIDATE CONSTRAINT akay_reading_credential_device;
ALTER TABLE akay_readings VALIDATE CONSTRAINT akay_sequence_nonnegative;
ALTER TABLE akay_alerts VALIDATE CONSTRAINT akay_alert_reading_identity;
ALTER TABLE akay_assignments VALIDATE CONSTRAINT akay_assignment_time_order;
ALTER TABLE akay_ownership_history VALIDATE CONSTRAINT akay_ownership_time_order;
ALTER TABLE akay_connections VALIDATE CONSTRAINT akay_consent_state;
ALTER TABLE __USERS_TABLE__ VALIDATE CONSTRAINT akay_account_role;

-- Validate existing roles/custody before installing write guards. Abort with
-- a generic diagnostic, never a patient/account identifier.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM akay_connections c JOIN __USERS_TABLE__ n ON n.user_id=c.navigator_id JOIN __USERS_TABLE__ g ON g.user_id=c.caregiver_id WHERE n.role<>'visually_impaired' OR g.role<>'caregiver')
 OR EXISTS(SELECT 1 FROM akay_invitations i JOIN __USERS_TABLE__ u ON u.user_id=i.navigator_id WHERE u.role<>'visually_impaired')
 OR EXISTS(SELECT 1 FROM akay_devices d JOIN __USERS_TABLE__ u ON u.user_id=d.owner_id WHERE u.role<>'visually_impaired')
 OR EXISTS(SELECT 1 FROM akay_ownership_history h JOIN __USERS_TABLE__ u ON u.user_id=h.owner_id WHERE u.role<>'visually_impaired')
 OR EXISTS(SELECT 1 FROM akay_assignments a JOIN __USERS_TABLE__ u ON u.user_id=a.navigator_id JOIN akay_devices d ON d.id=a.device_id WHERE u.role<>'visually_impaired' OR a.assigned_by<>a.navigator_id OR (a.ended_at IS NULL AND a.navigator_id IS DISTINCT FROM d.owner_id))
 OR EXISTS(SELECT 1 FROM akay_transfers t JOIN __USERS_TABLE__ f ON f.user_id=t.from_id JOIN __USERS_TABLE__ n ON n.user_id=t.to_id WHERE f.role<>'visually_impaired' OR n.role<>'visually_impaired')
 THEN RAISE EXCEPTION 'Role/custody inconsistency; reconcile before integrity migration'; END IF;
END $$;
CREATE OR REPLACE FUNCTION akay_guard_roles() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE nav uuid; car uuid; BEGIN
 IF TG_TABLE_NAME='akay_connections' THEN nav=NEW.navigator_id; car=NEW.caregiver_id;
 ELSIF TG_TABLE_NAME='akay_invitations' THEN nav=NEW.navigator_id;
 ELSIF TG_TABLE_NAME='akay_devices' THEN nav=NEW.owner_id;
 ELSIF TG_TABLE_NAME='akay_ownership_history' THEN nav=NEW.owner_id;
 ELSIF TG_TABLE_NAME='akay_transfers' THEN
  nav=NEW.from_id;
  IF NOT EXISTS(SELECT 1 FROM __USERS_TABLE__ WHERE user_id=NEW.to_id AND role='visually_impaired') THEN RAISE EXCEPTION 'Navigator recipient required'; END IF;
 ELSIF TG_TABLE_NAME='akay_assignments' THEN
  nav=NEW.navigator_id;
  IF NEW.assigned_by<>nav OR NOT EXISTS(SELECT 1 FROM akay_devices WHERE id=NEW.device_id AND owner_id=nav) THEN RAISE EXCEPTION 'Assignment must belong to its navigator custodian'; END IF;
 END IF;
 IF nav IS NOT NULL AND NOT EXISTS(SELECT 1 FROM __USERS_TABLE__ WHERE user_id=nav AND role='visually_impaired') THEN RAISE EXCEPTION 'Navigator role required'; END IF;
 IF car IS NOT NULL AND NOT EXISTS(SELECT 1 FROM __USERS_TABLE__ WHERE user_id=car AND role='caregiver') THEN RAISE EXCEPTION 'Caregiver role required'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akay_connection_roles ON akay_connections;
CREATE TRIGGER akay_connection_roles BEFORE INSERT OR UPDATE OF navigator_id,caregiver_id ON akay_connections FOR EACH ROW EXECUTE FUNCTION akay_guard_roles();
DROP TRIGGER IF EXISTS akay_invitation_role ON akay_invitations;
CREATE TRIGGER akay_invitation_role BEFORE INSERT OR UPDATE OF navigator_id ON akay_invitations FOR EACH ROW EXECUTE FUNCTION akay_guard_roles();
DROP TRIGGER IF EXISTS akay_device_role ON akay_devices;
CREATE TRIGGER akay_device_role BEFORE INSERT OR UPDATE OF owner_id ON akay_devices FOR EACH ROW EXECUTE FUNCTION akay_guard_roles();
DROP TRIGGER IF EXISTS akay_ownership_role ON akay_ownership_history;
CREATE TRIGGER akay_ownership_role BEFORE INSERT OR UPDATE OF owner_id ON akay_ownership_history FOR EACH ROW EXECUTE FUNCTION akay_guard_roles();
DROP TRIGGER IF EXISTS akay_assignment_custody ON akay_assignments;
CREATE TRIGGER akay_assignment_custody BEFORE INSERT OR UPDATE OF navigator_id,device_id,assigned_by ON akay_assignments FOR EACH ROW EXECUTE FUNCTION akay_guard_roles();
DROP TRIGGER IF EXISTS akay_transfer_roles ON akay_transfers;
CREATE TRIGGER akay_transfer_roles BEFORE INSERT OR UPDATE OF from_id,to_id ON akay_transfers FOR EACH ROW EXECUTE FUNCTION akay_guard_roles();

-- An established identity/role cannot be moved onto someone else's history by
-- an ordinary profile update. Reconciliation requires a separately approved plan.
CREATE OR REPLACE FUNCTION akay_guard_account_identity() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 IF (OLD.firebase_uid IS NOT NULL AND NEW.firebase_uid IS DISTINCT FROM OLD.firebase_uid)
 OR (OLD.role IN ('caregiver','visually_impaired') AND NEW.role IS DISTINCT FROM OLD.role)
 THEN RAISE EXCEPTION 'Established identity and role require explicit reconciliation'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS akay_account_identity ON __USERS_TABLE__;
CREATE TRIGGER akay_account_identity BEFORE UPDATE OF firebase_uid,role ON __USERS_TABLE__ FOR EACH ROW EXECUTE FUNCTION akay_guard_account_identity();

-- New timestamps reflect the actual write time after locks, not BEGIN time.
ALTER TABLE akay_assignments ALTER COLUMN started_at SET DEFAULT clock_timestamp();
ALTER TABLE akay_ownership_history ALTER COLUMN started_at SET DEFAULT clock_timestamp();
ALTER TABLE akay_readings ALTER COLUMN received_at SET DEFAULT clock_timestamp();
ALTER TABLE akay_alerts ALTER COLUMN created_at SET DEFAULT clock_timestamp();
ALTER TABLE akay_transfers ALTER COLUMN created_at SET DEFAULT clock_timestamp();
CREATE INDEX IF NOT EXISTS akay_latest_sample ON akay_readings(assignment_id,sampled_at DESC,received_at DESC);
CREATE INDEX IF NOT EXISTS akay_navigator_alerts ON akay_alerts(navigator_id,created_at DESC);
CREATE INDEX IF NOT EXISTS akay_navigator_assignments ON akay_assignments(navigator_id,started_at DESC) WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS akay_caregiver_connections ON akay_connections(caregiver_id,requested_at DESC);
CREATE INDEX IF NOT EXISTS akay_owned_devices ON akay_devices(owner_id,created_at);
COMMIT;
