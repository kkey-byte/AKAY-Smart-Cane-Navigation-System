'use strict';
const {test,before,after,beforeEach}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const {Pool}=require('pg');
const {createPostgresRecordStore}=require('../services/postgresRecordStore');
const {createTripStore}=require('../services/tripStore');
const {createFirestoreHistoryImport}=require('../services/firestoreHistoryImport');
const {createLegacyStorageMigration}=require('../services/legacyStorageMigration');
// Disposable localhost test cluster only. Never loads application .env.
const config={host:'127.0.0.1',port:55449,database:'postgres',user:'akay_test',password:'',max:12};
const schema=`akay_history_test_${process.pid}_${Date.now()}`;
const admin=new Pool(config);
let pool,storage,trips;
const now=Date.UTC(2026,10,11);
const p=sequence=>({sequence,latitude:10+sequence/1000,longitude:20,sampledAt:now-10000+sequence*1000,accuracyMeters:5});
const firebase={firestore:()=>{throw new Error('Runtime must never access Firestore.');},
  database:()=>({ref:()=>({remove:async()=>{},set:async()=>{}})})};
before(async()=>{
  assert.match(schema,/^akay_history_test_[0-9_]+$/);
  await admin.query(`CREATE SCHEMA ${schema}`);
  pool=new Pool({...config,options:`-c search_path=${schema},public`});
  await pool.query(readFileSync(require.resolve('../database/migrations/007_postgres_history.sql'),'utf8'));
  storage=createPostgresRecordStore(pool);trips=createTripStore(firebase,{clock:()=>now,recordStore:storage});
});
beforeEach(async()=>{await pool.query('TRUNCATE akay_persistent_records');});
after(async()=>{await pool?.end();await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.end();});
async function phone(uid='nav',id='trip') {
  const body={name:'Synthetic walk',startedAt:now-10000,points:[p(0),p(1)]};
  await trips.phoneBatch(uid,id,body);return body;
}
test('real SQL batches and finalization preserve captures, retries and immutable completed trips',async()=>{
  const body=await phone();
  await trips.finalizePhone('nav','trip',{pointCount:2,status:'completed',endedAt:now});
  await trips.phoneBatch('nav','trip',body);
  assert.equal((await trips.detail('nav','trip')).points['00000001'].time,p(1).sampledAt);
  assert.equal((await pool.query('SELECT count(*) FROM akay_persistent_records')).rows[0].count,'3');
  await assert.rejects(trips.phoneBatch('nav','trip',{...body,points:[{...p(0),latitude:99}]}));
  assert.equal((await trips.detail('nav','trip')).pointCount,2);
});
test('concurrent retries serialize; failed transaction rolls back the entire batch',async()=>{
  await Promise.all(Array.from({length:6},()=>phone()));
  assert.equal(Object.keys((await trips.detail('nav','trip')).points).length,2);
  await assert.rejects(trips.phoneBatch('nav','trip',{name:'Synthetic walk',startedAt:now-10000,
    points:[p(2),{...p(0),longitude:22}]}));
  assert.equal(Object.keys((await trips.detail('nav','trip')).points).length,2);
  await assert.rejects(trips.finalizePhone('nav','trip',{pointCount:3,status:'completed',endedAt:now}));
});
test('keyset pagination, physical-source filters and retention use PostgreSQL indexes',async()=>{
  await phone('nav','a');await phone('nav','b');
  const first=await trips.list('nav',{limit:1});assert.deepEqual(Object.keys(first.trips),['b']);
  const second=await trips.list('nav',{limit:1,cursor:first.nextCursor});assert.deepEqual(Object.keys(second.trips),['a']);
  const cane=await trips.cane('nav','device','assignment',{...p(0),sessionId:'session',event:'start'});
  await trips.cane('nav','device','assignment',{...p(1),sessionId:'session',event:'end'});
  const page=await trips.list('nav',{sourceType:'cane_gps',deviceId:'device',assignmentId:'assignment'});
  assert.deepEqual(Object.keys(page.trips),[cane.tripId]);
  const later=createTripStore(firebase,{clock:()=>now+3*86400000,recordStore:storage});
  assert.equal((await later.retain(1)).deleted,1);
  assert.equal(await trips.detail('nav',cane.tripId),null);
  assert.ok(await trips.detail('nav','a'));
});
test('deletion tombstones block resurrection without touching adjacent account prefixes',async()=>{
  await phone();await phone('nav-other');
  await trips.removeAccount('nav');
  await assert.rejects(phone(),e=>e.code==='history_deleted');
  assert.ok(await trips.detail('nav-other','trip'));
  assert.equal(await trips.detail('nav','trip'),null);
});
test('legacy metadata and Firestore captures import into SQL without runtime Firestore access',async()=>{
  const migration=createLegacyStorageMigration(firebase,trips,{recordStore:storage});
  const raw={caregiver:{name:'Synthetic caregiver'}};
  await migration.metadata('breadcrumb_shares','nav',raw,{apply:true});
  assert.deepEqual((await storage.collection('legacy_rtdb').doc('breadcrumb_shares').collection('records').doc('nav').get()).data().payload,raw);
  const importer=createFirestoreHistoryImport(firebase,storage,{clock:()=>now});
  const summary={ownerId:'nav',name:'Imported',sourceType:'phone_gps',startedAt:now-10000,endedAt:now,status:'completed',pointCount:2};
  await importer.trip('nav','imported',summary,[p(0),p(1)]);
  assert.equal(await trips.detail('nav','imported'),null);
  await importer.trip('nav','imported',summary,[p(0),p(1)],{apply:true});
  await importer.trip('nav','imported',summary,[p(0),p(1)],{apply:true});
  assert.equal((await trips.detail('nav','imported')).points['00000001'].latitude,p(1).latitude);
  await assert.rejects(importer.trip('nav','imported',{...summary,name:'Conflict'},[p(0),p(1)],{apply:true}));
  await assert.rejects(importer.trip('other','imported',summary,[p(0),p(1)],{apply:true}));
});
test('live signal worker projects actual SQL readings and alert resolutions without copying history',async()=>{
  await pool.query(`CREATE TABLE users(user_id text PRIMARY KEY,firebase_uid text);
    CREATE TABLE akay_devices(id text PRIMARY KEY,owner_id text);
    CREATE TABLE akay_assignments(id text PRIMARY KEY,navigator_id text,device_id text,ended_at timestamptz);
    CREATE TABLE akay_readings(id text PRIMARY KEY,assignment_id text,sampled_at timestamptz,sequence bigint,battery int,status text);
    CREATE TABLE akay_alerts(id text PRIMARY KEY,navigator_id text,kind text,created_at timestamptz,resolved_at timestamptz);
    INSERT INTO users VALUES('nav-db','nav');INSERT INTO akay_devices VALUES('device','nav-db');
    INSERT INTO akay_assignments VALUES('assignment','nav-db','device',null);
    INSERT INTO akay_readings VALUES('reading','assignment',now(),1,70,'moving');
    INSERT INTO akay_alerts VALUES('alert','nav-db','sos',now(),null);`);
  const values=new Map(),liveFirebase={database:()=>({ref:path=>({get:async()=>({val:()=>null}),transaction:async fn=>{
    const value=fn(values.get(path)??null);if(value!==undefined) values.set(path,value);
  }})})};
  const worker=require('../services/liveCaneSignals').createLiveCaneSignals(pool,()=> 'users',liveFirebase);
  assert.equal((await worker.sync()).failed,0);
  assert.equal(values.get('cane_status/nav/assignment').battery,70);
  assert.equal(values.get('urgent_signals/nav').active,true);
  await pool.query("UPDATE akay_alerts SET resolved_at=clock_timestamp() WHERE id='alert'");
  await worker.sync();assert.equal(values.get('urgent_signals/nav').active,false);
  assert.equal(values.size,2);
});
