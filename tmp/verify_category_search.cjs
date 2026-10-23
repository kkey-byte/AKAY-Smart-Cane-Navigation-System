const pool=require('C:/Users/Asus/app_mobile/backend_patch/database/db');
const {searchDestinations,resolveSearchIntent}=require('C:/Users/Asus/app_mobile/backend_patch/services/searchService');
const original=global.fetch;global.fetch=async()=>({ok:true,json:async()=>({features:[]})});
(async()=>{
 try {
  const {rows}=await pool.query('SELECT category,latitude,longitude FROM places');
  const row=rows.find(row=>resolveSearchIntent(row.category).category);
  if(!row){console.log('No recognized saved category available for read-only verification');return;}
  const intent=resolveSearchIntent(row.category);
  const plural=intent.category.aliases.find(alias=>alias.endsWith('s')) || intent.text;
  const latitude=Number(row.latitude),longitude=Number(row.longitude);
  const counts=[];let ids;
  for(const query of [intent.text,`nearby ${plural}`,`${plural} near me`]) {
   const results=await searchDestinations({query,latitude,longitude});
   const current=results.filter(p=>p.source==='AKAY').map(p=>p.id).sort();
   if(ids && JSON.stringify(ids)!==JSON.stringify(current)) throw new Error('Inconsistent category matches');
   ids=current;counts.push(current.length);
  }
  console.log(JSON.stringify({savedCategoryCountsByPhrase:counts,equivalentMatches:true}));
 }catch(_){console.log('Read-only category search check failed');process.exitCode=1;}
 finally{global.fetch=original;await pool.end();}
})();
