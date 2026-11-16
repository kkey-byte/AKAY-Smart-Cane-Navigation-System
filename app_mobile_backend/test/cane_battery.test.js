'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {batteryPercent,createCaneBatteryService}=require('../services/caneBatteryService');
test('firmware fractions convert to percentages without example or invalid fallbacks',()=>{
  assert.equal(batteryPercent(0.50391),50);assert.equal(batteryPercent(0),0);assert.equal(batteryPercent(1),100);
  assert.equal(batteryPercent(81.07422),81);assert.equal(batteryPercent(50),50);
  for(const raw of [null,undefined,'0.5',NaN,Infinity,-1,101]) assert.equal(batteryPercent(raw),null);
});
test('each request reads the assigned serial battery directly and observes subsequent changes',async()=>{
  let value=0.50391;const paths=[];
  const pool={query:async(sql,args)=>{
    assert.match(sql,/d.owner_id=a.navigator_id/);assert.match(sql,/a.ended_at IS NULL/);
    assert.deepEqual(args,['synthetic-nav']);return {rows:[{id:'device',serial:'00001',assignment_id:'assignment'}]};
  }};
  const service=createCaneBatteryService(pool,{database:()=>({ref:path=>{paths.push(path);return {get:async()=>({val:()=>value})};}})});
  assert.equal((await service.read({id:'synthetic-nav'}))[0].battery,50);
  value=0.2;assert.equal((await service.read({id:'synthetic-nav'}))[0].battery,20);
  value=null;assert.equal((await service.read({id:'synthetic-nav'}))[0].battery,null);
  assert.deepEqual(paths,Array(3).fill('Device_Location/00001/batteryLevel'));
});
test('failed, invalid and stalled reads do not retain previous readings or block other canes',async()=>{
  const service=createCaneBatteryService(null,{database:()=>({ref:path=>({get:()=>{
    if(path.includes('/slow/')) return new Promise(()=>{});
    if(path.includes('/error/')) return Promise.reject(new Error('Synthetic failure'));
    return Promise.resolve({val:()=>0.75});
  }})})},{timeoutMs:5});
  const rows=await service.readDevices(['slow','error','00002','bad/serial'].map(serial=>({id:serial,serial})));
  assert.deepEqual(rows.map(r=>r.battery),[null,null,75,null]);
});
test('no assignment means no Firebase read',async()=>{
  const service=createCaneBatteryService({query:async()=>({rows:[]})},{database:()=>{throw new Error('Must not read');}});
  assert.deepEqual(await service.read({id:'synthetic-nav'}),[]);
});
test('current SOS and fall flags are independently read each time and never fall back to old flags',async()=>{
  const values={batteryLevel:81.07422,unsafe:false,fallAlert:false};
  const service=createCaneBatteryService(null,{database:()=>({ref:path=>({get:async()=>{
    const value=values[path.split('/').at(-1)];
    if(value instanceof Error) throw value;
    return {val:()=>value};
  }})})},{includeSignals:true});
  const devices=[{id:'device',serial:'00001',assignment_id:'assignment'}];
  let [data]=await service.readDevices(devices);
  assert.equal(data.sos,false);assert.equal(data.fall,false);assert.equal(data.battery,81);
  values.unsafe=true;values.fallAlert=true;
  [data]=await service.readDevices(devices);assert.equal(data.sos,true);assert.equal(data.fall,true);
  values.unsafe=new Error('Synthetic unavailable');values.fallAlert=false;
  [data]=await service.readDevices(devices);assert.equal(data.sos,null);assert.equal(data.fall,false);assert.equal(data.battery,81);
  values.unsafe='true';values.fallAlert=1;
  [data]=await service.readDevices(devices);assert.equal(data.sos,null);assert.equal(data.fall,null);
});
