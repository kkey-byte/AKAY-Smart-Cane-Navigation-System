'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const express=require('express');
test('walking proxy validates coordinates, releases failed requests, and accepts exponent notation',async()=>{
 const app=express();app.use('/api/routing',require('../routes/routing'));
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
 const original=global.fetch, originalNow=Date.now;const local=original;let calls=0,now=originalNow(),failure=true;
 Date.now=()=>now;
 global.fetch=async(url)=>{
  calls++;assert.equal(new URL(url).hostname,'routing.openstreetmap.de');assert.match(new URL(url).pathname,/routed-foot\/route\/v1\/foot\//);
  if(failure) throw new Error('Synthetic provider outage');
  return {ok:true,json:async()=>({code:'Ok',routes:[{distance:100,duration:90,geometry:{coordinates:[[2,1],[2.001,1.001]]}}]})};
 };
 try {
  const base=`http://127.0.0.1:${server.address().port}/api/routing/walk`;
  for(const coordinates of ['bad','2,;2,1','0x10,1;2,1','2,91;2,1','2,1;2,Infinity','2,1,3;2,1']) {
    assert.equal((await local(`${base}?coordinates=${encodeURIComponent(coordinates)}`)).status,400);
  }
  assert.equal(calls,0);
  assert.equal((await local(`${base}?coordinates=2,1;2.001,1.001`)).status,503);
  now+=2000;failure=false;
  const good=await local(`${base}?coordinates=2,1;2.001,1.001`);
  assert.equal(good.status,200);assert.equal((await good.json()).code,'Ok');assert.equal(calls,2);assert.equal(good.headers.get('cache-control'),'no-store');
  assert.equal((await local(`${base}?coordinates=2,1;2.001,1.001`)).status,429);
  now+=2000;
  assert.equal((await local(`${base}?coordinates=2,1;2,1e-7`)).status,200);
  assert.equal(calls,3);
 }finally{global.fetch=original;Date.now=originalNow;server.closeAllConnections();await new Promise(r=>server.close(r));}
});
