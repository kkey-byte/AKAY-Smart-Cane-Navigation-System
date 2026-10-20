require("dotenv").config();
const pool = require("../database/db");

(async () => {
  try {
    const fks = await pool.query(`
      SELECT
        tc.constraint_name,
        kcu.column_name,
        ccu.table_name AS foreign_table,
        ccu.column_name AS foreign_column
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
      JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
      WHERE tc.table_name = 'navigationsessions'
        AND tc.constraint_type = 'FOREIGN KEY'
    `);
    console.log("fks:", fks.rows);

    const checks = await pool.query(`
      SELECT conname, pg_get_constraintdef(oid) AS def
      FROM pg_constraint
      WHERE conrelid = 'navigationsessions'::regclass
    `);
    console.log("constraints:", checks.rows);
  } catch (e) {
    console.error(e.message);
  } finally {
    await pool.end();
  }
})();
