'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {authorize,describe}=require('../scripts/authorizeCaneRegistration');
function fixture({navigator={user_id:'synthetic-nav',role:'visually_impaired'},device={id:'synthetic-device',owner_id:null,claim_hash:'synthetic-digest'},tables={codes:true,authorizations:true}}={}) {
  const statements=[];
  const db={query:async sql=>{statements.push(sql);
    if(sql.includes('FROM "users"')) return {rows:navigator?[navigator]:[]};
    if(sql.includes('FROM akay_devices')) return {rows:device?[device]:[]};
    if(sql.includes('to_regclass')) return {rows:[tables]};
    return {rows:[]};
  },release(){}};
  return {pool:{connect:async()=>db},options:{checkOnly:true,resolveTable:async()=> '"users"'},statements};
}
test('empty and placeholder arguments explain the input issue without database access',async()=>{
  for(const values of [[undefined,undefined],['CANE_SERIAL','NAVIGATOR_FIREBASE_UID']]) {
    await assert.rejects(authorize({},...values),e=>!!e.safeMessage);
  }
});
for(const [name,settings,message] of [
  ['missing backend navigator',{navigator:null},/No backend account/],
  ['wrong role',{navigator:{role:'caregiver'}},/not a navigator/],
  ['unprovisioned cane',{device:null},/No provisioned cane/],
  ['owned cane',{device:{owner_id:'private-owner'}},/already owned/],
  ['missing proof',{device:{owner_id:null,claim_hash:null}},/no active claim proof/],
  ['missing migration',{tables:{codes:true,authorizations:false}},/Registration tables are missing/],
]) test(name,async()=>{
  const f=fixture(settings);
  await assert.rejects(authorize(f.pool,'00001','synthetic-uid',f.options),e=>message.test(describe(e)));
  assert.ok(f.statements.includes('ROLLBACK'));
});
test('check mode performs no mutations and normal authorization still commits',async()=>{
  const read=fixture();await authorize(read.pool,'00001','synthetic-uid',read.options);
  assert.equal(read.statements[0],'BEGIN READ ONLY');
  assert.ok(!read.statements.some(sql=>/INSERT|UPDATE|DELETE/.test(sql)));
  const write=fixture();await authorize(write.pool,'00001','synthetic-uid',{...write.options,checkOnly:false});
  assert.ok(write.statements.some(sql=>sql.includes('INSERT INTO akay_cane_registration_authorizations')));
  assert.equal(write.statements.at(-1),'COMMIT');
});
test('database errors never disclose raw details',()=>{
  assert.match(describe({code:'42P01'}),/migrations/);
  assert.match(describe({code:'42501'}),/permission/);
  assert.ok(!describe({message:'private credential or location'}).includes('private credential or location'));
});
