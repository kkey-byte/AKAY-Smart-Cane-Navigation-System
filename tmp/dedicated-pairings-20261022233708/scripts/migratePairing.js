'use strict';
// Review by default. Never invoked by server startup.
const {readFileSync}=require('node:fs');
const path=require('node:path');
const pool=require('../database/db');
(async()=>{
  try {
    // Resolve existing name without running ensureUsersTable's schema mutations.
    const result=await pool.query("SELECT relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND relname IN ('Users','users') AND relkind='r'");
    const names=result.rows.map(r=>r.relname);
    if(names.length!==1) throw new Error('Resolve ambiguous or missing Users table before migration.');
    const table=names[0]==='Users'?'"Users"':'users';
    const migration=process.argv.find(arg=>arg.startsWith('--migration='))?.slice('--migration='.length)||'001_pairing';
    if(!['001_pairing','002_integrity','003_runtime_role'].includes(migration)) throw new Error('Select a reviewed migration from the explicit allowlist.');
    let sql=readFileSync(path.join(__dirname,`../database/migrations/${migration}.sql`),'utf8').replaceAll('__USERS_TABLE__',table);
    if(migration==='003_runtime_role') {
      const patient=await require('../database/schemaCatalog').resolveTable(pool,['patientprofiles'],process.env.AKAY_PATIENT_TABLE,['user_id'],['user_id']);
      sql=sql.replaceAll('__PATIENT_TABLE__',patient);
    }
    if(!process.argv.includes('--apply')) {process.stdout.write(sql);return;}
    if(process.env.AKAY_MIGRATION_APPROVED!=='yes') throw new Error('Review migration and set AKAY_MIGRATION_APPROVED=yes for the approved target.');
    await pool.query(sql);
    console.log('Selected reviewed migration applied. Legacy records still require reconciliation.');
  } catch(error){console.error(error.message);process.exitCode=1;}
  finally{await pool.end();}
})();
