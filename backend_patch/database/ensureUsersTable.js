const pool = require("./db");

/**
 * Resolves the physical table name (`users` vs `"Users"`) and ensures
 * the Firebase-linked schema columns exist.
 */
let usersTableSql = "users";

function usersTable() {
  return usersTableSql;
}

async function ensureUsersTable() {
  // Normal server startup must not perform implicit migrations.
  if (process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP !== 'yes') {
    usersTableSql = await require('./schemaCatalog').resolveTable(pool,['Users','users'],process.env.AKAY_USERS_TABLE,
      ['user_id','firebase_uid','email','role','name','phone','profile_picture','created_at','updated_at'],['user_id','firebase_uid']);
    return;
  }
  await pool.query(`CREATE EXTENSION IF NOT EXISTS pgcrypto`);

  const existing = await pool.query(`
    SELECT c.relname AS name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname IN ('Users', 'users')
  `);

  const names = existing.rows.map((r) => r.name);
  if (names.length > 1) throw new Error("Ambiguous Users table; explicit schema review required.");
  if (names.includes("Users")) {
    usersTableSql = '"Users"';
  } else if (names.includes("users")) {
    usersTableSql = "users";
  } else {
    // Unquoted Users → public.users (matches deployed schema)
    await pool.query(`
      CREATE TABLE users (
        user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        firebase_uid VARCHAR(128) UNIQUE,
        name VARCHAR(100),
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255),
        role VARCHAR(50) NOT NULL CHECK (role IN ('visually_impaired', 'caregiver')),
        phone VARCHAR(20),
        profile_picture TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      )
    `);
    usersTableSql = "users";
  }

  const table = usersTableSql;

  await pool.query(
    `ALTER TABLE ${table} ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(128)`
  );

  try {
    await pool.query(
      `ALTER TABLE ${table} ALTER COLUMN password DROP NOT NULL`
    );
  } catch (_) {
    // Column may already be nullable
  }

  try {
    await pool.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_users_firebase_uid_unique
       ON ${table} (firebase_uid)`
    );
  } catch (_) {
    throw new Error("Firebase identity uniqueness could not be established.");
  }

  await pool.query(
    `CREATE INDEX IF NOT EXISTS idx_users_email ON ${table} (email)`
  );

  console.log(`✅ Users table ready (${table})`);
}

module.exports = ensureUsersTable;
module.exports.usersTable = usersTable;
