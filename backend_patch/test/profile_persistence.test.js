'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {Pool}=require('pg');
const express=require('express');
require('../database/dateTypes');
// Dedicated synthetic PostgreSQL instance; never loads application credentials.
const schema=`akay_profile_test_${process.pid}_${Date.now()}`;
const config={host:'127.0.0.1',port:55439,database:'postgres',user:'akay_test',password:'',connectionTimeoutMillis:3000};
function stub(path,exports) {
  const id=require.resolve(path);require.cache[id]={id,filename:id,loaded:true,exports};
}
test('profile save and fetch persist Users and patientprofiles atomically for the authenticated owner',async()=>{
  const admin=new Pool(config);let pool,server,created=false;
  try {
    await admin.query(`CREATE SCHEMA ${schema}`);created=true;
    pool=new Pool({...config,options:`-c search_path=${schema},public`});
    await pool.query(`CREATE TABLE "Users"(user_id uuid PRIMARY KEY,firebase_uid text UNIQUE,name varchar(100),email text,role text,phone varchar(20),profile_picture text,created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now())`);
    await pool.query(`CREATE TABLE patientprofiles(profile_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid NOT NULL UNIQUE REFERENCES "Users"(user_id),age integer,gender varchar(50),birthdate date,medical_conditions text,allergies text,blood_type varchar(16),emergency_contact varchar(250),address text,created_at timestamp DEFAULT now(),updated_at timestamp DEFAULT now(),CHECK(address IS DISTINCT FROM 'synthetic-reject'))`);
    const owner=randomUUID(),other=randomUUID();
    await pool.query(`INSERT INTO "Users"(user_id,firebase_uid,email,role) VALUES($1,'synthetic-owner','synthetic@example.test','visually_impaired'),($2,'synthetic-other','other@example.test','caregiver')`,[owner,other]);
    stub('../database/db',pool);
    stub('../database/ensureUsersTable',{usersTable:()=> '"Users"'});
    stub('../database/ensurePatientProfilesTable',{patientProfilesTable:()=> 'patientprofiles'});
    stub('../middleware/identity',{
      verifyFirebase:(_req,_res,next)=>next(),
      requireProfile:(req,_res,next)=>{req.actor={id:owner};next();},
    });
    const app=express();app.use(express.json());app.use('/profile',require('../routes/profile'));
    server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
    const request=async(body)=>{
      const response=await fetch(`http://127.0.0.1:${server.address().port}/profile?userId=${other}`,body===undefined?{}:{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
      return {status:response.status,body:await response.json()};
    };
    const empty=await request();assert.equal(empty.status,200);assert.equal(empty.body.patientProfile,null);
    const fields={name:'Synthetic owner',phone:'09000000000',profilePicture:'https://example.test/avatar.png',birthdate:'1990-01-01',gender:'Other',medicalConditions:'Synthetic condition',allergies:'Synthetic allergy',bloodType:'O+',emergencyContact:'Synthetic contact',address:'Synthetic address'};
    const saved=await request({...fields,userId:other});
    assert.equal(saved.status,200);assert.equal(saved.body.profileComplete,true);
    assert.equal(saved.body.user.user_id,owner);
    const account=(await pool.query('SELECT * FROM "Users" WHERE user_id=$1',[owner])).rows[0];
    const health=(await pool.query('SELECT * FROM patientprofiles WHERE user_id=$1',[owner])).rows[0];
    assert.equal(account.name,fields.name);assert.equal(account.phone,fields.phone);assert.equal(account.profile_picture,fields.profilePicture);
    for(const [requestKey,column] of Object.entries({birthdate:'birthdate',gender:'gender',medicalConditions:'medical_conditions',allergies:'allergies',bloodType:'blood_type',emergencyContact:'emergency_contact',address:'address'})) assert.equal(health[column],fields[requestKey]);
    assert.deepEqual((await request()).body.patientProfile,saved.body.patientProfile);
    assert.equal((await pool.query('SELECT name FROM "Users" WHERE user_id=$1',[other])).rows[0].name,null);
    // Snake-case aliases, explicit clears and omitted fields must round-trip.
    const updated=await request({medical_conditions:'Updated synthetic condition',blood_type:'A+',allergies:''});
    assert.equal(updated.status,200);assert.equal(updated.body.patientProfile.medicalConditions,'Updated synthetic condition');
    assert.equal(updated.body.patientProfile.allergies,'');assert.equal(updated.body.patientProfile.bloodType,'A+');assert.equal(updated.body.patientProfile.birthdate,fields.birthdate);
    const before=(await request()).body;
    for(const invalid of [{age:true},{birthdate:'2000-02-31'},{name:{}},{bloodType:'A+',blood_type:'O+'}]) assert.equal((await request(invalid)).status,400);
    // A health-table failure must roll back the Users update as well.
    assert.equal((await request({name:'Must roll back',address:'synthetic-reject'})).status,500);
    assert.deepEqual((await request()).body,before);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM patientprofiles')).rows[0].n,1);
  } finally {
    if(server) await new Promise(resolve=>server.close(resolve));
    await pool?.end();
    if(created) await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  }
});
