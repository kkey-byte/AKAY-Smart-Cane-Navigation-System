import {readFile} from 'node:fs/promises';
import {before,after,test} from 'node:test';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {ref,get,set,update,onValue} from 'firebase/database';
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-akay-breadcrumbs',database:{host:'127.0.0.1',port:9009,rules:await readFile(new URL('./database.rules.json',import.meta.url),'utf8')}});});
after(async()=>{await env?.cleanup();});
const db=uid=>env.authenticatedContext(uid).database();
const trip=()=>({ownerId:'navigator',name:'Synthetic walk',startedAt:Date.now()-5000,status:'recording',points:{'00000000':{latitude:12.3,longitude:123.4,accuracy:8,time:Date.now()-1000}}});
test('owner records; caregiver and strangers require backend, even with legacy grants',async()=>{
  const owner=db('navigator'),caregiver=db('caregiver');
  await assertSucceeds(set(ref(owner,'breadcrumb_trips/navigator/trip'),trip()));
  await assertSucceeds(get(ref(owner,'breadcrumb_trips/navigator/trip')));
  await env.withSecurityRulesDisabled(async context=>{await set(ref(context.database(),'breadcrumb_shares/navigator/caregiver'),{name:'Legacy grant'});});
  await assertFails(get(ref(caregiver,'breadcrumb_trips/navigator/trip')));
  await assertFails(get(ref(db('unrelated'),'breadcrumb_trips/navigator/trip')));
  await assertFails(get(ref(env.unauthenticatedContext().database(),'breadcrumb_trips/navigator/trip')));
  await assertFails(update(ref(owner),{'breadcrumb_shares/navigator/caregiver':{name:'Forged'},'breadcrumb_links/caregiver/navigator':{name:'Forged'}}));
});
test('broad legacy live channels cannot be used to bypass consent or impersonate a cane',async()=>{
  for(const root of ['navigation_live','live_location']) {
    await assertFails(set(ref(db('navigator'),`${root}/arbitrary-cane`),{latitude:12.3,longitude:123.4}));
    await assertFails(get(ref(db('caregiver'),root)));
  }
});
test('phone GPS has explicit own-account attribution and coordinate validation',async()=>{
  const value={latitude:12.3,longitude:123.4,timestamp:Date.now(),source:'phone_gps'};
  await assertSucceeds(set(ref(db('navigator'),'phone_location/navigator'),value));
  await assertFails(set(ref(db('navigator'),'phone_location/other'),value));
  await assertFails(get(ref(db('caregiver'),'phone_location/navigator')));
  await assertFails(set(ref(db('navigator'),'phone_location/navigator'),{...value,latitude:100}));
  await assertFails(set(ref(db('navigator'),'phone_location/navigator'),{...value,source:'cane'}));
});
test('caregiver subscription cannot start even if a client supplies a navigator UID',async()=>{
  await new Promise((resolve,reject)=>{
    let stop;
    const timeout=setTimeout(()=>{stop?.();reject(new Error('Expected denied caregiver subscription'));},5000);
    stop=onValue(ref(db('caregiver'),'breadcrumb_trips/navigator'),()=>{clearTimeout(timeout);stop?.();reject(new Error('Unauthorized data delivered'));},()=>{clearTimeout(timeout);stop?.();resolve();});
  });
});
test('invalid GPS points and impersonated trip owners remain rejected',async()=>{
  const bad=trip();bad.points['00000000'].latitude=100;
  await assertFails(set(ref(db('navigator'),'breadcrumb_trips/navigator/bad'),bad));
  await assertFails(set(ref(db('navigator'),'breadcrumb_trips/other/bad'),trip()));
});

test('phone records reject invented timestamps and unexpected sensitive fields',async()=>{
  const value={latitude:12.3,longitude:123.4,timestamp:Date.now(),source:'phone_gps'};
  for(const patch of [{timestamp:'not-a-time'},{timestamp:Date.now()+60000},{timestamp:Date.now()-600000},{patientNotes:'Unexpected'},{heading:361}]) {
    await assertFails(set(ref(db('navigator'),'phone_location/navigator'),{...value,...patch}));
  }
});

test('trip start cannot be relabelled and points cannot predate the trip',async()=>{
  const owner=db('navigator'),value=trip();
  await assertSucceeds(set(ref(owner,'breadcrumb_trips/navigator/timechecks'),value));
  await assertFails(update(ref(owner,'breadcrumb_trips/navigator/timechecks'),{startedAt:value.startedAt-1000}));
  const bad=trip();bad.points['00000000'].time=bad.startedAt-1000;
  await assertFails(set(ref(owner,'breadcrumb_trips/navigator/earlypoint'),bad));
  await assertSucceeds(set(ref(owner,'breadcrumb_trips/navigator/timechecks'),null));
});
