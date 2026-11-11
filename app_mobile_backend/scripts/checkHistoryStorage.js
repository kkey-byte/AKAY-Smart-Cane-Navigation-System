'use strict';
// Read-only diagnosis. Never prints hosts, passwords, account IDs or GPS data.
const pool=require('../database/db');
const {importDiagnostic}=require('../services/importDiagnostics');
async function main() {
  const result=await pool.query(`SELECT current_database() AS database,current_schema() AS schema,
    to_regclass('akay_persistent_records')::text AS history_table`);
  const target=result.rows[0];
  console.log({database:target.database,schema:target.schema,historyTableAvailable:target.history_table!=null});
  if(!target.history_table) {
    console.error('History table is missing from this backend connection. Confirm the intended database and migration 007.');
    process.exitCode=1;return;
  }
  const counts=await pool.query('SELECT collection_name,count(*)::int AS record_count FROM akay_persistent_records GROUP BY collection_name');
  console.log({records:counts.rows});
  console.log('Database access is ready. This does not confirm that the app is using this backend or providing a valid GPS fix.');
}
main().catch(error=>{console.error('Storage check failed; no records were changed.');console.error(importDiagnostic(error));process.exitCode=1;})
  .finally(()=>pool.end());
