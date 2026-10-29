BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
LOCK TABLE public.patientmedication IN ACCESS EXCLUSIVE MODE;
-- Keep IDs, foreign keys and every existing row. Medication history has no
-- meaningful conversion to measurements, so archive it without inventing data.
ALTER TABLE public.patientmedication
  ADD COLUMN IF NOT EXISTS legacy_medication jsonb,
  ADD COLUMN IF NOT EXISTS health_status_record boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS height numeric(6,2) CHECK (height > 0 AND height < 1000),
  ADD COLUMN IF NOT EXISTS weight numeric(6,2) CHECK (weight > 0 AND weight < 1000),
  ADD COLUMN IF NOT EXISTS medical_conditions text,
  ADD COLUMN IF NOT EXISTS allergies text,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone varchar(40);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public'
    AND table_name='patientmedication' AND column_name='medicine_name') THEN
    UPDATE public.patientmedication SET legacy_medication =
      COALESCE(legacy_medication, '{}'::jsonb) || jsonb_build_object(
        'medicine_name', medicine_name, 'dosage', dosage, 'schedule', schedule);
  END IF;
END $$;
-- No CASCADE: unexpected external dependencies must abort the whole transaction.
ALTER TABLE public.patientmedication
  DROP COLUMN IF EXISTS medicine_name,
  DROP COLUMN IF EXISTS dosage,
  DROP COLUMN IF EXISTS schedule;
CREATE UNIQUE INDEX IF NOT EXISTS patientmedication_health_patient_unique
  ON public.patientmedication(patient_id) WHERE health_status_record;
-- Extend only this table's access for installations using the existing runtime
-- group. Archived medication content is deliberately excluded from these grants.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='akay_runtime') THEN
    GRANT SELECT (medication_id,patient_id,health_status_record,height,weight,medical_conditions,allergies,emergency_contact_phone),
      INSERT (medication_id,patient_id,health_status_record,height,weight,medical_conditions,allergies,emergency_contact_phone),
      UPDATE (height,weight,medical_conditions,allergies,emergency_contact_phone)
      ON public.patientmedication TO akay_runtime;
  END IF;
END $$;
COMMIT;
