'use strict';
// Prints the script unless --apply is explicitly supplied. Never runs on startup.
const fs=require('node:fs');
const path=require('node:path');
const sql=fs.readFileSync(path.join(__dirname,'../database/migrations/006_patient_health_status.sql'),'utf8');
if (!process.argv.includes('--apply')) { process.stdout.write(sql); }
else {
  const pool=require('../database/db');
  (async()=>{
    try { await pool.query(sql); console.log('patientmedication health-status migration applied.'); }
    catch (_) { console.error('Health migration failed and was rolled back. Inspect schema dependencies and privileges.'); process.exitCode=1; }
    finally { await pool.end(); }
  })();
}
