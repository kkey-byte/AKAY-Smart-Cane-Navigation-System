'use strict';
// Never prints credentials, device identifiers or personal coordinates.
require('dotenv').config({quiet:true});
const {caneCoordinates}=require('../services/caneCoordinates');
(async()=>{
  let timer;
  try {
    const serial=process.argv[2];
    if(!serial || /[.#$\[\]/]/.test(serial)) throw new Error('Invalid serial');
    const snapshot=await Promise.race([
      require('../services/firebaseAdmin').database().ref(`Device_Location/${serial}`).get(),
      new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Timeout')),10000);}),
    ]);
    const raw=snapshot.val();
    console.log(JSON.stringify({recordExists:snapshot.exists(),
      latitudeType:typeof raw?.latitude,longitudeType:typeof raw?.longitude,
      validCoordinates:caneCoordinates(raw)!==null,hasCaptureTimestamp:raw?.timestamp!=null,
      coordinatesRedacted:true}));
  } catch(_) {
    console.error('Read-only cane location check unavailable. Verify backend configuration and connectivity.');
    process.exitCode=1;
  } finally {
    clearTimeout(timer);
    const {getApps,deleteApp}=require('firebase-admin/app');
    await Promise.all(getApps().map(app=>deleteApp(app)));
  }
})();
