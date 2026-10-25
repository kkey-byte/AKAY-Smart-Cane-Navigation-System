'use strict';
function corsOptions(env=process.env) {
  const allowed=(env.CORS_ALLOWED_ORIGINS||'').split(',').map(s=>s.trim()).filter(Boolean);
  return {origin:(origin,done)=> {
    let local=false;
    if(origin && env.NODE_ENV!=='production') {
      try {const url=new URL(origin);local=['http:','https:'].includes(url.protocol) && ['localhost','127.0.0.1','[::1]'].includes(url.hostname) && !url.username && !url.password;} catch(_){}
    }
    done(null,!origin || allowed.includes(origin) || local);
  }};
}
// Account synchronization does not depend on optional health/search schemas.
// A failed optional check gates its own routes, never selects a patient table.
async function initializeStorage({accounts,profiles,places}) {
  await accounts();
  const result={profileReady:false,searchReady:false,issues:[]};
  for(const [check,key] of [[profiles,'profileReady'],[places,'searchReady']]) {
    try {await check();result[key]=true;} catch(_) {result.issues.push(key);}
  }
  return result;
}
function storageGuard(ready,feature) {
  return (_req,res,next)=> ready() ? next() : res.status(503).json({code:'storage_not_ready',message:`${feature} storage is unavailable. Ask the backend operator to review its schema configuration.`});
}
module.exports={corsOptions,initializeStorage,storageGuard};
