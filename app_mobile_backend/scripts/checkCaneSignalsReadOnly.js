'use strict';
// Read signal fields only; do not start alert processing or write any records.
require('dotenv').config({quiet:true});
(async()=>{
  const serial=process.argv[2];let timer;
  try {
    if(!serial || /[.#$\[\]/]/.test(serial)) throw new Error('Invalid serial');
    const db=require('../services/firebaseAdmin').database();
    const snapshots=await Promise.race([
      Promise.all(['unsafe','fallAlert'].map(field=>db.ref(`Device_Location/${serial}/${field}`).get())),
      new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Timeout')),10000);}),
    ]);
    console.log(JSON.stringify({source:'Firebase Realtime Database',fields:snapshots.map((snapshot,index)=>{
      const raw=snapshot.val();return {field:['unsafe','fallAlert'][index],exists:snapshot.exists(),
        type:raw===null?'null':typeof raw,value:typeof raw==='boolean'?raw:null};
    }),readAt:new Date().toISOString()}));
  } catch(_) {console.error('Firebase signal read unavailable. Check the existing backend Firebase configuration and connectivity.');process.exitCode=1;}
  finally {clearTimeout(timer);const {getApps,deleteApp}=require('firebase-admin/app');await Promise.all(getApps().map(app=>deleteApp(app)));}
})();
