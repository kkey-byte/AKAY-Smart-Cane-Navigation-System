'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {createPhoneLocationService}=require('../services/phoneLocation');
function setup() {
  const values=new Map(),calls=[],now=Date.UTC(2026,10,10);
  const db={query:async(sql,args)=>{calls.push([sql,args]);return {rows:sql.includes('FOR SHARE')?[{user_id:'sql-nav'}]:[]};},release(){calls.push(['release']);}};
  const firebase={database:()=>({ref:path=>({get:async()=>({val:()=>values.get(path)}),transaction:async fn=>{
    const next=fn(values.get(path)??null);if(next===undefined)return {committed:false};
    values.set(path,next);return {committed:true};
  }})})};
  const service=createPhoneLocationService({connect:async()=>db},()=> 'users',firebase,{clock:()=>now});
  const actor={id:'sql-nav',uid:'nav',role:'visually_impaired'};
  const sample={source:'phone_gps',latitude:10,longitude:20,timestamp:now-1000,accuracy:5};
  return {service,actor,sample,values,calls,now};
}
test('trusted phone publication binds Firebase UID to the PostgreSQL navigator and keeps capture time',async()=>{
  const c=setup();assert.deepEqual(await c.service.publish(c.actor,c.sample),{accepted:true,applied:true});
  const saved=c.values.get('phone_location/nav');assert.equal(saved.timestamp,c.sample.timestamp);
  assert.equal(saved.source,'phone_gps');assert.equal(saved.enabled,true);assert.ok(saved.receivedAt);
  assert.deepEqual(c.calls.find(([sql])=>sql.includes('FOR SHARE'))[1],['sql-nav','nav']);
  assert.equal(c.calls.at(-2)[0],'COMMIT');assert.equal(c.calls.at(-1)[0],'release');
});
test('retry and reversed delivery cannot overwrite newer phone coordinates',async()=>{
  const c=setup();await c.service.publish(c.actor,c.sample);
  assert.equal((await c.service.publish(c.actor,c.sample)).applied,false);
  await c.service.publish(c.actor,{...c.sample,timestamp:c.now-5000,latitude:11});
  assert.equal(c.values.get('phone_location/nav').latitude,10);
});
test('caregiver, physical cane impersonation, malformed and stale samples are rejected',async()=>{
  const c=setup();
  await assert.rejects(c.service.publish({...c.actor,role:'caregiver'},c.sample),e=>e.status===403);
  for(const patch of [{deviceId:'physical-cane'},{source:'cane_gps'},{latitude:91},{heading:361},
    {timestamp:c.now-60000},{timestamp:c.now+31000},{accuracy:-1}])
    await assert.rejects(c.service.publish(c.actor,{...c.sample,...patch}),e=>e.status===400);
  assert.equal(c.values.size,0);
});
test('pause prevents late resurrection and an old stop cannot erase resumed sharing',async()=>{
  const c=setup();await c.service.publish(c.actor,c.sample);
  await c.service.clear(c.actor,{stoppedAt:c.now});
  assert.equal(c.values.get('phone_location/nav').latitude,undefined);
  await c.service.publish(c.actor,c.sample);
  assert.equal(c.values.get('phone_location/nav').enabled,false);
  await c.service.publish(c.actor,{...c.sample,timestamp:c.now+1,latitude:12});
  await c.service.clear(c.actor,{stoppedAt:c.now});
  assert.equal(c.values.get('phone_location/nav').latitude,12);
});
test('deleted account tombstone rejects future phone writes and releases the database lock',async()=>{
  const c=setup();c.values.set('deleted_location_accounts/nav',true);
  await assert.rejects(c.service.publish(c.actor,c.sample),e=>e.status===410);
  assert.equal(c.values.has('phone_location/nav'),false);
  assert.equal(c.calls.at(-2)[0],'ROLLBACK');assert.equal(c.calls.at(-1)[0],'release');
});
