'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createDestinationProgress,arrived}=require('../services/destinationProgress');
const {createDestinationAssignment}=require('../services/destinationAssignment');
const navigator={id:'nav-db',uid:'nav-uid',role:'visually_impaired'};
const caregiver={id:'carer-db',uid:'carer-uid',role:'caregiver'};
const destination={latitude:10,longitude:20};
const fix=()=>({...destination,accuracy:5,timestamp:Date.now()});
function setup() {
  const data={};const sends=[];let allowed=true,failPush=false;
  const at=path=>path.split('/').reduce((v,k)=>v?.[k],data);
  const put=(path,value)=>{const parts=path.split('/');let node=data;for(const key of parts.slice(0,-1)) node=node[key]??={};if(value===null) delete node[parts.at(-1)];else node[parts.at(-1)]=value;};
  const ref=path=>({get:async()=>({val:()=>at(path)??null}),set:async v=>put(path,v),
    transaction:async fn=>{const v=fn(at(path));if(v!==undefined) put(path,v);},
    update:async v=>put(path,{...at(path),...v}),remove:async()=>put(path,null),child:key=>ref(`${path}/${key}`),
    orderByChild:()=>ref(path),limitToLast:()=>ref(path),limitToFirst:()=>ref(path),endAt:()=>ref(path)});
  const authorize=async(actor,uid)=>{
    if(!allowed||actor.id!==caregiver.id||uid!==navigator.uid) throw Object.assign(new Error('Revoked'),{status:403});
    return {id:navigator.id,name:'Test navigator'};
  };
  const firebase={database:()=>({ref}),messaging:()=>({send:async message=>{if(failPush) throw new Error('Offline');sends.push(message);}})};
  const service=createDestinationProgress(authorize,firebase,{query:async()=>({rows:[{token:'test-token',token_hash:'hash'}]})});
  const assignment={id:'assignment-1',navigator_id:navigator.id,navigator_uid:navigator.uid,
    caregiver_id:caregiver.id,caregiver_uid:caregiver.uid,createdAt:Date.now()-1000,destination};
  return {service,data,sends,assignment,reopen:()=>createDestinationAssignment(authorize,firebase,service),revoke:()=>{allowed=false;},failPush:value=>{failPush=value;}};
}
test('arrival requires a fresh accurate fix near the destination',()=>{
  assert.equal(arrived(destination,fix()),true);
  for(const change of [{accuracy:100},{accuracy:null},{timestamp:Date.now()-60000},{latitude:11},{latitude:NaN}])
    assert.equal(arrived(destination,{...fix(),...change}),false);
});
test('assigned arrival is durable, delivered once, and cancellation cannot replace arrival',async()=>{
  const c=setup();await c.service.start(c.assignment);
  await c.service.location(navigator,{...fix(),latitude:11});
  assert.equal((await c.service.list(caregiver)).notifications.length,0);
  await c.service.location(navigator,fix());
  await c.service.location(navigator,fix());
  assert.equal((await c.service.list(caregiver)).notifications[0].status,'arrived');
  await c.service.dispatch();
  await c.service.location(navigator,fix());
  assert.equal(c.sends.length,1);
  assert.equal(c.sends[0].data.type,'destination_progress');
  await c.service.cancel(navigator,c.assignment.id);
  assert.equal((await c.service.list(caregiver)).notifications[0].status,'arrived');
  await c.service.dispatch();assert.equal(c.sends.length,1);
});
test('cancel before arrival reports not arrived; receipts and revocation are enforced',async()=>{
  const c=setup();await c.service.start(c.assignment);
  await c.service.cancel(navigator,c.assignment.id);
  assert.equal((await c.service.list(caregiver)).notifications[0].status,'not_arrived');
  await c.service.receipt(caregiver,c.assignment.id,'read');
  assert.equal((await c.service.list(caregiver)).notifications[0].isRead,true);
  c.revoke();assert.equal((await c.service.list(caregiver)).notifications.length,0);
  await c.service.dispatch();assert.equal(c.sends.length,0);
  await assert.rejects(c.service.receipt(caregiver,c.assignment.id,'dismiss'));
});
test('wrong account cannot cancel and push failures leave a retry job',async()=>{
  const c=setup();await c.service.start(c.assignment);
  assert.equal((await c.service.cancel({...navigator,id:'other'},c.assignment.id)).accepted,false);
  await assert.rejects(c.service.cancel(caregiver,c.assignment.id));
  await c.service.location(navigator,fix());c.failPush(true);await c.service.dispatch();
  assert.ok(c.data.destination_push_queue[c.assignment.id]);
  c.failPush(false);await c.service.dispatch();assert.equal(c.sends.length,1);
});
test('replacement reports the old unfinished journey and cannot cancel the new assignment by old ID',async()=>{
  const c=setup();await c.service.start(c.assignment);
  await c.service.start({...c.assignment,id:'assignment-2'});
  assert.equal((await c.service.list(caregiver)).notifications[0].status,'not_arrived');
  assert.equal((await c.service.cancel(navigator,c.assignment.id)).accepted,false);
  await c.service.location(navigator,fix());
  assert.equal((await c.service.list(caregiver)).notifications.length,2);
});
test('a recent confirmed position wins over a cancellation request',async()=>{
  const c=setup();await c.service.start(c.assignment);
  c.data.phone_location={[navigator.uid]:{...fix(),enabled:true}};
  await c.service.cancel(navigator,c.assignment.id);
  assert.equal((await c.service.list(caregiver)).notifications[0].status,'arrived');
});

test('cancel before acknowledgement removes delivery and reopening does not restart it',async()=>{
  const c=setup();
  const {assignment}=await c.reopen().send(caregiver,navigator.uid,{navigator_id:navigator.uid,destination:{...destination,name:'Test destination',address:''}});
  assert.equal((await c.reopen().pending(navigator)).assignment.id,assignment.id);
  await c.service.cancel(navigator,assignment.id);
  assert.equal(c.data.destination_assignments[navigator.uid],undefined);
  assert.equal((await c.reopen().pending(navigator)).assignment,null);
  // Also repair an older leftover delivery when a cancellation is retried.
  c.data.destination_assignments[navigator.uid]=assignment;
  await c.service.cancel(navigator,assignment.id);
  assert.equal(c.data.destination_assignments[navigator.uid],undefined);
  assert.equal((await c.reopen().pending(navigator)).assignment,null);
});

test('finishing an old journey never deletes a newer pending delivery',async()=>{
  const c=setup();await c.service.start(c.assignment);
  const next={...c.assignment,id:'assignment-2'};
  c.data.destination_assignments={[navigator.uid]:next};
  await c.service.cancel(navigator,c.assignment.id);
  assert.equal(c.data.destination_assignments[navigator.uid].id,next.id);
});
