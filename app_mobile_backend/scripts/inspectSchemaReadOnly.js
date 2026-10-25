'use strict';
// Catalog metadata only: never selects account, profile, location or alert rows.
const {writeFileSync}=require('node:fs');
const path=require('node:path');
require('dotenv').config({path:path.resolve(__dirname,'../../../app_mobile_backend/.env'),quiet:true});
const {Pool}=require('pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:String(process.env.DB_PASSWORD||''),connectionTimeoutMillis:5000});
(async()=>{
  let db;
  try {
    db=await pool.connect();await db.query('BEGIN READ ONLY');
    const columns=(await db.query("SELECT table_name,column_name,data_type,is_nullable FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name,ordinal_position")).rows;
    const constraints=(await db.query("SELECT c.relname AS table_name,k.conname,k.contype,k.convalidated,pg_get_constraintdef(k.oid) AS definition FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' ORDER BY c.relname,k.conname")).rows;
    const indexes=(await db.query("SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname")).rows;
    const role=(await db.query('SELECT rolsuper,rolbypassrls,rolcreatedb,rolcreaterole FROM pg_roles WHERE rolname=current_user')).rows[0];
    const rowSecurity=(await db.query("SELECT c.relname AS table_name,c.relrowsecurity,c.relforcerowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r'")).rows;
    await db.query('COMMIT');
    writeFileSync(path.resolve(__dirname,'../../docs/backend_schema_metadata.json'),JSON.stringify({scope:'public catalog metadata only; no user rows',columns,constraints,indexes,serviceRoleCapabilities:role,rowSecurity},null,2));
    console.log(`Read-only schema inspection: ${new Set(columns.map(c=>c.table_name)).size} tables; metadata saved without user records.`);
  } catch (_) {try {await db?.query('ROLLBACK');}catch(_){} console.error('Read-only schema inspection unavailable.');process.exitCode=1;}
  finally {db?.release();await pool.end();}
})();
