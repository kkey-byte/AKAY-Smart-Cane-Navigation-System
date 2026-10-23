'use strict';
// Read-only connectivity check. Never prints configuration or result rows.
const path=require('node:path');
require('dotenv').config({path:path.resolve(__dirname,'../../../app_mobile_backend/.env'),quiet:true});
const {Pool}=require('pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:String(process.env.DB_PASSWORD||''),connectionTimeoutMillis:5000});
(async()=>{
  try {await pool.query('SELECT 1');console.log('Configured PostgreSQL: read-only connectivity verified.');}
  catch (_) {console.log('Configured PostgreSQL: connectivity unavailable.');process.exitCode=1;}
  finally {await pool.end();}
})();
