'use strict';
const {test,before,after,beforeEach}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {readFileSync}=require('node:fs');
const {Pool}=require('pg');
require('../database/dateTypes');
const {createPairingService,hash,secret}=require('../services/pairingService');
// Always isolated local PostgreSQL. Never reads the application's .env/database.
const schema=`akay_security_test_${process.pid}_${Date.now()}`;
const runtimeRole=`akay_runtime_test_${process.pid}_${Date.now()}`;
const config={host:'127.0.0.1',port:55439,database:'postgres',user:'akay_test',password:'',max:12};
const admin=new Pool(config);
let pool,service;
const nav={id:randomUUID(),uid:'nav-a',role:'visually_impaired'};
const nav2={id:randomUUID(),uid:'nav-b',role:'visually_impaired'};
const car={id:randomUUID(),uid:'caregiver',role:'caregiver'};
const stranger={id:randomUUID(),uid:'stranger',role:'caregiver'};
const legacyDevice=randomUUID();
before(async()=>{
  assert.match(schema,/^akay_security_test_[0-9_]+$/);
  await admin.query(`CREATE SCHEMA ${schema}`);
  pool=new Pool({...config,options:`-c search_path=${schema},public`});
  await pool.query(`CREATE TABLE users(user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),firebase_uid text UNIQUE,password varchar(255),name text,profile_picture text,role text NOT NULL,email text UNIQUE,phone text,created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now())`);
  await pool.query(`CREATE TABLE patientprofiles(profile_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    age integer, gender text,birthdate date,medical_conditions text,allergies text,blood_type text,emergency_contact text,address text,
    created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now())`);
  await pool.query(`CREATE TABLE navigationsessions(sessionid uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid,deviceid text,
    originlatitude numeric,originlongitude numeric,originaddress text,destinationlatitude numeric,destinationlongitude numeric,destinationaddress text,
    starttime timestamptz,endtime timestamptz,totaldistance numeric,duration numeric,averagespeed numeric,status text,createdat timestamptz,updatedat timestamptz)`);
  await pool.query('CREATE TABLE smartcanes(device_id uuid PRIMARY KEY,serial_number text UNIQUE,registered_user_id uuid)');
  await pool.query('CREATE TABLE places(place_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),place_name text,category text,address text,latitude double precision,longitude double precision,is_accessible boolean,description text)');
  await pool.query('INSERT INTO smartcanes VALUES($1,$2,$3)',[legacyDevice,'synthetic-legacy-cane',nav.id]);
  await pool.query(readFileSync(require.resolve('../database/migrations/001_pairing.sql'),'utf8').replaceAll('__USERS_TABLE__','users'));
  await pool.query(readFileSync(require.resolve('../database/migrations/002_integrity.sql'),'utf8').replaceAll('__USERS_TABLE__','users'));
  service=createPairingService(pool,()=> 'users');
});
beforeEach(async()=>{
  await pool.query('TRUNCATE users CASCADE');
  await pool.query('TRUNCATE navigationsessions');
  await pool.query('TRUNCATE akay_rate_limits');
  for(const a of [nav,nav2,car,stranger]) await pool.query('INSERT INTO users(user_id,firebase_uid,name,role) VALUES($1,$2,$3,$4)',[a.id,a.uid,`Synthetic ${a.uid}`,a.role]);
});
after(async()=>{
  await pool?.end();await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
  if((await admin.query('SELECT 1 FROM pg_roles WHERE rolname=$1',[runtimeRole])).rowCount) {
    await admin.query(`DROP OWNED BY ${runtimeRole}`);await admin.query(`DROP ROLE ${runtimeRole}`);
  }
  await admin.end();
});
const error=code=>e=>e.code===code;
async function device() {
  const id=randomUUID(),key=secret(),claim=secret();
  await pool.query('INSERT INTO akay_devices(id,serial,claim_hash) VALUES($1,$2,$3)',[id,randomUUID(),hash(claim)]);
  await pool.query('INSERT INTO akay_device_credentials(device_id,secret_hash) VALUES($1,$2)',[id,hash(key)]);
  return {id,key,claim};
}
async function connect(n=nav,c=car) {
  const invitation=await service.invite(n);
  const connection=await service.redeem(c,invitation.code);
  await service.decide(n,connection.id,true);
  return connection;
}
async function assigned(n=nav) {const d=await device();await service.claim(n,d.id,d.claim);return {...d,assignment:await service.assign(n,d.id)};}
const reading=(assignment,sequence=0)=>({assignmentId:assignment.id,sequence,sampledAt:new Date(Math.max(Date.now(),new Date(assignment.started_at).getTime())).toISOString(),latitude:12.3,longitude:123.4,battery:60,status:'moving',alert:'obstacle'});

test('migration preserves legacy physical identity but does not invent custody or claims',async()=>{
  await pool.query(readFileSync(require.resolve('../database/migrations/001_pairing.sql'),'utf8').replaceAll('__USERS_TABLE__','users'));
  const d=(await pool.query('SELECT * FROM akay_devices WHERE id=$1',[legacyDevice])).rows[0];
  assert.equal(d.serial,'synthetic-legacy-cane');assert.equal(d.owner_id,null);assert.equal(d.claim_hash,null);
  assert.equal((await pool.query("SELECT * FROM akay_reconciliation WHERE source='smartcanes' AND legacy_key=$1",[legacyDevice])).rowCount,1);
  await assert.rejects(pool.query('UPDATE akay_devices SET id=$2 WHERE id=$1',[legacyDevice,randomUUID()]));
});

test('registration, repeat request and database uniqueness',async()=>{
  const d=await device();
  await assert.rejects(service.claim(nav,d.id,'wrong'),error('claim_invalid'));
  await service.claim(nav,d.id,d.claim);
  await service.claim(nav,d.id,d.claim);
  assert.equal((await service.devices(nav)).length,1);
  await assert.rejects(service.claim(nav2,d.id,d.claim),error('already_owned'));
  await assert.rejects(service.claim(car,d.id,d.claim),error('role_required'));
  const row=(await pool.query('SELECT serial FROM akay_devices WHERE id=$1',[d.id])).rows[0];
  await assert.rejects(pool.query('INSERT INTO akay_devices(serial) VALUES($1)',[row.serial]),error('23505'));
});
test('simultaneous private claims yield exactly one owner',async()=>{
  const d=await device();
  const outcomes=await Promise.allSettled([service.claim(nav,d.id,d.claim),service.claim(nav2,d.id,d.claim)]);
  assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);
  assert.equal((await pool.query('SELECT * FROM akay_ownership_history WHERE device_id=$1 AND ended_at IS NULL',[d.id])).rowCount,1);
});
test('invitations are single use, expiring, require consent and reject self/wrong roles',async()=>{
  const invite=await service.invite(nav);
  const pending=await service.redeem(car,invite.code);
  await assert.rejects(service.authorize(car,nav.uid),error('access_revoked'));
  await assert.rejects(service.redeem(stranger,invite.code),error('invalid_invitation'));
  await assert.rejects(service.decide(nav2,pending.id,true),error('forbidden'));
  await service.decide(nav,pending.id,false);
  await assert.rejects(service.authorize(car,nav.uid),error('access_revoked'));
  const expired=await service.invite(nav2);
  await pool.query("UPDATE akay_invitations SET expires_at=now()-interval '1 minute' WHERE id=$1",[expired.id]);
  await assert.rejects(service.redeem(car,expired.code),error('invalid_invitation'));
  await assert.rejects(service.invite(car),error('role_required'));
  await assert.rejects(service.redeem(nav,expired.code),error('role_required'));
});
test('duplicate concurrent pair requests cannot reset accepted consent',async()=>{
  const a=await service.invite(nav),b=await service.invite(nav);
  const results=await Promise.allSettled([service.redeem(car,a.code),service.redeem(car,b.code)]);
  assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
  const connection=results.find(x=>x.status==='fulfilled').value;
  await service.decide(nav,connection.id,true);
  const extra=await service.invite(nav);
  await assert.rejects(service.redeem(car,extra.code),error('connection_exists'));
  assert.equal((await service.connections(car))[0].status,'active');
});
test('redemption attempts are rate limited even when every code is invalid',async()=>{
  for(let i=0;i<5;i++) await assert.rejects(service.redeem(car,'bad'),error('invalid_invitation'));
  await assert.rejects(service.redeem(car,'bad'),error('rate_limited'));
});
test('pending consent expires and cannot be accepted',async()=>{
  const i=await service.invite(nav),c=await service.redeem(car,i.code);
  await pool.query("UPDATE akay_connections SET expires_at=now()-interval '1 minute' WHERE id=$1",[c.id]);
  assert.equal((await service.connections(nav))[0].status,'expired');
  await assert.rejects(service.decide(nav,c.id,true),error('request_closed'));
});
test('caregiver monitors two navigators and different canes without mixed readings or alerts',async()=>{
  await connect(nav);await connect(nav2);
  const a=await assigned(nav),b=await assigned(nav2);
  await service.ingest(a.id,a.key,reading(a.assignment));
  await service.ingest(b.id,b.key,{...reading(b.assignment),latitude:13.5,battery:25,alert:'battery_low'});
  const first=await service.snapshot(car,nav.uid),second=await service.snapshot(car,nav2.uid);
  assert.equal(first.devices[0].id,a.id);assert.equal(first.devices[0].battery,60);
  assert.equal(second.devices[0].id,b.id);assert.equal(second.devices[0].battery,25);
  assert.equal(first.alerts[0].device_id,a.id);assert.equal(second.alerts[0].device_id,b.id);
  await assert.rejects(service.snapshot(stranger,nav.uid),error('access_revoked'));
  assert.equal((await service.connections(car)).length,2);
});
test('multiple canes and caregivers per navigator, one active assignment per cane',async()=>{
  await connect(nav,car);await connect(nav,stranger);
  const a=await assigned(nav);await assigned(nav);
  await Promise.all([service.assign(nav,a.id),service.assign(nav,a.id)]);
  assert.equal((await service.devices(nav)).length,2);
  assert.equal((await pool.query('SELECT * FROM akay_assignments WHERE device_id=$1 AND ended_at IS NULL',[a.id])).rowCount,1);
  await assert.rejects(service.assign(nav2,a.id),error('not_owner'));
  assert.equal((await service.snapshot(stranger,nav.uid)).devices.length,2);
});
test('revocation denies subsequent reads without deleting users or releasing canes',async()=>{
  const c=await connect();const d=await assigned();
  await service.revoke(nav,c.id);
  await assert.rejects(service.snapshot(car,nav.uid),error('access_revoked'));
  assert.equal((await service.devices(nav))[0].id,d.id);
  assert.equal((await pool.query('SELECT * FROM users')).rowCount,4);
});
test('hardware credentials, assignment generation and replay protection are enforced',async()=>{
  const d=await assigned(),other=await assigned(nav2);
  await assert.rejects(service.ingest(other.id,d.key,reading(other.assignment)),error('device_auth_failed'));
  await service.ingest(d.id,d.key,reading(d.assignment));
  await assert.rejects(service.ingest(d.id,d.key,reading(d.assignment)),error('replayed_reading'));
  await service.release(nav,d.id);
  const newAssignment=await service.assign(nav,d.id);
  await assert.rejects(service.ingest(d.id,d.key,reading(d.assignment,1)),error('assignment_changed'));
  await service.ingest(d.id,d.key,reading(newAssignment,1));
});
test('replacement retains immutable history and new assignment never inherits old telemetry',async()=>{
  const d=await assigned();await service.ingest(d.id,d.key,reading(d.assignment));
  await service.release(nav,d.id);const replacement=await assigned();
  const snapshot=await service.snapshot(nav,nav.uid);
  assert.equal(snapshot.devices.length,1);assert.equal(snapshot.devices[0].id,replacement.id);
  assert.equal(snapshot.devices[0].battery,null);
  assert.equal((await pool.query('SELECT * FROM akay_readings WHERE assignment_id=$1',[d.assignment.id])).rowCount,1);
});
test('authorized transfer requires intended recipient and preserves old attribution',async()=>{
  const d=await assigned();await service.ingest(d.id,d.key,reading(d.assignment));
  const offer=await service.transfer(nav,d.id,nav2.uid);
  await assert.rejects(service.acceptTransfer(nav,offer.code),error('transfer_invalid'));
  await service.acceptTransfer(nav2,offer.code);
  await assert.rejects(service.acceptTransfer(nav2,offer.code),error('transfer_invalid'));
  await assert.rejects(service.assign(nav,d.id),error('not_owner'));
  const a=await service.assign(nav2,d.id);
  assert.equal((await service.snapshot(nav2,nav2.uid)).devices[0].battery,null);
  await service.ingest(d.id,d.key,reading(a,1));
  const rows=(await pool.query('SELECT navigator_id FROM akay_readings ORDER BY received_at')).rows;
  assert.deepEqual(rows.map(x=>x.navigator_id),[nav.id,nav2.id]);
});
test('release consumes claims and invalidates outstanding transfer offers',async()=>{
  const d=await assigned(),offer=await service.transfer(nav,d.id,nav2.uid);
  await service.release(nav,d.id,true);
  await assert.rejects(service.claim(nav2,d.id,d.claim),error('claim_invalid'));
  await assert.rejects(service.acceptTransfer(nav2,offer.code),error('owner_changed'));
  assert.equal((await pool.query('SELECT * FROM akay_assignments WHERE device_id=$1 AND ended_at IS NULL',[d.id])).rowCount,0);
});

test('HTTP endpoints reject UID-only auth and enforce consent, roles and session ownership',async()=>{
  const express=require('express');
  // Only this test replaces the verifier with synthetic token identities. All
  // production requests go through Admin SDK verifyIdToken(token, true).
  const override=(file,exports)=>{require.cache[require.resolve(file)]={id:require.resolve(file),filename:require.resolve(file),loaded:true,exports};};
  override('../database/db',pool);
  override('../database/ensureUsersTable',{usersTable:()=> 'users'});
  override('../database/ensurePatientProfilesTable',{patientProfilesTable:()=> 'patientprofiles'});
  const trip={ownerId:nav.uid,name:'Synthetic trip',startedAt:Date.now(),status:'completed',points:{}};
  let beforeRead=async()=>{};
  override('../services/firebaseAdmin',{
    auth:()=>({verifyIdToken:async(token,checkRevoked)=>{
      assert.equal(checkRevoked,true);
      const who=[nav,nav2,car,stranger,{uid:'new-navigator'}].find(a=>token===`synthetic:${a.uid}`);
      if(!who) throw new Error('Invalid test token');
      return {uid:who.uid,email:`${who.uid}@example.test`};
    }}),
    database:()=>({ref:()=>({orderByChild(){return this;},limitToLast(){return this;},get:async()=>{await beforeRead();return {val:()=>({synthetic:trip})};}})}),
  });
  const app=express();app.use(express.json());
  app.use('/api/v2',require('../routes/pairing'));
  app.use('/api/profile',require('../routes/profile'));
  app.use('/api/navigation',require('../routes/navigation'));
  app.use('/api/auth',require('../routes/auth'));
  const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
  const base=`http://127.0.0.1:${server.address().port}/api`;
  const request=async(path,actor,{method='GET',body}={})=>fetch(base+path,{method,headers:{'Content-Type':'application/json',...(actor?{Authorization:`Bearer ${actor}`}:{})},...(body?{body:JSON.stringify(body)}:{})});
  try {
    assert.equal((await request('/v2/connections',null)).status,401);
    assert.equal((await request('/v2/connections',nav.uid)).status,401);
    const registered=await request('/auth/register','synthetic:new-navigator',{method:'POST',body:{role:'visually_impaired',password:'synthetic-only'}});
    assert.equal(registered.status,200);
    const created=(await registered.json()).user;
    assert.equal(created.firebase_uid,'new-navigator');assert.equal(created.role,'visually_impaired');
    const repeated=await request('/auth/register','synthetic:new-navigator',{method:'POST',body:{role:'caregiver',password:'synthetic-only'}});
    assert.equal((await repeated.json()).user.role,'visually_impaired');
    assert.equal((await request('/v2/invitations',`synthetic:${car.uid}`,{method:'POST'})).status,403);
    assert.equal((await request(`/v2/navigators/${nav.uid}/snapshot`,`synthetic:${car.uid}`)).status,403);
    assert.equal((await request(`/v2/navigators/${nav.uid}/trips`,`synthetic:${stranger.uid}`)).status,403);
    const profile=await request(`/profile?userId=${nav2.id}`,`synthetic:${nav.uid}`);
    assert.equal(profile.status,200);assert.equal((await profile.json()).user.user_id,nav.id);
    const saved = await request('/profile',`synthetic:${nav.uid}`,{method:'PUT',body:{name:'Synthetic updated',age:30,allergies:'Synthetic allergy',gender:'Other'}});
    assert.equal(saved.status,200);
    const partial = await request('/profile',`synthetic:${nav.uid}`,{method:'PUT',body:{phone:'synthetic-phone'}});
    assert.equal(partial.status,200);
    const partialBody=await partial.json();
    assert.equal(partialBody.patientProfile.allergies,'Synthetic allergy');
    assert.equal(partialBody.patientProfile.age,30);
    const dateSave=await request('/profile',`synthetic:${nav.uid}`,{method:'PUT',body:{birthdate:'1990-01-01',age:1}});
    assert.equal(dateSave.status,200);
    const dateBody=await dateSave.json();
    assert.equal(dateBody.patientProfile.birthdate,'1990-01-01');
    assert.ok(dateBody.patientProfile.age>=35);
    assert.equal((await (await request('/profile',`synthetic:${nav.uid}`)).json()).patientProfile.birthdate,'1990-01-01');
    assert.equal(partialBody._meta,undefined);
    assert.equal((await request('/profile',`synthetic:${nav.uid}`,{method:'PUT',body:{age:-1}})).status,400);
    for (const body of [{age:true},{name:{unexpected:'object'}},{birthdate:'2030-02-31'},{phone:'1'.repeat(21)},{profilePicture:'http://example.test/image.png'}]) {
      assert.equal((await request('/profile',`synthetic:${nav.uid}`,{method:'PUT',body})).status,400);
    }
    const spoofEdit=await request('/profile',`synthetic:${nav.uid}`,{method:'PUT',body:{userId:nav2.id,name:'Synthetic own edit'}});
    assert.equal((await spoofEdit.json()).user.user_id,nav.id);
    assert.equal((await pool.query('SELECT name FROM users WHERE user_id=$1',[nav2.id])).rows[0].name,`Synthetic ${nav2.uid}`);
    assert.equal((await request(`/v2/navigators/${nav.uid}/trips?limit=Infinity`,`synthetic:${nav.uid}`)).status,400);
    const startBody={deviceId:`phone_${nav.uid}`,originLatitude:1,originLongitude:2,destinationLatitude:2,destinationLongitude:3};
    assert.equal((await request('/navigation/start',`synthetic:${nav.uid}`,{method:'POST',body:{...startBody,originLatitude:91}})).status,400);
    const starts=await Promise.all([1,2].map(()=>request('/navigation/start',`synthetic:${nav.uid}`,{method:'POST',body:startBody})));
    assert.deepEqual(starts.map(s=>s.status),[201,201]);
    assert.equal((await pool.query("SELECT * FROM navigationsessions WHERE user_id=$1 AND status='Active'",[nav.id])).rowCount,1);
    const active=(await pool.query("SELECT sessionid FROM navigationsessions WHERE user_id=$1 AND status='Active'",[nav.id])).rows[0];
    assert.equal((await request('/navigation/live',`synthetic:${nav.uid}`,{method:'PUT',body:{sessionId:active.sessionid,status:'Paused',totalDistance:100,duration:100}})).status,200);
    assert.equal((await request('/navigation/start',`synthetic:${nav.uid}`,{method:'POST',body:startBody})).status,201);
    assert.equal((await pool.query("SELECT * FROM navigationsessions WHERE user_id=$1 AND status IN ('Active','Paused')",[nav.id])).rowCount,1);
    assert.equal((await request('/navigation/live',`synthetic:${nav.uid}`,{method:'PUT',body:{sessionId:active.sessionid,totalDistance:-1}})).status,400);
    const spoof=await request('/auth/login',`synthetic:${nav.uid}`,{method:'POST',body:{firebase_uid:nav2.uid}});
    assert.equal((await spoof.json()).user.user_id,nav.id);
    const sessionId=randomUUID();
    await pool.query("INSERT INTO navigationsessions(sessionid,user_id,status) VALUES($1,$2,'Active')",[sessionId,nav.id]);
    assert.equal((await request('/navigation/end',`synthetic:${nav2.uid}`,{method:'POST',body:{sessionId}})).status,403);
    const c=await connect();const d=await assigned();await service.ingest(d.id,d.key,reading(d.assignment));
    const granted=await request(`/v2/navigators/${nav.uid}/snapshot`,`synthetic:${car.uid}`);
    assert.equal(granted.status,200);assert.equal((await granted.json()).devices[0].id,d.id);
    assert.equal((await request(`/v2/navigators/${nav.uid}/trips`,`synthetic:${car.uid}`)).status,200);
    // Revoke while an Admin read is in flight: the final permission check
    // must discard the fetched trip instead of returning it to the caregiver.
    beforeRead=()=>service.revoke(nav,c.id);
    assert.equal((await request(`/v2/navigators/${nav.uid}/trips`,`synthetic:${car.uid}`)).status,403);
    beforeRead=async()=>{};
    assert.equal((await request(`/v2/navigators/${nav.uid}/trips`,`synthetic:${car.uid}`)).status,403);
    assert.equal((await request(`/v2/navigators/${nav.uid}/snapshot`,`synthetic:${car.uid}`)).status,403);
    assert.equal((await request('/v2/telemetry',`synthetic:${nav.uid}`,{method:'POST',body:reading(d.assignment,1)})).status,401);
    const machine=await fetch(base+'/v2/telemetry',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Device ${d.id}.${d.key}`},body:JSON.stringify({...reading(d.assignment,1),navigatorId:nav2.id})});
    assert.equal(machine.status,200);
    assert.equal((await pool.query('SELECT navigator_id FROM akay_readings WHERE sequence=1')).rows[0].navigator_id,nav.id);
  } finally {await new Promise(resolve=>server.close(resolve));}
});

test('database enforces credential-device and alert-reading attribution',async()=>{
  const a=await assigned(),b=await assigned(nav2);
  const row=await service.ingest(a.id,a.key,reading(a.assignment));
  const credential=(await pool.query('SELECT id FROM akay_device_credentials WHERE device_id=$1',[b.id])).rows[0].id;
  await assert.rejects(pool.query(`INSERT INTO akay_readings(device_id,assignment_id,navigator_id,credential_id,sequence,sampled_at)
    VALUES($1,$2,$3,$4,1,clock_timestamp())`,[a.id,a.assignment.id,nav.id,credential]),error('23503'));
  await assert.rejects(pool.query(`INSERT INTO akay_alerts(reading_id,navigator_id,device_id,assignment_id,kind) VALUES($1,$2,$3,$4,'sos')`,[row.id,nav2.id,a.id,a.assignment.id]),error('23503'));
  assert.equal((await service.snapshot(nav2,nav2.uid)).alerts.length,0);
  await assert.rejects(pool.query(`INSERT INTO akay_alerts(reading_id,navigator_id,device_id,assignment_id,kind) VALUES($1,$2,$3,$4,'obstacle')`,[row.id,nav.id,a.id,a.assignment.id]),error('23505'));
});

test('database rejects role/custody violations and identity reassignment',async()=>{
  const d=await device();
  await assert.rejects(pool.query('UPDATE akay_devices SET owner_id=$2 WHERE id=$1',[d.id,car.id]));
  await service.claim(nav,d.id,d.claim);
  await assert.rejects(pool.query('INSERT INTO akay_assignments(device_id,navigator_id,assigned_by) VALUES($1,$2,$2)',[d.id,nav2.id]));
  await assert.rejects(pool.query('UPDATE users SET firebase_uid=$2 WHERE user_id=$1',[nav.id,'synthetic-replacement']));
  await assert.rejects(pool.query("UPDATE users SET role='caregiver' WHERE user_id=$1",[nav.id]));
  await assert.rejects(service.release(nav2,d.id,true),error('not_owner'));
  assert.equal((await service.devices(nav)).length,1);
});

test('an invitation expiring while its row is locked cannot be redeemed',async()=>{
  const invitation=await service.invite(nav);
  const lock=await pool.connect();let began;
  const transactionStarted=new Promise(resolve=>{began=resolve;});
  const instrumented={query:(...args)=>pool.query(...args),connect:async()=>{
    const db=await pool.connect();return {release:()=>db.release(),query:async(...args)=>{const result=await db.query(...args);if(args[0]==='BEGIN') began();return result;}};
  }};
  try {
    await lock.query('BEGIN');
    await lock.query('UPDATE akay_invitations SET expires_at=clock_timestamp()+interval \'250 milliseconds\' WHERE id=$1',[invitation.id]);
    await lock.query('COMMIT');
    await lock.query('BEGIN');await lock.query('SELECT id FROM akay_invitations WHERE id=$1 FOR UPDATE',[invitation.id]);
    const pending=createPairingService(instrumented,()=> 'users').redeem(car,invitation.code);
    const outcome=assert.rejects(pending,error('invalid_invitation'));
    await transactionStarted;
    await pool.query('SELECT pg_sleep(0.35)');
    await lock.query('COMMIT');
    await outcome;
    assert.equal((await service.connections(car)).length,0);
  } finally {await lock.query('ROLLBACK');lock.release();}
});

test('late-arriving older samples do not replace newer measurements',async()=>{
  const d=await assigned();
  await pool.query("UPDATE akay_assignments SET started_at=clock_timestamp()-interval '2 minutes' WHERE id=$1",[d.assignment.id]);
  await service.ingest(d.id,d.key,{...reading(d.assignment),sampledAt:new Date(Date.now()-10000).toISOString(),battery:80});
  await service.ingest(d.id,d.key,{...reading(d.assignment,1),sampledAt:new Date(Date.now()-30000).toISOString(),battery:20});
  assert.equal((await service.snapshot(nav,nav.uid)).devices[0].battery,80);
});

test('integrity migration can be reapplied without altering existing attribution',async()=>{
  const d=await assigned();const row=await service.ingest(d.id,d.key,reading(d.assignment));
  await pool.query(readFileSync(require.resolve('../database/migrations/002_integrity.sql'),'utf8').replaceAll('__USERS_TABLE__','users'));
  assert.equal((await pool.query('SELECT navigator_id FROM akay_readings WHERE id=$1',[row.id])).rows[0].navigator_id,nav.id);
});

test('integrity migration aborts on inconsistent legacy rows without repairing or partially applying',async()=>{
  const a=await assigned(),b=await assigned(nav2);
  await pool.query('ALTER TABLE akay_readings DROP CONSTRAINT akay_reading_credential_device');
  const credential=(await pool.query('SELECT id FROM akay_device_credentials WHERE device_id=$1',[b.id])).rows[0].id;
  const bad=(await pool.query(`INSERT INTO akay_readings(device_id,assignment_id,navigator_id,credential_id,sequence,sampled_at)
    VALUES($1,$2,$3,$4,0,clock_timestamp()) RETURNING id`,[a.id,a.assignment.id,nav.id,credential])).rows[0];
  const sql=readFileSync(require.resolve('../database/migrations/002_integrity.sql'),'utf8').replaceAll('__USERS_TABLE__','users');
  const db=await pool.connect();
  try {await assert.rejects(db.query(sql),error('23503'));await db.query('ROLLBACK');}
  finally {db.release();}
  assert.equal((await pool.query("SELECT * FROM pg_constraint WHERE conrelid='akay_readings'::regclass AND conname='akay_reading_credential_device'")).rowCount,0);
  assert.equal((await pool.query('SELECT * FROM akay_readings WHERE id=$1',[bad.id])).rowCount,1);
  await pool.query('DELETE FROM akay_readings WHERE id=$1',[bad.id]);
  await pool.query(sql);
});

test('restricted runtime role permits required writes but denies identity edits, history deletion and DDL',async()=>{
  const sql=readFileSync(require.resolve('../database/migrations/003_runtime_role.sql'),'utf8')
    .replaceAll('__USERS_TABLE__','users').replaceAll('__PATIENT_TABLE__','patientprofiles')
    .replaceAll('akay_runtime',runtimeRole).replace('SCHEMA public',`SCHEMA ${schema}`);
  await pool.query(sql);
  const cane=await device();
  const db=await pool.connect();
  try {
    await db.query(`SET ROLE ${runtimeRole}`);
    assert.equal((await db.query('SELECT user_id FROM users WHERE firebase_uid=$1',[nav.uid])).rowCount,1);
    await db.query('UPDATE users SET name=$2 WHERE user_id=$1',[nav.id,'Synthetic allowed edit']);
    const runtime=createPairingService({query:(...args)=>db.query(...args),connect:async()=>({query:(...args)=>db.query(...args),release(){}})},()=> 'users');
    await runtime.claim(nav,cane.id,cane.claim);
    const assignment=await runtime.assign(nav,cane.id);
    const invite=await runtime.invite(nav),connection=await runtime.redeem(car,invite.code);
    await runtime.decide(nav,connection.id,true);
    await runtime.ingest(cane.id,cane.key,reading(assignment));
    assert.equal((await runtime.snapshot(car,nav.uid)).devices[0].id,cane.id);
    const offer=await runtime.transfer(nav,cane.id,nav2.uid);
    await runtime.acceptTransfer(nav2,offer.code);
    await db.query('INSERT INTO patientprofiles(user_id,age) VALUES($1,30)',[nav.id]);
    await db.query('UPDATE patientprofiles SET age=31 WHERE user_id=$1',[nav.id]);
    await assert.rejects(db.query('UPDATE patientprofiles SET user_id=$2 WHERE user_id=$1',[nav.id,nav2.id]),error('42501'));
    await assert.rejects(db.query('UPDATE users SET firebase_uid=$2 WHERE user_id=$1',[nav.id,'replacement']),error('42501'));
    await assert.rejects(db.query('DELETE FROM akay_readings'),error('42501'));
    await assert.rejects(db.query('ALTER TABLE users ADD COLUMN unsafe text'),error('42501'));
    const capabilities=(await db.query('SELECT rolsuper,rolbypassrls FROM pg_roles WHERE rolname=current_user')).rows[0];
    assert.deepEqual(capabilities,{rolsuper:false,rolbypassrls:false});
  } finally {await db.query('RESET ROLE');db.release();}
});
