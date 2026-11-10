'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {createMonitoringService}=require('../services/monitoringService');
function setup({timeoutMs=50}={}) {
  const now=Date.UTC(2026,10,10),values=new Map(),history=new Map(),queries=[];
  const ctx={now,values,history,queries,assignments:[]};
  const pool={query:async(_sql,args)=>{assert.deepEqual(args,['sql-nav']);return {rows:ctx.assignments};}};
  const firebase={database:()=>({ref:path=>({get:async()=>{
    const value=values.get(path);if(value instanceof Error)throw value;
    return {val:()=>value??null};
  }})})};
  const trips={list:async(uid,options)=>{
    queries.push([uid,options]);
    if(ctx.historyFailure) throw new Error('Synthetic history failure');
    if(ctx.historyStalls) return new Promise(()=>{});
    const match=[...history.entries()].find(([,t])=>t.sourceType===options.sourceType&&
      (!options.deviceId||t.deviceId===options.deviceId)&&(!options.assignmentId||t.assignmentId===options.assignmentId));
    return {trips:match?{[match[0]]:match[1]}:{}};
  },preview:async(_uid,id)=>history.get(id)};
  ctx.service=createMonitoringService(pool,firebase,trips,{clock:()=>now,timeoutMs});
  ctx.nav={uid:'nav',id:'sql-nav'};
  ctx.phone=(age=0)=>({source:'phone_gps',latitude:10,longitude:20,timestamp:now-age});
  ctx.cane=(age=0,assignment='assignment')=>({source:'cane_gps',latitude:11,longitude:21,timestamp:now-age,
    deviceId:'device',assignmentId:assignment});
  ctx.assign=()=>{ctx.assignments=[{id:'device',assignment_id:'assignment',started_at:new Date(now-60000)}];};
  return ctx;
}
test('phone-first live monitoring never combines cane points with the phone source',async()=>{
  const c=setup();c.assign();c.values.set('phone_location/nav',c.phone());
  c.values.set('cane_location/nav/assignment',c.cane());
  c.history.set('phone-trip',{sourceType:'phone_gps',status:'recording',startedAt:c.now-2000,
    points:{a:{latitude:10,longitude:20,time:c.now-1000}}});
  const data=await c.service.read(c.nav);
  assert.equal(data.location.source,'phone_gps');assert.equal(data.points[0].latitude,10);
  assert.equal(data.trip.id,'phone-trip');assert.equal(data.phoneLocation.fresh,true);
});
test('stale phone falls back to a current cane and queries only that physical assignment history',async()=>{
  const c=setup();c.assign();c.values.set('phone_location/nav',c.phone(60000));
  c.values.set('cane_location/nav/assignment',c.cane());
  c.history.set('old-owner',{sourceType:'cane_gps',deviceId:'device',assignmentId:'old-assignment',points:{}});
  c.history.set('cane-trip',{sourceType:'cane_gps',status:'recording',deviceId:'device',assignmentId:'assignment',
    startedAt:c.now-2000,points:{a:{latitude:11,longitude:21,time:c.now-1000}}});
  const data=await c.service.read(c.nav);
  assert.equal(data.location.source,'cane_gps');assert.equal(data.trip.id,'cane-trip');
  assert.deepEqual(c.queries[0][1],{limit:1,sourceType:'cane_gps',deviceId:'device',assignmentId:'assignment'});
  assert.equal(data.points[0].latitude,11);
});
test('unassigned, mismatched, future and pre-assignment cane positions never appear',async()=>{
  const c=setup();c.assign();
  for(const patch of [{assignmentId:'old-assignment'},{deviceId:'other'},
    {timestamp:c.now+31000},{timestamp:c.now-61000},{latitude:999}]) {
    c.values.set('cane_location/nav/assignment',{...c.cane(),...patch});
    assert.equal((await c.service.read(c.nav)).location,null);
  }
  c.assignments=[];c.values.set('cane_location/nav/assignment',c.cane());
  assert.equal((await c.service.read(c.nav)).location,null);
});
test('history alone remains explicitly last known even if its capture is recent',async()=>{
  const c=setup();c.history.set('trip',{sourceType:'phone_gps',points:{a:{latitude:10,longitude:20,time:c.now}}});
  const data=await c.service.read(c.nav);
  assert.equal(data.location.live,false);assert.equal(data.location.recordedOnly,true);
});
test('fresh live position survives unavailable or timed-out history, and never draws an older completed trip',async()=>{
  const c=setup({timeoutMs:5});c.values.set('phone_location/nav',c.phone());
  c.history.set('old',{sourceType:'phone_gps',status:'completed',startedAt:c.now-60000,endedAt:c.now-1000,
    points:{a:{latitude:1,longitude:2,time:c.now-1000}}});
  assert.deepEqual((await c.service.read(c.nav)).points,[]);
  c.historyFailure=true;
  const failed=await c.service.read(c.nav);assert.equal(failed.location.live,true);assert.ok(failed.errors.length);
  c.historyFailure=false;c.historyStalls=true;
  const timeout=await c.service.read(c.nav);assert.equal(timeout.location.latitude,10);assert.ok(timeout.errors.length);
});
