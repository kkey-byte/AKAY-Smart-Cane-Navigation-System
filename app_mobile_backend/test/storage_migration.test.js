'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {memoryFirestore}=require('./helpers/memoryFirestore');
const {createTripStore}=require('../services/tripStore');
const {createLegacyStorageMigration}=require('../services/legacyStorageMigration');
function setup() {
  const memory=memoryFirestore(),values=new Map(),now=Date.UTC(2026,10,10);
  const context={...memory,values,now,beforeCleanup:null};
  const firebase={firestore:()=>{throw new Error('Runtime Firestore access forbidden.');},database:()=>({ref:path=>({
    transaction:async fn=>{
      // Model the SDK's initial callback before it has a local server cache.
      if(fn(null)===undefined) return {committed:false};
      context.beforeCleanup?.();
      const value=fn(values.get(path)??null);
      if(value===undefined) return {committed:false};
      if(value===null) values.delete(path);else values.set(path,value);
      return {committed:true};
    },remove:async()=>values.delete(path),
  })})};
  const trips=createTripStore(firebase,{clock:()=>now,recordStore:memory.store});
  return Object.assign(context,{trips,migration:createLegacyStorageMigration(firebase,trips,{recordStore:memory.store})});
}
const legacy=now=>({ownerId:'nav',name:'Synthetic trip',startedAt:now-60000,endedAt:now,status:'completed',
  points:{a:{latitude:10,longitude:20,time:now-60000,accuracy:5},b:{latitude:11,longitude:21,time:now-30000,accuracy:6}}});
test('dry run does not write; verified migration and conditional cleanup are retryable',async()=>{
  const c=setup(),raw=legacy(c.now),path='breadcrumb_trips/nav/trip';c.values.set(path,raw);
  await c.migration.history('nav','trip',raw);assert.equal(c.records.size,0);assert.ok(c.values.has(path));
  await c.migration.history('nav','trip',raw,{apply:true});assert.ok(c.values.has(path));
  const result=await c.migration.history('nav','trip',raw,{apply:true,clean:true});
  assert.equal(result.removed,true);assert.equal(c.values.has(path),false);
  const trip=await c.trips.detail('nav','trip');assert.equal(trip.pointCount,2);assert.equal(trip.points['00000001'].latitude,11);
});
test('active trips, failed commits and changed sources are never deleted',async()=>{
  const c=setup(),path='breadcrumb_trips/nav/trip',raw=legacy(c.now);c.values.set(path,raw);
  assert.equal((await c.migration.history('nav','trip',{...raw,status:'recording'},{apply:true,clean:true})).skipped,true);
  assert.equal(c.records.size,0);
  c.failNext();await assert.rejects(c.migration.history('nav','trip',raw,{apply:true,clean:true}));assert.ok(c.values.has(path));
  c.beforeCleanup=()=>c.values.set(path,{...raw,name:'Changed source'});
  assert.equal((await c.migration.history('nav','trip',raw,{apply:true,clean:true})).removed,false);
  assert.equal(c.values.get(path).name,'Changed source');
});
test('matching point count cannot hide corrupted or conflicting persistent captures',async()=>{
  const c=setup(),raw=legacy(c.now),path='breadcrumb_trips/nav/trip';c.values.set(path,raw);
  await c.migration.history('nav','trip',raw,{apply:true});
  const p=c.records.get('navigators/nav/trips/trip/points/00000001');
  c.records.set('navigators/nav/trips/trip/points/00000001',{...p,longitude:99});
  await assert.rejects(c.migration.history('nav','trip',raw,{apply:true,clean:true}),/verification failed/);
  assert.ok(c.values.has(path));
});
test('retired grants archive with verification; unknown nodes and collisions fail closed',async()=>{
  const c=setup(),raw={caregiver:{name:'Synthetic caregiver'}},path='breadcrumb_shares/nav';c.values.set(path,raw);
  await c.migration.metadata('breadcrumb_shares','nav',raw);assert.equal(c.records.size,0);
  await c.migration.metadata('breadcrumb_shares','nav',raw,{apply:true});
  await assert.rejects(c.migration.metadata('breadcrumb_shares','nav',{other:true},{apply:true,clean:true}));
  assert.ok(c.values.has(path));
  assert.equal((await c.migration.metadata('breadcrumb_shares','nav',raw,{apply:true,clean:true})).removed,true);
  assert.deepEqual(c.records.get('legacy_rtdb/breadcrumb_shares/records/nav').payload,raw);
  await assert.rejects(c.migration.metadata('phone_location','nav',raw,{apply:true,clean:true}));
});
test('migration does not read or overwrite live GPS or pending signals',async()=>{
  const c=setup(),raw=legacy(c.now);
  c.values.set('phone_location/nav',{latitude:10,timestamp:c.now});
  c.values.set('destination_assignments/nav',{id:'pending'});
  await c.migration.history('nav','trip',raw,{apply:true,clean:true});
  assert.deepEqual(c.values.get('phone_location/nav'),{latitude:10,timestamp:c.now});
  assert.deepEqual(c.values.get('destination_assignments/nav'),{id:'pending'});
});
