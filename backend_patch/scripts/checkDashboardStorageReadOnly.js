'use strict';
const path=require('node:path');
require('dotenv').config({path:path.resolve(__dirname,'../../../app_mobile_backend/.env'),quiet:true});
const {Pool}=require('pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:String(process.env.DB_PASSWORD??''),connectionTimeoutMillis:5000});
(async()=>{
  try {
    await pool.query(`EXPLAIN SELECT sessionid,destinationlatitude,destinationlongitude,destinationaddress,
      status,starttime,endtime,updatedat FROM navigationsessions WHERE user_id=$1
      ORDER BY starttime DESC NULLS LAST,updatedat DESC NULLS LAST LIMIT 1`,['00000000-0000-0000-0000-000000000000']);
    console.log('Dashboard navigation query validates against the configured schema. No user rows read.');
  } catch(_) {console.error('Dashboard schema verification unavailable.');process.exitCode=1;}
  finally{await pool.end();}
})();
