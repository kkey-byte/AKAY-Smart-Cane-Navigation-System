'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {initializeStorage}=require('../services/httpPolicy');

test('profile storage selects only patientprofiles before and after retired table deletion',async()=>{
  const previous=process.env.AKAY_PATIENT_TABLE;
  const bootstrap=process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP;
  const calls=[];
  let tables=['patientprofiles','PatientProfiles'];
  const db=require.resolve('../database/db');
  const schemaColumns=['profile_id','user_id','age','gender','birthdate','medical_conditions','allergies','blood_type','emergency_contact','address','created_at','updated_at'];
  require.cache[db]={id:db,filename:db,loaded:true,exports:{query:async(sql,args)=>{
    calls.push({sql,args});assert.match(sql,/^SELECT/);
    if(sql.includes('information_schema.tables')) {
      assert.deepEqual(args[0],['patientprofiles']);
      return {rows:tables.filter(name=>args[0].includes(name)).map(table_name=>({table_name}))};
    }
    if(sql.includes('information_schema.columns')) return {rows:schemaColumns.map(column_name=>({column_name}))};
    return {rows:[{}]};
  }}};
  const ensure=require('../database/ensurePatientProfilesTable');
  try {
    delete process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP;
    delete process.env.AKAY_PATIENT_TABLE;
    const checks={accounts:async()=>{},profiles:ensure,places:async()=>{}};
    assert.equal((await initializeStorage(checks)).profileReady,true);
    tables=['patientprofiles'];
    assert.equal((await initializeStorage(checks)).profileReady,true);
    process.env.AKAY_PATIENT_TABLE='patientprofiles';
    assert.equal((await initializeStorage(checks)).profileReady,true);
    assert.equal(ensure.patientProfilesTable(),'"patientprofiles"');
    assert.ok(calls.filter(call=>call.sql.includes('information_schema.columns')).every(call=>call.args[0]==='patientprofiles'));
    for(const configured of ['PatientProfiles','PatientProfile','patientprofile']) {
      process.env.AKAY_PATIENT_TABLE=configured;
      await assert.rejects(ensure(),/must be patientprofiles/);
      process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP='yes';
      await assert.rejects(ensure(),/must be patientprofiles/);
      delete process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP;
    }
    delete process.env.AKAY_PATIENT_TABLE;
    tables=['PatientProfiles'];
    assert.equal((await initializeStorage(checks)).profileReady,false);
  } finally {
    if(previous===undefined) delete process.env.AKAY_PATIENT_TABLE;else process.env.AKAY_PATIENT_TABLE=previous;
    if(bootstrap===undefined) delete process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP;else process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP=bootstrap;
  }
});
