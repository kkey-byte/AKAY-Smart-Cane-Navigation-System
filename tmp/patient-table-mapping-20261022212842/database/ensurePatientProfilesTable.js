const pool = require("./db");
const { usersTable } = require("./ensureUsersTable");

/**
 * Resolves the physical PatientProfiles table name.
 * Prefer the user's original unquoted table (`patientprofiles`) when present.
 */
let patientTableSql = "patientprofiles";

function patientProfilesTable() {
  return patientTableSql;
}

async function ensurePatientProfilesTable() {
  if (process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP !== 'yes') {
    patientTableSql = await require('./schemaCatalog').resolveTable(pool,['PatientProfiles','patientprofiles'],process.env.AKAY_PATIENT_TABLE,
      ['profile_id','user_id','age','gender','birthdate','medical_conditions','allergies','blood_type','emergency_contact','address','created_at','updated_at'],['user_id']);
    return;
  }
  const users = usersTable();

  const existing = await pool.query(`
    SELECT c.relname AS name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname IN ('PatientProfiles', 'patientprofiles')
  `);

  const names = existing.rows.map((r) => r.name);

  if (names.length > 1) throw new Error("Ambiguous patient table; explicit schema review required.");
  // Prefer the original lowercase table the app / DB tools usually show.
  if (names.includes("patientprofiles")) {
    patientTableSql = "patientprofiles";
  } else if (names.includes("PatientProfiles")) {
    patientTableSql = '"PatientProfiles"';
  } else {
    await pool.query(`
      CREATE TABLE patientprofiles (
        profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL UNIQUE
          REFERENCES ${users}(user_id) ON DELETE CASCADE,
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
      )
    `);
    patientTableSql = "patientprofiles";
  }

  const table = patientTableSql;

  const alters = [
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS age INTEGER`,
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS gender VARCHAR(50)`,
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS birthdate DATE`,
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS medical_conditions TEXT`,
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS allergies TEXT`,
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS blood_type VARCHAR(16)`,
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS emergency_contact TEXT`,
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS address TEXT`,
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`,
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`,
  ];

  for (const sql of alters) {
    try {
      await pool.query(sql);
    } catch (_) {
      throw new Error("Patient schema update failed; review the approved schema.");
    }
  }

  try {
    await pool.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_patientprofiles_user_id_unique
       ON ${table} (user_id)`
    );
  } catch (_) {
    throw new Error("Patient profile uniqueness could not be established.");
  }

  console.log(`✅ PatientProfiles table ready (${table})`);
}

module.exports = ensurePatientProfilesTable;
module.exports.patientProfilesTable = patientProfilesTable;
