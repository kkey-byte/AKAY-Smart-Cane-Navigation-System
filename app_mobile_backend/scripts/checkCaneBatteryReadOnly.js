'use strict';
// Reads the battery field only. Never reads coordinates or writes Firebase.
require('dotenv').config({quiet:true});
const {batteryPercent}=require('../services/caneBatteryService');
(async()=>{
  const serial=process.argv[2];let timer;
  try {
    if(!serial || /[.#$\[\]/]/.test(serial)) throw new Error('Invalid serial');
    const ref=require('../services/firebaseAdmin').database().ref(`Device_Location/${serial}/batteryLevel`);
    const snapshot=await Promise.race([
      ref.get(),
      new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Read timeout')),10000);}),
    ]);
    const percent=batteryPercent(snapshot.val());
    if(percent===null) {
      const raw=snapshot.val();
      const numeric=typeof raw==='number'?raw:typeof raw==='string'&&raw.trim()!==''?Number(raw):NaN;
      console.log(JSON.stringify({source:'Firebase Realtime Database',databaseHost:new URL(ref.toString()).hostname,
        recordExists:snapshot.exists(),valueType:raw===null?'null':typeof raw,
        numericValue:Number.isFinite(numeric)?numeric:null,
        status:'batteryLevel is missing or outside the supported numeric fraction/percentage ranges.'}));
    }
    else console.log(JSON.stringify({source:'Firebase Realtime Database',batteryPercent:percent,readAt:new Date().toISOString()}));
  } catch(_) {console.error('Firebase battery read unavailable. Check the serial, existing backend Firebase credentials, database URL and connectivity.');process.exitCode=1;}
  finally {
    clearTimeout(timer);
    const {getApps,deleteApp}=require('firebase-admin/app');
    await Promise.all(getApps().map(app=>deleteApp(app)));
  }
})();
