'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {parseDeviceLocation,transition,createDeviceLocationService}=require('../services/deviceLocationService');
const raw={batteryLevel:0.50391,fallAlert:false,unsafe:false,latitude:10,longitude:20};
const state={sos_active:false,fall_started_at:null,fall_notified:false};
test('firmware schema converts fractional battery and rejects ambiguous flags and coordinates',()=>{
  assert.deepEqual(parseDeviceLocation(raw),{sos:false,fall:false,battery:50,latitude:10,longitude:20});
  assert.equal(parseDeviceLocation(null),null);
  assert.equal(parseDeviceLocation({...raw,unsafe:'false'}),null);
  assert.equal(parseDeviceLocation({...raw,batteryLevel:120}).battery,null);
  assert.equal(parseDeviceLocation({...raw,batteryLevel:81.07422}).battery,81);
  assert.equal(parseDeviceLocation({...raw,batteryLevel:NaN}).battery,null);
  assert.equal(parseDeviceLocation({...raw,latitude:91}).longitude,null);
});
test('SOS is immediate and latched until a false-to-true transition',()=>{
  const sample=parseDeviceLocation({...raw,unsafe:true});
  assert.equal(transition(state,sample,1000).sos,true);
  assert.equal(transition({...state,sos_active:true},sample,4000).sos,false);
});
test('fall requires three seconds; physical reset cancels and a new fall rearms',()=>{
  const sample=parseDeviceLocation({...raw,fallAlert:true});
  const first=transition(state,sample,1000);
  assert.equal(first.motion,false);assert.equal(first.wait,3000);
  const pending={...state,fall_started_at:new Date(first.started)};
  assert.equal(transition(pending,sample,3999).motion,false);
  assert.equal(transition(pending,sample,4000).motion,true);
  const reset=transition(pending,parseDeviceLocation(raw),3999);
  assert.equal(reset.started,null);assert.equal(reset.motion,false);
  const sent={...pending,fall_notified:true};
  assert.equal(transition(sent,sample,9000).motion,false);
  assert.equal(transition(state,sample,10000).wait,3000);
});
test('restart grants a fresh cancellation window but never repeats a persisted fall alert',()=>{
  const sample=parseDeviceLocation({...raw,fallAlert:true});
  const pending={...state,fall_started_at:new Date(1000)};
  assert.equal(transition(pending,sample,10000,{initial:true}).wait,3000);
  assert.equal(transition({...pending,fall_notified:true},sample,10000,{initial:true}).motion,false);
});
test('monitor subscribes by serial, never writes RTDB, and cleans up on assignment removal',async()=>{
  let rows=[{id:'assignment',serial:'00001'}],removed=0;
  const paths=[];
  const service=createDeviceLocationService({query:async()=>({rows})},{database:()=>({ref:path=>{
    paths.push(path);return {on:(event)=>assert.equal(event,'value'),off:()=>removed++};
  }})});
  await service.reconcile();await service.reconcile();
  assert.deepEqual(paths,['Device_Location/00001']);
  rows=[];await service.reconcile();assert.equal(removed,1);
  service.stop();await service.reconcile();assert.equal(removed,1);
});

test('coordinate-only firmware updates persist without clearing sensor latches or raising alerts',async()=>{
  let listener;const calls=[];
  const db={release(){},async query(sql,args){
    calls.push({sql,args});
    if(sql.includes('FOR SHARE')) return {rows:[{id:'assignment',device_id:'device',navigator_id:'navigator'}]};
    if(sql.includes('FOR UPDATE')) return {rows:[{...state,sos_active:true,fall_notified:true,
      sequence:2,payload:null,now:new Date(10000)}]};
    if(sql.includes('INSERT INTO akay_readings')) return {rows:[{id:'reading'}]};
    return {rows:[]};
  }};
  const service=createDeviceLocationService({connect:async()=>db,
    query:async()=>({rows:[{id:'assignment',serial:'synthetic'}]})},
  {database:()=>({ref:()=>({on:(_event,callback)=>{listener=callback;},off(){}})})});
  try {
    await service.reconcile();listener({val:()=>({latitude:10,longitude:20})});
    await new Promise(resolve=>setImmediate(resolve));
    const insert=calls.find(c=>c.sql.includes('INSERT INTO akay_readings'));
    assert.deepEqual(insert.args.slice(5,7),[10,20]);
    const update=calls.find(c=>c.sql.includes('SET sequence='));
    assert.equal(update.args[2],true);assert.equal(update.args[4],true);
    assert.equal(calls.some(c=>c.sql.includes('INSERT INTO akay_alerts')),false);
    assert.ok(calls.some(c=>c.sql==='COMMIT'));
  } finally {service.stop();}
});
