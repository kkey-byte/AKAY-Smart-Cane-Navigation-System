'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {createCaneGps}=require('../services/caneGps');
const {createPairingService}=require('../services/pairingService');
test('delayed cane GPS stays with capture assignment and cannot update reassigned live source',async()=>{
  const now=Date.UTC(2026,0,2),calls=[],live=[];
  const pairing={hardware:async(_id,key,fn)=>{
    if(key!=='valid') throw new Error('Device authentication failed');
    return fn({query:async(sql,args)=>{
      assert.match(sql,/a\.started_at<=\$3/);assert.match(sql,/a\.ended_at>\$3/);
      assert.match(sql,/akay_ownership_history/);assert.match(sql,/h\.ended_at>\$3/);
      assert.equal(args[2].getTime(),now-60000);
      return {rows:args[0]==='old-assignment'?[{uid:'previous-nav',id:'old-assignment'}]:[]};
    }},{},{},{id:'new-assignment'});
  }};
  const ingest=createCaneGps(pairing,null,()=> 'users',{cane:async(...args)=>{calls.push(args);return {accepted:true};}},
    {database:()=>({ref:path=>({transaction:async fn=>live.push([path,fn(null)])})})},{clock:()=>now});
  const body={assignmentId:'old-assignment',sampledAt:now-60000};
  await ingest('physical-cane','valid',body);
  assert.equal(calls[0][0],'previous-nav');assert.equal(calls[0][2],'old-assignment');assert.equal(live.length,0);
  await assert.rejects(ingest('physical-cane','invalid',body),/authentication failed/);
  await assert.rejects(ingest('physical-cane','valid',{...body,assignmentId:'wrong'}),e=>e.code==='assignment_invalid');
});
test('PostgreSQL consent is checked anew: stranger denied and revocation ends future reads',async()=>{
  let consent=true;
  const db={release(){},async query(sql){
    if(sql.includes('FROM users')) return {rows:[{id:'navigator',uid:'nav'}]};
    if(sql.includes('FROM akay_connections')) return {rows:consent?[{id:'connection'}]:[]};
    return {rows:[]};
  }};
  const service=createPairingService({connect:async()=>db},()=> 'users');
  await service.authorize({id:'caregiver',role:'caregiver'},'nav');
  consent=false;
  await assert.rejects(service.authorize({id:'caregiver',role:'caregiver'},'nav'),e=>e.code==='access_revoked');
  await assert.rejects(service.authorize({id:'stranger',role:'visually_impaired'},'nav'),e=>e.code==='access_revoked');
});
