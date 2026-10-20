require("dotenv").config();
const pool = require("../database/db");

(async () => {
  try {
    // Force password to string (fixes SASL when env is undefined)
    if (pool.options) {
      pool.options.password = String(process.env.DB_PASSWORD ?? "");
    }

    const tables = await pool.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND lower(table_name) LIKE '%patient%'
      ORDER BY table_name
    `);
    console.log("tables:", tables.rows);

    for (const t of tables.rows) {
      const cols = await pool.query(
        `
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = $1
        ORDER BY ordinal_position
        `,
        [t.table_name]
      );
      console.log("---", t.table_name, "---");
      console.log(JSON.stringify(cols.rows, null, 2));
    }

    const cons = await pool.query(`
      SELECT rel.relname, c.conname, pg_get_constraintdef(c.oid) AS def
      FROM pg_constraint c
      JOIN pg_class rel ON rel.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = rel.relnamespace
      WHERE n.nspname = 'public'
        AND lower(rel.relname) LIKE '%patient%'
    `);
    console.log("constraints:", cons.rows);
  } catch (e) {
    console.error("ERR", e.message);
  } finally {
    await pool.end();
  }
})();
