'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createPairingService}=require('../services/pairingService');
const {createNavigatorHealthService}=require('../services/navigatorHealthService');

function setup() {
  const state={active:true,profile:true,healthError:false,revokeDuringRead:false,queries:[]};
  const pool={release(){},async connect(){return this;},async query(sql,args){
    state.queries.push({sql,args});
    if(['BEGIN','COMMIT','ROLLBACK'].includes(sql)) return {rows:[]};
    assert.match(sql,/^SELECT/);
    if(sql.includes('AS id,firebase_uid AS uid')) {
      return {rows:args[0]==='navigator-a' ? [{id:'nav-account',uid:'navigator-a',name:'Synthetic Navigator'}] : []};
    }
    if(sql.includes('FROM akay_connections')) {
      assert.deepEqual(args,['nav-account','caregiver-account']);
      return {rows:state.active ? [{id:'active-connection'}] : []};
    }
    if(sql.includes('LEFT JOIN patientprofiles')) {
      assert.deepEqual(args,['nav-account','navigator-a']);
      return {rows:[{user_id:'nav-account',firebase_uid:'navigator-a',name:'Synthetic Navigator',phone:'synthetic-phone',
        profile_id:state.profile ? 'patient-profile' : null,age:30,gender:'Synthetic gender',blood_type:'Synthetic type',
        medical_conditions:'Profile condition',allergies:'Profile allergy',emergency_contact:'Synthetic contact',address:'Synthetic address'}]};
    }
    if(sql.includes('FROM public.patientmedication')) {
      assert.deepEqual(args,['patient-profile']);
      if(state.healthError) throw new Error('Synthetic health schema error');
      if(state.revokeDuringRead) state.active=false;
      return {rows:[{height:'170.5',weight:'60',medical_conditions:null,allergies:'Saved allergy',
        emergency_contact_phone:'synthetic-emergency',legacy_medication:{private:'not returned'},patient_id:'not returned'}]};
    }
    throw new Error('Unexpected query');
  }};
  const authorize=createPairingService(pool,()=> 'users').authorize;
  return {state,service:createNavigatorHealthService(pool,authorize,()=> 'users',()=> 'patientprofiles')};
}
const actor={id:'caregiver-account',uid:'caregiver',role:'caregiver'};

test('active caregiver reads selected navigator profile and health without archived medication data',async()=>{
  const {service,state}=setup();
  const result=await service.snapshot(actor,'navigator-a');
  assert.equal(result.navigator.uid,'navigator-a');
  assert.equal(result.navigator.phone,'synthetic-phone');
  assert.equal(result.patientProfile.bloodType,'Synthetic type');
  assert.equal(result.health_status.height,170.5);
  assert.equal(result.health_status.medical_conditions,null);
  assert.equal(result.health_status.allergies,'Saved allergy');
  assert.equal(Object.hasOwn(result.health_status,'legacy_medication'),false);
  assert.equal(Object.hasOwn(result.health_status,'patient_id'),false);
  assert.equal(state.queries.filter(q=>q.sql.includes('FROM akay_connections')).length,2);
});
test('revoked connections and wrong roles cannot read navigator health',async()=>{
  const {service,state}=setup();
  state.active=false;
  await assert.rejects(service.snapshot(actor,'navigator-a'),error=>error.status===403);
  assert.equal(state.queries.some(q=>q.sql.includes('LEFT JOIN')),false);
  state.active=true;
  await assert.rejects(service.snapshot({...actor,role:'visually_impaired'},'navigator-a'),error=>error.status===403);
});
test('revocation during health fetch prevents returning the entire record',async()=>{
  const {service,state}=setup();
  state.revokeDuringRead=true;
  await assert.rejects(service.snapshot(actor,'navigator-a'),error=>error.status===403);
});
test('missing health schema keeps available profile fields and marks measurements unavailable',async()=>{
  const {service,state}=setup();state.healthError=true;
  const result=await service.snapshot(actor,'navigator-a');
  assert.equal(result.patientProfile.medicalConditions,'Profile condition');
  assert.equal(result.health_status,null);assert.equal(result.healthUnavailable,true);
});
test('missing patient profile stays unknown and unknown navigator does not fall back to caregiver',async()=>{
  const {service,state}=setup();state.profile=false;
  const result=await service.snapshot(actor,'navigator-a');
  assert.equal(result.patientProfile,null);assert.equal(result.health_status,null);
  assert.equal(state.queries.some(q=>q.sql.includes('patientmedication')),false);
  await assert.rejects(service.snapshot(actor,'unknown'),error=>error.status===404);
});
