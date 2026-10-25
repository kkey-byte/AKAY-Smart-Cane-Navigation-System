'use strict';
// Diagnostics expose schema and aggregate counts only, never profile values.
const path=require('node:path');
require('dotenv').config({path:path.resolve(__dirname,'../../../app_mobile_backend/.env'),quiet:true});
const {Pool}=require('pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:String(process.env.DB_PASSWORD??''),connectionTimeoutMillis:5000});
(async()=>{
  let client;
  try {
    client=await pool.connect();await client.query('BEGIN READ ONLY');
    const names=(await client.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name=ANY($1::text[])",[['Users','users','patientprofiles']])).rows.map(row=>row.table_name);
    console.log(JSON.stringify({tables:names,configuredPatientTable:process.env.AKAY_PATIENT_TABLE||null}));
    for(const name of names.filter(name=>name==='patientprofiles')) {
      const counts=(await client.query(`SELECT count(*)::int AS profiles, count(DISTINCT user_id)::int AS owners FROM "${name}"`)).rows[0];
      const relations=(await client.query("SELECT pg_get_constraintdef(k.oid) AS definition FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname=$1 AND k.contype IN ('f','u')",[name])).rows;
      console.log(JSON.stringify({table:name,...counts,relations}));
    }
    await client.query('COMMIT');
  } catch (_) {try {await client?.query('ROLLBACK');}catch(_){}console.error('Profile storage inspection unavailable.');process.exitCode=1;}
  finally {client?.release();await pool.end();}
})();
