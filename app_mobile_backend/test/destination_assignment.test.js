'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createDestinationAssignment}=require('../services/destinationAssignment');
function setup() {
  const values=new Map();let allowed=true;
  const service=createDestinationAssignment(async(actor,uid)=>{
    assert.equal(actor.id,'caregiver-db');assert.equal(uid,'navigator-uid');
    if(!allowed) throw new Error('Access revoked');
    return {id:'navigator-db',uid};
  },{database:()=>({ref:path=>({set:async v=>values.set(path,v),
    get:async()=>({val:()=>values.get(path)??null}),
    transaction:async fn=>{const v=fn(values.get(path));if(v!==undefined) values.set(path,v);}})})});
  return {service,values,revoke:()=>{allowed=false;}};
}
const caregiver={id:'caregiver-db',uid:'caregiver-uid',role:'caregiver'};
const navigator={id:'navigator-db',uid:'navigator-uid',role:'visually_impaired'};
const body={navigator_id:'navigator-uid',destination:{name:'Destination',address:'Test address',latitude:10,longitude:20}};
test('dispatch stores the recipient database ID and UID, never the caregiver as owner',async()=>{
  const c=setup();const {assignment:a}=await c.service.send(caregiver,navigator.uid,body);
  assert.equal(a.navigator_id,navigator.id);assert.equal(a.caregiver_id,caregiver.id);
  assert.equal(c.values.has('destination_assignments/caregiver-uid'),false);
  assert.equal((await c.service.pending(navigator)).assignment.id,a.id);
  await c.service.acknowledge(navigator,a.id);
  assert.equal((await c.service.pending(navigator)).assignment,null);
});
test('role, recipient, coordinates and revoked consent are enforced',async()=>{
  const c=setup();
  await assert.rejects(c.service.send(navigator,navigator.uid,body));
  await assert.rejects(c.service.pending(caregiver));
  await assert.rejects(c.service.send(caregiver,navigator.uid,{...body,navigator_id:caregiver.uid}));
  await assert.rejects(c.service.send(caregiver,navigator.uid,{...body,destination:{...body.destination,latitude:NaN}}));
  await c.service.send(caregiver,navigator.uid,body);c.revoke();
  await assert.rejects(c.service.pending(navigator));
  await assert.rejects(c.service.send(caregiver,navigator.uid,body));
});
test('acknowledging an older delivery preserves a newer assignment and other accounts cannot consume it',async()=>{
  const c=setup();const {assignment:a}=await c.service.send(caregiver,navigator.uid,body);
  const {assignment:b}=await c.service.send(caregiver,navigator.uid,body);
  await c.service.acknowledge(navigator,a.id);
  await c.service.acknowledge({...navigator,id:'other-db'},b.id);
  assert.equal((await c.service.pending(navigator)).assignment.id,b.id);
});

test('reopening never redelivers old pending assignments with a completed outcome',async()=>{
  for(const outcome of ['not_arrived','arrived']) {
    const c=setup();const {assignment}=await c.service.send(caregiver,navigator.uid,body);
    // Models older data: cancellation/arrival saved, but acknowledgement failed.
    c.values.set(`destination_progress/${navigator.uid}`,{...assignment,outcome});
    assert.equal((await c.service.pending(navigator)).assignment,null);
    assert.equal(c.values.get(`destination_assignments/${navigator.uid}`),null);
    assert.equal((await c.service.pending(navigator)).assignment,null);
  }
});

test('superseded pending delivery is discarded while a new unfinished assignment stays deliverable',async()=>{
  const c=setup();const {assignment:old}=await c.service.send(caregiver,navigator.uid,body);
  c.values.set(`destination_progress/${navigator.uid}`,{...old,id:'new-assignment',createdAt:old.createdAt+1});
  assert.equal((await c.service.pending(navigator)).assignment,null);
  const {assignment:next}=await c.service.send(caregiver,navigator.uid,body);
  c.values.set(`destination_progress/${navigator.uid}`,next);
  assert.equal((await c.service.pending(navigator)).assignment.id,next.id);
});
