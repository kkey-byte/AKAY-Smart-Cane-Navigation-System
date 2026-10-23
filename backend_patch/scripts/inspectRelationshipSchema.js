'use strict';
require('dotenv').config({quiet:true});
const {Pool}=require('pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:String(process.env.DB_PASSWORD??''),connectionTimeoutMillis:5000});
(async()=>{try {
  const columns=await pool.query("SELECT table_name,column_name,data_type,is_nullable FROM information_schema.columns WHERE table_schema='public' AND (lower(table_name) IN ('users','navigationsessions','smartcanedevices','devices','caregiverpatients','caregivernavigators','caregiver_navigator','pairings') OR lower(table_name) LIKE '%device%' OR lower(table_name) LIKE '%caregiver%' OR lower(table_name) LIKE '%cane%') ORDER BY table_name,ordinal_position");
  const constraints=await pool.query("SELECT c.relname AS table_name,conname,pg_get_constraintdef(k.oid) AS definition FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND (lower(c.relname) IN ('users','navigationsessions') OR lower(c.relname) LIKE '%device%' OR lower(c.relname) LIKE '%caregiver%' OR lower(c.relname) LIKE '%cane%' OR lower(c.relname)='pairings') ORDER BY c.relname,conname");
  console.log(JSON.stringify({columns:columns.rows,constraints:constraints.rows},null,2));
} catch(_){console.error('Read-only schema inspection unavailable. No data was changed.');process.exitCode=1;} finally{await pool.end();}})();
