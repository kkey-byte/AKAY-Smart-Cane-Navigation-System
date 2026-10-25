'use strict';
const path=require('node:path');
require('dotenv').config({path:path.resolve(__dirname,'../../../app_mobile_backend/.env'),quiet:true});
const {Pool}=require('pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:String(process.env.DB_PASSWORD??''),connectionTimeoutMillis:5000});
pool.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name=ANY($1::text[])",[['pairings','akay_connections','akay_invitations','akay_rate_limits','akay_audit_events']])
  .then(async result=>{
    console.log(JSON.stringify({pairingTables:result.rows.map(row=>row.table_name)}));
    if(result.rows.some(row=>row.table_name==='pairings')) {
      console.log(JSON.stringify({columns:(await pool.query("SELECT column_name,data_type,is_nullable,column_default FROM information_schema.columns WHERE table_schema='public' AND table_name='pairings' ORDER BY ordinal_position")).rows}));
      console.log(JSON.stringify({constraints:(await pool.query("SELECT pg_get_constraintdef(k.oid) AS definition FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='pairings'")).rows}));
      console.log(JSON.stringify({counts:(await pool.query('SELECT count(*)::int AS records FROM pairings')).rows[0]}));
    }
  })
  .catch(()=>{console.error('Pairing schema inspection unavailable.');process.exitCode=1;})
  .finally(()=>pool.end());
