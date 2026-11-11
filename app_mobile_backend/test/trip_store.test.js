'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {createTripStore}=require('../services/tripStore');
const {memoryFirestore}=require('./helpers/memoryFirestore');
const Timestamp={fromMillis:value=>value};
function setup() {
  const memory=memoryFirestore(),now=Date.UTC(2026,0,2);
  const firebase={firestore:()=>{throw new Error('Runtime Firestore access forbidden.');},database:()=>({ref:()=>({remove:async()=>{},set:async()=>{}})})};
  const service=createTripStore(firebase,{clock:()=>now,recordStore:memory.store});
  const p=sequence=>({latitude:10+sequence/10000,longitude:20,sequence,sampledAt:now-60000+sequence*1000,accuracyMeters:5});
  return {...memory,service,now,p};
}
test('idempotent capture and receipt times; interrupted finalization recovers',async()=>{
  const c=setup(),body={name:'Walk',startedAt:c.now-60000,points:[c.p(0),c.p(1)]};
  await c.service.phoneBatch('nav','trip',body);
  const first=c.records.get('navigators/nav/trips/trip/points/00000000');
  await c.service.phoneBatch('nav','trip',body);
  assert.equal(c.records.get('navigators/nav/trips/trip/points/00000000'),first);
  assert.equal(first.sampledAt,c.p(0).sampledAt);assert.ok(first.receivedAt);
  const summary={pointCount:2,status:'completed',endedAt:c.now};
  c.failNext();await assert.rejects(c.service.finalizePhone('nav','trip',summary));
  assert.equal(c.records.get('navigators/nav/trips/trip').status,'recording');
  await c.service.finalizePhone('nav','trip',summary);
  await c.service.phoneBatch('nav','trip',body);await c.service.finalizePhone('nav','trip',summary);
  assert.equal(c.records.size,3);assert.equal(c.records.get('navigators/nav/trips/trip').pointCount,2);
});
test('missing points prevent finalization; stale point retries cannot overwrite capture time',async()=>{
  const c=setup(),body={name:'Walk',startedAt:c.now-60000,points:[c.p(0)]};
  await c.service.phoneBatch('nav','trip',body);
  await assert.rejects(c.service.finalizePhone('nav','trip',{pointCount:2,status:'completed',endedAt:c.now}),e=>e.code==='upload_incomplete');
  await c.service.phoneBatch('nav','trip',{...body,points:[{...c.p(0),sampledAt:c.now-10000}]});
  await c.service.phoneBatch('nav','trip',body);
  assert.equal(c.records.get('navigators/nav/trips/trip/points/00000000').sampledAt,c.now-10000);
});
test('stationary freshness changes summary only and survives finalization without changing original captures',async()=>{
  const c=setup();
  await c.service.phoneBatch('nav','trip',{name:'Walk',startedAt:c.now-60000,points:[c.p(0)]});
  const original=c.records.get('navigators/nav/trips/trip/points/00000000');
  await c.service.finalizePhone('nav','trip',{pointCount:1,status:'recording',lastSampledAt:c.now-1000});
  assert.equal(c.records.get('navigators/nav/trips/trip/points/00000000'),original);
  assert.equal(c.records.get('navigators/nav/trips/trip').lastSampledAt,c.now-1000);
  assert.equal(c.records.get('navigators/nav/trips/trip').durationSeconds,59);
  await assert.rejects(c.service.finalizePhone('nav','trip',{pointCount:1,status:'recording',lastSampledAt:c.now-5000}),e=>e.code==='stale_summary');
  await c.service.finalizePhone('nav','trip',{pointCount:1,status:'completed',endedAt:c.now,lastSampledAt:c.now-1000});
  const result=await c.service.detail('nav','trip');
  assert.equal(result.points['00000000'].time,c.p(0).sampledAt);
  assert.equal(result.lastSampledAt,c.now-1000);
});
test('migration dry run and retries preserve stable IDs; summary queries omit coordinates',async()=>{
  const c=setup(),legacy={ownerId:'nav',name:'Legacy',startedAt:c.now-60000,status:'completed',endedAt:c.now,
    points:{a:{latitude:10,longitude:20,time:c.now-60000,accuracy:5}}};
  await c.service.migrate('nav','legacy',legacy);assert.equal(c.records.size,0);
  await c.service.migrate('nav','legacy',legacy,{apply:true});await c.service.migrate('nav','legacy',legacy,{apply:true});
  assert.equal(c.records.size,2);assert.ok(legacy.points.a);
  const page=await c.service.list('nav',{limit:1});assert.equal(page.trips.legacy.pointCount,1);
  assert.deepEqual(page.trips.legacy.points,{});assert.ok(page.nextCursor);
  assert.deepEqual((await c.service.list('nav',{limit:1,cursor:page.nextCursor})).trips,{});
});
test('cascade deletion tombstones block outboxes and account retries; retention defaults off',async()=>{
  const c=setup(),body={name:'Walk',startedAt:c.now-60000,points:[c.p(0)]};
  await c.service.phoneBatch('nav','trip',body);await c.service.remove('nav','trip');
  assert.equal([...c.records.keys()].filter(k=>k.includes('/points/')).length,0);
  await assert.rejects(c.service.phoneBatch('nav','trip',body),e=>e.code==='history_deleted');
  await c.service.removeAccount('nav');
  await assert.rejects(c.service.phoneBatch('nav','new',body),e=>e.code==='history_deleted');
  assert.deepEqual(await c.service.retain(),{enabled:false});
});
test('legacy open-trip migration permits recovery of a newer durable phone outbox',async()=>{
  const c=setup(),legacy={ownerId:'nav',name:'Walk',startedAt:c.now-60000,status:'recording',
    points:{a:{latitude:10,longitude:20,time:c.now-60000,accuracy:5}}};
  await c.service.migrate('nav','trip',legacy,{apply:true});
  await c.service.phoneBatch('nav','trip',{name:'Walk',startedAt:legacy.startedAt,points:[c.p(0),c.p(1)]});
  await c.service.finalizePhone('nav','trip',{status:'interrupted',pointCount:2,endedAt:c.now});
  await c.service.migrate('nav','trip',legacy,{apply:true});
  const saved=c.records.get('navigators/nav/trips/trip');
  assert.equal(saved.pointCount,2);assert.equal(saved.legacyOpen,false);assert.equal(saved.status,'interrupted');
});
test('explicit cane sessions reject absent starts and gaps; retries retain a separate physical identity',async()=>{
  const c=setup(),base={...c.p(0),sessionId:'session',event:'start'};
  await assert.rejects(c.service.cane('nav','device','assignment',{...base,event:'point'}),e=>e.code==='session_order');
  const a=await c.service.cane('nav','device','assignment',base);
  assert.equal((await c.service.cane('nav','device','assignment',base)).tripId,a.tripId);
  await assert.rejects(c.service.cane('nav','device','assignment',{...base,...c.p(2),event:'point'}),e=>e.code==='session_order');
  await c.service.cane('nav','device','assignment',{...base,...c.p(1),event:'end'});
  const trip=c.records.get(`navigators/nav/trips/${a.tripId}`);
  assert.equal(trip.sourceType,'cane_gps');assert.equal(trip.deviceId,'device');assert.equal(trip.status,'completed');
});
test('monitoring preview is bounded and cane summaries filter by exact physical assignment',async()=>{
  const c=setup(),prefix='navigators/nav/trips/';
  c.records.set(prefix+'old',{ownerId:'nav',name:'Old',sourceType:'cane_gps',deviceId:'device',
    assignmentId:'old-assignment',startedAt:Timestamp.fromMillis(c.now-1000)});
  c.records.set(prefix+'current',{ownerId:'nav',name:'Cane',sourceType:'cane_gps',deviceId:'device',
    assignmentId:'assignment',startedAt:Timestamp.fromMillis(c.now-2000),status:'recording'});
  for(let i=0;i<600;i++) c.records.set(prefix+'current/points/'+String(i).padStart(12,'0'),
    {latitude:10,longitude:20,sampledAt:Timestamp.fromMillis(c.now-600+i),sequence:i});
  const page=await c.service.list('nav',{limit:1,sourceType:'cane_gps',deviceId:'device',assignmentId:'assignment'});
  assert.deepEqual(Object.keys(page.trips),['current']);
  const preview=await c.service.preview('nav','current');
  assert.equal(Object.keys(preview.points).length,500);
  assert.ok(preview.points['00000100']);assert.equal(preview.points['00000000'],undefined);
  assert.equal(preview.points['00000599'].time,c.now-1);
});
