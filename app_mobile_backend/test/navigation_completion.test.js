'use strict';
const {test,before,after,beforeEach}=require('node:test');
const assert=require('node:assert/strict');
const express=require('express');
let server,base,row,writes;
const id='00000000-0000-4000-8000-000000000001';
before(()=>{
  const replace=(name,exports)=>{const filename=require.resolve(name);require.cache[filename]={id:filename,filename,loaded:true,exports};};
  replace('../database/db',{query:async(sql,args)=>{
    const actor=sql.includes('UPDATE')?args[5]:args[1];
    if(args[0]!==id || actor!=='navigator') return {rows:[]};
    if(sql.includes('UPDATE')) {
      assert.match(sql,/status IN \('Active', 'Paused'\)/);
      if(!['Active','Paused'].includes(row.status)) return {rows:[]};
      writes++;row={...row,status:args[1],endtime:'synthetic-fixed-end'};
    }
    return {rows:[{...row}]};
  }});
  replace('../middleware/identity',{
    verifyFirebase:(req,_res,next)=>{req.actor={id:req.headers['x-test-actor']||'navigator',role:req.headers['x-test-role']||'visually_impaired'};next();},
    requireProfile:(_req,_res,next)=>next(),
  });
  const app=express();app.use(express.json());app.use('/navigation',require('../routes/navigation'));
  return new Promise(resolve=>{server=app.listen(0,'127.0.0.1',()=>{base=`http://127.0.0.1:${server.address().port}/navigation`;resolve();});});
});
beforeEach(()=>{row={sessionid:id,user_id:'navigator',status:'Active'};writes=0;});
after(()=>new Promise(resolve=>server.close(resolve)));
const finish=(status='Completed',headers={})=>fetch(`${base}/end`,{method:'POST',headers:{'content-type':'application/json',...headers},body:JSON.stringify({sessionId:id,status})});
test('arrival completion is idempotent and retains its original finish timestamp',async()=>{
  assert.equal((await finish()).status,200);
  assert.equal((await finish()).status,200);
  assert.equal(writes,1);assert.equal(row.endtime,'synthetic-fixed-end');
});
test('rapid concurrent Finish requests cannot create a conflicting cancellation',async()=>{
  assert.deepEqual((await Promise.all([finish(),finish()])).map(r=>r.status),[200,200]);
  assert.equal((await finish('Cancelled')).status,409);
  assert.equal(row.status,'Completed');assert.equal(writes,1);
});
test('unfinished trip cancellation still works and cannot later be relabeled completed',async()=>{
  assert.equal((await finish('Cancelled')).status,200);
  assert.equal((await finish('Cancelled')).status,200);
  assert.equal((await finish()).status,409);
  assert.equal(row.status,'Cancelled');assert.equal(writes,1);
});
test('completion retries retain navigator role and session ownership checks',async()=>{
  assert.equal((await finish('Completed',{'x-test-actor':'another-navigator'})).status,403);
  assert.equal((await finish('Completed',{'x-test-role':'caregiver'})).status,403);
  assert.equal(writes,0);
});
