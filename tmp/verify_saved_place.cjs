// Read-only verification against configured PostgreSQL; external calls are stubbed.
require('C:/Users/Asus/app_mobile/backend_patch/node_modules/dotenv').config({quiet:true});
const pool=require('C:/Users/Asus/app_mobile/backend_patch/database/db');
const {searchDestinations}=require('C:/Users/Asus/app_mobile/backend_patch/services/searchService');
const original=global.fetch;
global.fetch=async()=>({ok:true,json:async()=>({features:[]})});
(async()=>{
 try {
  const {rows}=await pool.query('SELECT place_id::text AS id,place_name,latitude,longitude FROM places WHERE latitude IS NOT NULL AND longitude IS NOT NULL LIMIT 1');
  if(!rows.length){console.log('No database place available');return;}
  const row=rows[0];
  const found=await searchDestinations({query:row.place_name,latitude:Number(row.latitude),longitude:Number(row.longitude)});
  console.log(JSON.stringify({savedPlaceQuerySucceeded:true,storedCoordinatesPreserved:found.some(p=>p.id===`akay_${row.id}` && p.latitude===Number(row.latitude) && p.longitude===Number(row.longitude))}));
 }catch(e){console.log(JSON.stringify({savedPlaceQuerySucceeded:false,error:e.message==='Place database unavailable.'?'database-query-failed':'search-failed'}));process.exitCode=1;}
 finally{global.fetch=original;await pool.end();}
})();
