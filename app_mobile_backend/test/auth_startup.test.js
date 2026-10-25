'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const express=require('express'),cors=require('cors');
const {corsOptions,initializeStorage,storageGuard}=require('../services/httpPolicy');
const allowed=(origin,env)=>new Promise(resolve=>corsOptions(env).origin(origin,(_error,value)=>resolve(value)));
test('development permits Flutter loopback ports, production requires explicit origins',async()=>{
  for(const origin of ['http://localhost:54321','http://127.0.0.1:62100','http://[::1]:5001']) assert.equal(await allowed(origin,{}),true);
  for(const origin of ['http://localhost.evil.test:5000','https://untrusted.example.test']) assert.equal(await allowed(origin,{}),false);
  assert.equal(await allowed('http://localhost:54321',{NODE_ENV:'production'}),false);
  assert.equal(await allowed('https://app.example.test',{NODE_ENV:'production',CORS_ALLOWED_ORIGINS:'https://app.example.test'}),true);
});
test('optional profile ambiguity cannot stop auth or expose the wrong patient table',async()=>{
  const state=await initializeStorage({accounts:async()=>{},profiles:async()=>{throw new Error('Ambiguous');},places:async()=>{}});
  assert.equal(state.profileReady,false);assert.equal(state.searchReady,true);
  await assert.rejects(initializeStorage({accounts:async()=>{throw new Error('Missing identity uniqueness');},profiles:async()=>{},places:async()=>{}}));
  const app=express();app.use(cors(corsOptions({})));
  app.post('/api/auth/register',(_req,res)=>res.status(401).json({message:'ID token required.'}));
  app.get('/api/profile',storageGuard(()=>state.profileReady,'Profile'),(_req,res)=>res.json({unexpected:true}));
  const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
  try {
    const base=`http://127.0.0.1:${server.address().port}`;
    const origin='http://localhost:54321';
    const preflight=await fetch(base+'/api/auth/register',{method:'OPTIONS',headers:{Origin:origin,'Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'authorization,content-type'}});
    assert.equal(preflight.status,204);assert.equal(preflight.headers.get('access-control-allow-origin'),origin);
    assert.equal((await fetch(base+'/api/auth/register',{method:'POST',headers:{Origin:origin}})).status,401);
    assert.equal((await fetch(base+'/api/profile')).status,503);
  } finally {await new Promise(resolve=>server.close(resolve));}
});
