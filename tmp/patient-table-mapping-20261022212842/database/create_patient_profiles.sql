-- PatientProfiles ↔ Users (1:1)
-- Prefer lowercase `patientprofiles` (unquoted CREATE TABLE PatientProfiles).
-- ensurePatientProfilesTable.js applies this on boot.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS patientprofiles (
  profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE
    REFERENCES "Users"(user_id) ON DELETE CASCADE,
  age INTEGER CHECK (age >= 0),
  gender VARCHAR(50),
  birthdate DATE,
  medical_conditions TEXT,
  allergies TEXT,
  blood_type VARCHAR(16),
  emergency_contact TEXT,
  address TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_patient_profiles_user_id
  ON patientprofiles(user_id);
