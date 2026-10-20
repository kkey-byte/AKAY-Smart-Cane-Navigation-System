require("dotenv").config();
const pool = require("../database/db");

(async () => {
  try {
    const tables = await pool.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND lower(table_name) LIKE '%navigation%'
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

    // Also check Users column names for FK references
    const usersCols = await pool.query(`
      SELECT table_name, column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND lower(table_name) IN ('users')
        AND column_name IN ('user_id', 'firebase_uid', 'email')
    `);
    console.log("users cols:", usersCols.rows);
  } catch (e) {
    console.error("ERR", e.message);
  } finally {
    await pool.end();
  }
})();
