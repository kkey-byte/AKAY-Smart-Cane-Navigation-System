-- REVIEW ONLY. Run after 001/002 with an operator role and approved table names.
-- Creates a NOLOGIN privilege group, never a password or login credential.
-- Does not revoke privileges from, alter or demote the current service account.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='akay_runtime') THEN
  CREATE ROLE akay_runtime NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
 ELSIF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='akay_runtime' AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls OR rolcanlogin)) THEN
  RAISE EXCEPTION 'Existing runtime role has unexpected capabilities; review manually';
 END IF;
 EXECUTE format('GRANT CONNECT ON DATABASE %I TO akay_runtime',current_database());
END $$;
GRANT USAGE ON SCHEMA public TO akay_runtime;
GRANT SELECT,INSERT ON __USERS_TABLE__ TO akay_runtime;
GRANT UPDATE(name,phone,profile_picture,updated_at) ON __USERS_TABLE__ TO akay_runtime;
GRANT SELECT,INSERT ON __PATIENT_TABLE__,navigationsessions TO akay_runtime;
GRANT UPDATE(age,gender,birthdate,medical_conditions,allergies,blood_type,emergency_contact,address,updated_at) ON __PATIENT_TABLE__ TO akay_runtime;
GRANT UPDATE(status,endtime,totaldistance,duration,averagespeed,updatedat) ON navigationsessions TO akay_runtime;
GRANT SELECT ON places TO akay_runtime;
GRANT SELECT,INSERT,UPDATE(redeemed_at,redeemed_by) ON akay_invitations TO akay_runtime;
GRANT SELECT,INSERT,UPDATE(status,invitation_id,requested_at,expires_at,consented_at,revoked_at) ON akay_connections TO akay_runtime;
GRANT SELECT,INSERT,UPDATE ON akay_rate_limits TO akay_runtime;
GRANT SELECT,UPDATE(owner_id,claim_hash) ON akay_devices TO akay_runtime;
GRANT SELECT,UPDATE(last_sequence) ON akay_device_credentials TO akay_runtime;
GRANT SELECT,INSERT,UPDATE(ended_at) ON akay_ownership_history,akay_assignments TO akay_runtime;
GRANT SELECT,INSERT,UPDATE(accepted_at) ON akay_transfers TO akay_runtime;
GRANT SELECT,INSERT ON akay_readings,akay_alerts TO akay_runtime;
GRANT INSERT ON akay_audit_events TO akay_runtime;
COMMIT;
