import {test,before,after} from 'node:test';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
assert.ok(['127.0.0.1:9009','localhost:9009'].includes(process.env.FIREBASE_DATABASE_EMULATOR_HOST));
assert.ok(['127.0.0.1:8089','localhost:8089'].includes(process.env.FIRESTORE_EMULATOR_HOST));
const require=createRequire(new URL('../app_mobile_backend/package.json',import.meta.url));
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getDatabase}=require('firebase-admin/database');
const {getFirestore}=require('firebase-admin/firestore');
const {Timestamp}=require('firebase-admin/firestore');
const {Pool}=require('pg');
const schema=`akay_emulator_history_${process.pid}_${Date.now()}`;
const config={host:'127.0.0.1',port:55449,database:'postgres',user:'akay_test',password:''};
const admin=new Pool(config),pool=new Pool({...config,options:`-c search_path=${schema},public`});
const storage=require('./services/postgresRecordStore').createPostgresRecordStore(pool);
const app=initializeApp({projectId:'demo-akay-breadcrumbs',databaseURL:'https://demo-akay-breadcrumbs.firebaseio.com'},'synthetic-storage-migration');
const firebase={database:()=>getDatabase(app),firestore:()=>getFirestore(app)};
const trips=require('./services/tripStore').createTripStore(firebase,{recordStore:storage});
const migration=require('./services/legacyStorageMigration').createLegacyStorageMigration(firebase,trips,{recordStore:storage});
const uid='synthetic-migration-nav';
before(async()=>{
  assert.match(schema,/^akay_emulator_history_[0-9_]+$/);
  await admin.query(`CREATE SCHEMA ${schema}`);
  await pool.query(readFileSync(require.resolve('./database/migrations/007_postgres_history.sql'),'utf8'));
});
after(async()=>{await getDatabase(app).ref(`breadcrumb_trips/${uid}`).remove();
  await getDatabase(app).ref(`breadcrumb_links/${uid}`).remove();
  await getDatabase(app).ref(`phone_location/${uid}`).remove();
  await getFirestore(app).recursiveDelete(getFirestore(app).doc(`navigators/${uid}`));
  await getFirestore(app).doc(`legacy_rtdb/breadcrumb_links/records/${uid}`).delete();
  await deleteApp(app);
  await pool.end();await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.end();});
test('real SDK migration verifies PostgreSQL copies before conditional RTDB cleanup while live state survives',async()=>{
  const now=Date.now(),raw={ownerId:uid,name:'Synthetic route',startedAt:now-10000,endedAt:now,status:'completed',
    points:{a:{latitude:10,longitude:20,time:now-10000,accuracy:5}}};
  const ref=getDatabase(app).ref(`breadcrumb_trips/${uid}/trip`);
  await ref.set(raw);
  await getDatabase(app).ref(`phone_location/${uid}`).set({latitude:11,longitude:21,timestamp:now});
  await migration.history(uid,'trip',raw);assert.equal((await ref.get()).exists(),true);
  await migration.history(uid,'trip',raw,{apply:true});assert.equal((await ref.get()).exists(),true);
  assert.equal((await migration.history(uid,'trip',raw,{apply:true,clean:true})).removed,true);
  assert.equal((await ref.get()).exists(),false);
  assert.equal((await trips.detail(uid,'trip')).points['00000000'].time,raw.startedAt);
  assert.equal((await getDatabase(app).ref(`phone_location/${uid}`).get()).val().latitude,11);
  const link={navigator:'Synthetic navigator'};
  await getDatabase(app).ref(`breadcrumb_links/${uid}`).set(link);
  assert.equal((await migration.metadata('breadcrumb_links',uid,link,{apply:true,clean:true})).removed,true);
  const archive=await storage.collection('legacy_rtdb').doc('breadcrumb_links').collection('records').doc(uid).get();
  assert.deepEqual(archive.data().payload,link);
});
test('Firestore Timestamp captures import into PostgreSQL and leave the source intact',async()=>{
  const now=Date.now(),source=getFirestore(app).doc(`navigators/${uid}/trips/from-firestore`);
  const summary={ownerId:uid,name:'Synthetic Firestore import',sourceType:'phone_gps',
    startedAt:Timestamp.fromMillis(now-10000),endedAt:Timestamp.fromMillis(now),status:'completed',pointCount:1};
  await source.set(summary);
  await source.collection('points').doc('00000000').set({sequence:0,latitude:10,longitude:20,
    sampledAt:Timestamp.fromMillis(now-10000),accuracyMeters:5});
  const snap=await source.get(),points=await source.collection('points').orderBy('sequence').get();
  const importer=require('./services/firestoreHistoryImport').createFirestoreHistoryImport(firebase,storage);
  await importer.trip(uid,source.id,snap.data(),points.docs.map(p=>p.data()),{apply:true});
  assert.equal((await trips.detail(uid,source.id)).points['00000000'].time,now-10000);
  assert.equal((await source.get()).exists,true);
});
