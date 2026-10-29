'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');
const {Pool}=require('pg');
const express=require('express');
const config={host:'127.0.0.1',port:55439,database:'postgres',user:'akay_test',password:'',connectionTimeoutMillis:3000};
const database=`health_status_test_${process.pid}_${Date.now()}`;
function stub(name,exports){const id=require.resolve(name);require.cache[id]={id,filename:id,loaded:true,exports};}

test('migration preserves legacy history and health API persists only authenticated owner fields',async()=>{
  const admin=new Pool(config);let db,server,created=false;
  try {
    await admin.query(`CREATE DATABASE ${database}`);created=true;
    db=new Pool({...config,database});
    await db.query(`CREATE TABLE patientprofiles(profile_id uuid PRIMARY KEY, user_id uuid UNIQUE NOT NULL, medical_conditions text, allergies text);
      CREATE TABLE unaffected(value text); INSERT INTO unaffected VALUES('unchanged');
      CREATE TABLE patientmedication(medication_id uuid PRIMARY KEY,patient_id uuid NOT NULL REFERENCES patientprofiles(profile_id),medicine_name varchar NOT NULL,dosage varchar NOT NULL,schedule varchar NOT NULL);`);
    const owner=randomUUID(),other=randomUUID(),patient=randomUUID(),otherPatient=randomUUID();
    await db.query('INSERT INTO patientprofiles VALUES($1,$2,$3,$4),($5,$6,NULL,NULL)',[patient,owner,'existing condition','existing allergy',otherPatient,other]);
    const oldId=randomUUID();
    await db.query(`INSERT INTO patientmedication VALUES($1,$2,'Synthetic medication','Synthetic dose','Synthetic schedule'),($3,$2,'Second medication','Second dose','Second schedule')`,[oldId,patient,randomUUID()]);
    const sql=fs.readFileSync(path.join(__dirname,'../database/migrations/006_patient_health_status.sql'),'utf8');
    await db.query('CREATE VIEW health_test_dependency AS SELECT medicine_name FROM patientmedication');
    const migrationClient=await db.connect();
    try {
      await assert.rejects(migrationClient.query(sql));
      await migrationClient.query('ROLLBACK');
      assert.equal((await migrationClient.query("SELECT count(*)::int n FROM information_schema.columns WHERE table_name='patientmedication' AND column_name='height'")).rows[0].n,0);
      assert.equal((await migrationClient.query('SELECT medicine_name FROM patientmedication WHERE medication_id=$1',[oldId])).rows[0].medicine_name,'Synthetic medication');
    } finally { migrationClient.release(); }
    await db.query('DROP VIEW health_test_dependency');
    await db.query(sql);await db.query(sql);
    const legacy=(await db.query('SELECT * FROM patientmedication WHERE medication_id=$1',[oldId])).rows[0];
    assert.equal(legacy.legacy_medication.medicine_name,'Synthetic medication');
    assert.equal(legacy.patient_id,patient);assert.equal(legacy.height,null);
    const columns=(await db.query("SELECT column_name FROM information_schema.columns WHERE table_name='patientmedication'")).rows.map(r=>r.column_name);
    for(const key of ['medicine_name','dosage','schedule']) assert.ok(!columns.includes(key));
    stub('../database/db',db);
    stub('../database/ensurePatientProfilesTable',{patientProfilesTable:()=> 'public.patientprofiles'});
    stub('../middleware/identity',{
      verifyFirebase:(req,res,next)=>req.headers.authorization ? next() : res.status(401).json({message:'sign in'}),
      requireProfile:(req,res,next)=>{req.actor={id:req.headers.authorization==='other'?other:owner};next();},
    });
    const app=express();app.use(express.json());app.use('/health-status',require('../routes/healthStatus'));
    server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
    async function request(body,token='owner') {
      const response=await fetch(`http://127.0.0.1:${server.address().port}/health-status?userId=${other}`,{method:body===undefined?'GET':'PUT',headers:{...(token?{Authorization:token}:{}),'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})});
      return {status:response.status,body:await response.json()};
    }
    assert.equal((await request(undefined,null)).status,401);
    assert.equal((await request()).body.health_status,null);
    const fields={height:165,weight:62.25,medical_conditions:'Test condition',allergies:'Test allergy',emergency_contact_phone:'09000000000'};
    const saved=await request(fields);assert.equal(saved.status,200);
    for(const key of Object.keys(fields)) assert.equal(saved.body.health_status[key],fields[key]);
    assert.deepEqual((await request()).body.health_status,saved.body.health_status);
    assert.equal((await request(undefined,'other')).body.health_status,null);
    for(const invalid of [{height:-1},{height:'165'},{height:1000},{height:1.234},{allergies:[]},{userId:other},{emergency_contact_phone:'x'.repeat(41)}]) assert.equal((await request(invalid)).status,400);
    const cleared=await request({weight:null,allergies:''});
    assert.equal(cleared.body.health_status.weight,null);assert.equal(cleared.body.health_status.height,165);
    await Promise.all([request({height:170}),request({emergency_contact_phone:'09111111111'})]);
    const current=(await request()).body.health_status;assert.equal(current.height,170);assert.equal(current.emergency_contact_phone,'09111111111');
    assert.equal((await db.query('SELECT count(*)::int n FROM patientmedication WHERE health_status_record')).rows[0].n,1);
    assert.equal((await db.query('SELECT count(*)::int n FROM patientmedication WHERE NOT health_status_record')).rows[0].n,2);
    assert.equal((await db.query('SELECT value FROM unaffected')).rows[0].value,'unchanged');
    assert.equal((await db.query('SELECT medical_conditions FROM patientprofiles WHERE profile_id=$1',[patient])).rows[0].medical_conditions,'existing condition');
  } finally {
    if(server) await new Promise(resolve=>server.close(resolve));
    await db?.end();
    if(created) await admin.query(`DROP DATABASE ${database}`);
    await admin.end();
  }
});
