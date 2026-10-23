'use strict';
const {test}=require('node:test');const assert=require('node:assert/strict');
const {resolveTable}=require('../database/schemaCatalog');
test('schema resolution refuses ambiguity and unsafe identifiers before account reads',async()=>{
  const pool={query:async(sql,args)=> {
    assert.match(sql,/^SELECT/);
    if(sql.includes('information_schema.tables')) return {rows:[{table_name:'PatientProfiles'},{table_name:'patientprofiles'}]};
    if(sql.includes('information_schema.columns')) return {rows:[{column_name:'user_id'}]};
    return {rows:[{}]};
  }};
  await assert.rejects(resolveTable(pool,['PatientProfiles','patientprofiles'],null,['user_id']),/ambiguous/);
  assert.equal(await resolveTable(pool,['PatientProfiles','patientprofiles'],'patientprofiles',['user_id'],['user_id']),'"patientprofiles"');
  await assert.rejects(resolveTable(pool,['PatientProfiles','patientprofiles'],'patientprofiles;DROP TABLE users',[]),/Unsupported/);
});
test('schema resolution fails if an ownership uniqueness constraint is missing',async()=>{
  const pool={query:async(sql)=>sql.includes('information_schema.tables')?{rows:[{table_name:'users'}]}:sql.includes('information_schema.columns')?{rows:[{column_name:'firebase_uid'}]}:{rows:[]}};
  await assert.rejects(resolveTable(pool,['users'],null,['firebase_uid'],['firebase_uid']),/uniqueness/);
});
test('normal Places startup only reads metadata and never seeds sample destinations',async()=>{
  delete process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP;
  const calls=[];
  const db=require.resolve('../database/db');
  require.cache[db]={id:db,filename:db,loaded:true,exports:{query:async(sql)=>{
    calls.push(sql);return sql.includes('information_schema.tables')?{rows:[{table_name:'places'}]}:{rows:['place_id','place_name','category','address','latitude','longitude','is_accessible','description'].map(column_name=>({column_name}))};
  }}};
  await require('../database/ensurePlacesTable')();
  assert.ok(calls.every(sql=>sql.startsWith('SELECT')));
});
