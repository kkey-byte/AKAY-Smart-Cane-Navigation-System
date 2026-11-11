'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {createLiveCaneSignals}=require('../services/liveCaneSignals');
test('only latest status and active/resolved signal overwrite RTDB; failed delivery retries committed SQL',async()=>{
  const values=new Map();let fail=true;
  const status={uid:'nav',assignment_id:'assignment',device_id:'device',reading_id:'reading',sampled_at:new Date(),battery:60,status:'moving'};
  const alert={uid:'nav',id:'alert',kind:'sos',created_at:new Date(),resolved_at:null};
  const pool={query:async sql=>({rows:sql.includes('LATERAL')?[status]:[alert]})};
  const firebase={database:()=>({ref:path=>({get:async()=>({val:()=>values.get(path)??null}),transaction:async fn=>{
    if(fail) throw new Error('Synthetic offline');
    const value=fn(values.get(path)??null);if(value!==undefined) values.set(path,value);
  }})})};
  const live=createLiveCaneSignals(pool,()=> 'users',firebase);
  assert.equal((await live.sync()).failed,2);fail=false;
  assert.equal((await live.sync()).failed,0);
  assert.equal(values.get('cane_status/nav/assignment').battery,60);
  assert.equal(values.get('urgent_signals/nav').active,true);
  alert.resolved_at=new Date(Date.now()+1);await live.sync();
  assert.equal(values.get('urgent_signals/nav').active,false);
  assert.equal(values.size,2);
  values.set('deleted_location_accounts/nav',true);
  status.battery=20;status.reading_id='new-reading';await live.sync();
  assert.equal(values.get('cane_status/nav/assignment').battery,60);
});
