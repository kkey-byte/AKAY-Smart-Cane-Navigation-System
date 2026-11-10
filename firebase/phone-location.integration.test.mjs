import {test,after} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
// Fail closed: this test can never use application credentials or production.
assert.ok(['127.0.0.1:9009','localhost:9009'].includes(process.env.FIREBASE_DATABASE_EMULATOR_HOST),
  'Run through the demo Realtime Database emulator only.');
const require=createRequire(new URL('../app_mobile_backend/package.json',import.meta.url));
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getDatabase}=require('firebase-admin/database');
const {createPhoneLocationService}=require('./services/phoneLocation');
const {createMonitoringService}=require('./services/monitoringService');
const app=initializeApp({projectId:'demo-akay-breadcrumbs',
  databaseURL:'https://demo-akay-breadcrumbs.firebaseio.com'},'synthetic-live-monitoring');
const db=getDatabase(app),uid='synthetic-live-nav';
const pool={connect:async()=>({query:async sql=>({rows:sql.includes('FOR SHARE')?[{user_id:'sql-nav'}]:[]}),release(){}}),
  query:async()=>({rows:[]})};
const firebase={database:()=>db};
after(async()=>{
  await db.ref('phone_location/'+uid).remove();
  await db.ref('deleted_location_accounts/'+uid).remove();
  await deleteApp(app);
});
test('actual Admin SDK transaction publishes monotonic phone locations for caregiver monitoring and respects stop',async()=>{
  let now=Date.now();const actor={id:'sql-nav',uid,role:'visually_impaired'};
  const phone=createPhoneLocationService(pool,()=> 'users',firebase,{clock:()=>now});
  const sample={source:'phone_gps',latitude:10,longitude:20,timestamp:now-1000};
  await phone.publish(actor,sample);
  await phone.publish(actor,{...sample,latitude:11,timestamp:now-2000});
  const actual=(await db.ref('phone_location/'+uid).get()).val();
  assert.equal(actual.latitude,10);assert.equal(actual.timestamp,sample.timestamp);
  assert.equal(typeof actual.receivedAt,'number');
  const monitor=createMonitoringService(pool,firebase,{list:async()=>({trips:{}})},{clock:()=>now});
  const seen=await monitor.read({id:'sql-nav',uid});
  assert.equal(seen.location.latitude,10);assert.equal(seen.location.live,true);
  await phone.clear(actor,{stoppedAt:now});
  await phone.publish(actor,sample);
  assert.equal((await monitor.read({id:'sql-nav',uid})).location,null);
  now++;
  await phone.publish(actor,{...sample,timestamp:now,latitude:12});
  await phone.clear(actor,{stoppedAt:now-1});
  assert.equal((await monitor.read({id:'sql-nav',uid})).location.latitude,12);
});
