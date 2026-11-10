'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {createDashboardService}=require('../services/dashboardService');
function setup(options={}) {
  let now=Date.UTC(2026,9,22,12),deny=false,checks=0;
  const sources={};
  const pool={query:async(sql,args)=>{assert.match(sql,/^SELECT/);assert.deepEqual(args,['synthetic-user']);if(sql.includes('FROM akay_assignments')) return {rows:[]};return {rows:[{sessionid:'synthetic-session',destinationlatitude:'7.31',destinationlongitude:'125.68',destinationaddress:'Synthetic destination, Sample street',status:'Active',updatedat:new Date(now),starttime:new Date(now)}]};}};
  const authorize=async(_actor,uid)=>{checks++;if(deny)throw new Error('Access revoked');return {id:'synthetic-user',uid,name:'Synthetic Navigator'};};
  const firebase={database:()=>({ref:path=>({orderByChild(){return this;},limitToLast(){return this;},async get(){if(sources[path] instanceof Error)throw sources[path];return {val:()=>sources[path]??null};}})})};
  const tripStore={list:async()=>{
    if(sources['breadcrumb_trips/nav'] instanceof Error) throw sources['breadcrumb_trips/nav'];
    return {trips:sources['breadcrumb_trips/nav']||{}};
  },detail:async(_uid,id)=>sources['breadcrumb_trips/nav']?.[id]};
  const service=createDashboardService(pool,authorize,firebase,{clock:()=>now,tripStore,...options});
  return {service,sources,advance:ms=>{now+=ms;},now:()=>now,deny:()=>{deny=true;},checks:()=>checks,pool};
}
test('dashboard reads saved sessions and filtered GPS without hardware-table prerequisites',async()=>{
  const ctx=setup();
  ctx.sources['breadcrumb_trips/nav']={trip:{points:{a:{latitude:7.3,longitude:125.68,time:ctx.now()-5000},invalid:{latitude:999,longitude:125,time:ctx.now()},b:{latitude:7.301,longitude:125.68,time:ctx.now()}}}};
  const data=await ctx.service.snapshot({id:'caregiver'},'nav');
  assert.equal(data.navigation.destination,'Synthetic destination, Sample street');assert.equal(data.navigation.active,true);
  assert.equal(data.location.latitude,7.301);assert.equal(data.points.length,2);assert.equal(data.presence.state,'unknown');
  assert.equal(ctx.checks(),2);assert.deepEqual(data.errors,[]);
});
test('foreground activity expires independently from fresh background location updates',async()=>{
  const ctx=setup();const navigator={uid:'nav',role:'visually_impaired'};
  ctx.service.presence(navigator,true);
  assert.equal((await ctx.service.snapshot({},'nav')).presence.state,'active');
  ctx.advance(46000);ctx.sources['phone_location/nav']={source:'phone_gps',latitude:7.3,longitude:125.68,timestamp:ctx.now(),heading:45};
  const data=await ctx.service.snapshot({},'nav');assert.equal(data.presence.state,'inactive');assert.equal(data.location.heading,45);
  assert.throws(()=>ctx.service.presence({uid:'caregiver',role:'caregiver'},true),e=>e.status===403);
  assert.throws(()=>ctx.service.presence(navigator,'true'),e=>e.status===400);
  ctx.service.presence(navigator,false);assert.equal((await ctx.service.snapshot({},'nav')).presence.state,'inactive');
});
test('database/Firebase failures produce independent fallback fields rather than blank successful data',async()=>{
  const ctx=setup();ctx.pool.query=async()=>{throw new Error('Synthetic database error');};
  ctx.sources['breadcrumb_trips/nav']=new Error('Synthetic history error');
  ctx.sources['phone_location/nav']={source:'phone_gps',latitude:7.3,longitude:125.68,timestamp:ctx.now()};
  const data=await ctx.service.snapshot({},'nav');assert.equal(data.navigation,null);assert.equal(data.location.latitude,7.3);
  assert.equal(data.errors.length,3);assert.deepEqual(data.points,[]);
});
test('revocation racing an asynchronous read prevents returning dashboard locations',async()=>{
  const ctx=setup();ctx.pool.query=async()=>{ctx.deny();return {rows:[]};};
  await assert.rejects(ctx.service.snapshot({},'nav'),/Access revoked/);
});
test('unauthorized caregiver is denied before any monitoring query or location read',async()=>{
  const ctx=setup();ctx.deny();ctx.pool.query=async()=>{throw new Error('Location data must not be queried');};
  await assert.rejects(ctx.service.snapshot({id:'stranger'},'nav'),/Access revoked/);
  assert.equal(ctx.checks(),1);
});
test('revocation during the Firebase read invalidates the complete response',async()=>{
  const ctx=setup();Object.defineProperty(ctx.sources,'phone_location/nav',{get(){
    ctx.deny();return {source:'phone_gps',latitude:10,longitude:20,timestamp:ctx.now()};
  }});
  await assert.rejects(ctx.service.snapshot({id:'caregiver'},'nav'),/Access revoked/);
});
test('a stalled navigation-session query cannot suppress a working live GPS marker',async()=>{
  const ctx=setup({timeoutMs:5}),query=ctx.pool.query;
  ctx.pool.query=(sql,args)=>sql.includes('FROM navigationsessions')?new Promise(()=>{}):query(sql,args);
  ctx.sources['phone_location/nav']={source:'phone_gps',latitude:10,longitude:20,timestamp:ctx.now()};
  const data=await ctx.service.snapshot({id:'caregiver'},'nav');
  assert.equal(data.location.latitude,10);assert.equal(data.navigation,null);
  assert.ok(data.errors.includes('Saved navigation details are unavailable.'));
});
