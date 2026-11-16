'use strict';
const {test,before,after,beforeEach}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {readFileSync}=require('node:fs');
const {Pool}=require('pg');
const {createPairingService,hash}=require('../services/pairingService');
// Disposable localhost fixture only; never loads application .env or Firebase.
const config={host:'127.0.0.1',port:55439,database:'postgres',user:'akay_test',password:''};
const schema=`akay_cane_codes_${process.pid}_${Date.now()}`;
const admin=new Pool(config);
let pool,service;
const nav={id:randomUUID(),role:'visually_impaired'},other={id:randomUUID(),role:'visually_impaired'},car={id:randomUUID(),role:'caregiver'};
before(async()=>{
  await admin.query(`CREATE SCHEMA ${schema}`);
  pool=new Pool({...config,options:`-c search_path=${schema},public`});
  await pool.query('CREATE TABLE users(user_id uuid PRIMARY KEY,firebase_uid text UNIQUE,name text,role text)');
  for(const file of ['001_pairing','002_integrity','009_cane_registration_codes','010_cane_registration_authorizations']) {
    await pool.query(readFileSync(require.resolve(`../database/migrations/${file}.sql`),'utf8').replaceAll('__USERS_TABLE__','users'));
  }
  service=createPairingService(pool,()=> 'users');
});
beforeEach(async()=>{
  await pool.query('TRUNCATE users CASCADE');await pool.query('TRUNCATE akay_rate_limits');
  for(const actor of [nav,other,car]) await pool.query('INSERT INTO users VALUES($1,$2,$3,$4)',[actor.id,actor.id,'Synthetic',actor.role]);
});
after(async()=>{await pool?.end();await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await admin.end();});
async function device() {
  const id=randomUUID(),code='synthetic-private-proof';
  await pool.query('INSERT INTO akay_devices(id,serial,claim_hash) VALUES($1,$2,$3)',[id,randomUUID(),hash(code)]);
  return {id,code};
}
test('click-triggered request uses only the cane authorized to the signed-in navigator',async()=>{
  const d=await device();
  await assert.rejects(service.requestCaneRegistration(nav),e=>e.code==='no_cane_ready');
  await pool.query('INSERT INTO akay_cane_registration_authorizations(device_id,navigator_id) VALUES($1,$2)',[d.id,nav.id]);
  await assert.rejects(service.requestCaneRegistration(other),e=>e.code==='no_cane_ready');
  const c=await service.requestCaneRegistration(nav);
  assert.equal((await service.devices(nav)).length,0);
  assert.equal((await service.confirmCaneRegistration(nav,c.registrationId,c.code)).id,d.id);
  assert.ok((await pool.query('SELECT consumed_at FROM akay_cane_registration_authorizations WHERE device_id=$1',[d.id])).rows[0].consumed_at);
});
test('revoked or expired authorization cannot complete a previously issued code',async()=>{
  const d=await device();
  await pool.query('INSERT INTO akay_cane_registration_authorizations(device_id,navigator_id) VALUES($1,$2)',[d.id,nav.id]);
  const c=await service.requestCaneRegistration(nav);
  await pool.query("UPDATE akay_cane_registration_authorizations SET expires_at=clock_timestamp()-interval '1 second' WHERE device_id=$1",[d.id]);
  await assert.rejects(service.confirmCaneRegistration(nav,c.registrationId,c.code),e=>e.status===410);
  await pool.query("UPDATE akay_cane_registration_authorizations SET expires_at=clock_timestamp()+interval '1 hour',navigator_id=$2 WHERE device_id=$1",[d.id,other.id]);
  await assert.rejects(service.confirmCaneRegistration(nav,c.registrationId,c.code),e=>e.status===410);
  assert.equal((await service.devices(nav)).length,0);
});
test('multiple prepared canes register independently in server preparation order',async()=>{
  const a=await device(),b=await device();
  await pool.query("INSERT INTO akay_cane_registration_authorizations(device_id,navigator_id,created_at) VALUES($1,$2,clock_timestamp()-interval '2 seconds'),($3,$2,clock_timestamp()-interval '1 second')",[a.id,nav.id,b.id]);
  const first=await service.requestCaneRegistration(nav);
  assert.equal((await service.confirmCaneRegistration(nav,first.registrationId,first.code)).id,a.id);
  const second=await service.requestCaneRegistration(nav);
  assert.equal((await service.confirmCaneRegistration(nav,second.registrationId,second.code)).id,b.id);
});
test('server challenge reserves no ownership until the navigator returns the correct code',async()=>{
  const d=await device(),challenge=await service.requestCaneRegistration(nav,d.id,d.code);
  assert.match(challenge.code,/^[A-HJ-NP-Z2-9]{6}$/);
  const stored=(await pool.query('SELECT * FROM akay_cane_registration_codes WHERE id=$1',[challenge.registrationId])).rows[0];
  assert.equal(stored.code_hash,hash(challenge.code));assert.notEqual(stored.code_hash,challenge.code);
  assert.equal((await pool.query('SELECT owner_id FROM akay_devices WHERE id=$1',[d.id])).rows[0].owner_id,null);
  const confirmed=await service.confirmCaneRegistration(nav,challenge.registrationId,` ${challenge.code.toLowerCase()} `);
  assert.equal(confirmed.accepted,true);assert.equal(confirmed.id,d.id);
  assert.equal((await service.devices(nav)).length,1);
  assert.equal((await pool.query('SELECT count(*) FROM akay_ownership_history')).rows[0].count,'1');
  await assert.rejects(service.confirmCaneRegistration(nav,challenge.registrationId,challenge.code),e=>e.status===410);
});
test('wrong code, another account, caregiver and invalid physical proof cannot register a cane',async()=>{
  const d=await device();
  await assert.rejects(service.requestCaneRegistration(nav,d.id,'wrong-proof'),e=>e.status===403);
  await assert.rejects(service.requestCaneRegistration(car,d.id,d.code),e=>e.status===403);
  const c=await service.requestCaneRegistration(nav,d.id,d.code);
  const wrong=c.code[0]==='A'?'B'+c.code.slice(1):'A'+c.code.slice(1);
  await assert.rejects(service.confirmCaneRegistration(nav,c.registrationId,wrong),e=>e.status===403);
  await assert.rejects(service.confirmCaneRegistration(other,c.registrationId,c.code),e=>e.status===410);
  await assert.rejects(service.confirmCaneRegistration(car,c.registrationId,c.code),e=>e.status===403);
  assert.equal((await service.devices(nav)).length,0);
  await service.confirmCaneRegistration(nav,c.registrationId,c.code);
});
test('resending replaces the previous code and expired codes never register',async()=>{
  const d=await device(),first=await service.requestCaneRegistration(nav,d.id,d.code);
  const next=await service.requestCaneRegistration(nav,d.id,d.code);
  await assert.rejects(service.confirmCaneRegistration(nav,first.registrationId,first.code),e=>e.status===410);
  await pool.query("UPDATE akay_cane_registration_codes SET expires_at=clock_timestamp()-interval '1 second' WHERE id=$1",[next.registrationId]);
  await assert.rejects(service.confirmCaneRegistration(nav,next.registrationId,next.code),e=>e.status===410);
});
test('simultaneous confirmations and competing claims produce one ownership record',async()=>{
  const d=await device(),c=await service.requestCaneRegistration(nav,d.id,d.code);
  const attempts=await Promise.allSettled([service.confirmCaneRegistration(nav,c.registrationId,c.code),service.confirmCaneRegistration(nav,c.registrationId,c.code)]);
  assert.equal(attempts.filter(a=>a.status==='fulfilled').length,1);
  assert.equal((await pool.query('SELECT count(*) FROM akay_ownership_history')).rows[0].count,'1');
  const second=await device(),pending=await service.requestCaneRegistration(nav,second.id,second.code);
  await service.claim(other,second.id,second.code);
  await assert.rejects(service.confirmCaneRegistration(nav,pending.registrationId,pending.code),e=>e.status===409);
});
test('changed cane proof invalidates outstanding registration; failed confirmations spend attempt limits',async()=>{
  const d=await device(),c=await service.requestCaneRegistration(nav,d.id,d.code);
  await pool.query('UPDATE akay_devices SET claim_hash=$2 WHERE id=$1',[d.id,hash('rotated-proof')]);
  await assert.rejects(service.confirmCaneRegistration(nav,c.registrationId,c.code),e=>e.status===409);
  for(let i=0;i<19;i++) await assert.rejects(service.confirmCaneRegistration(nav,c.registrationId,'BAD'),e=>e.status===400);
  await assert.rejects(service.confirmCaneRegistration(nav,c.registrationId,c.code),e=>e.status===429);
});
test('registration works with restricted runtime grants and migration can be reapplied',async()=>{
  const runtimeRole=`akay_cane_runtime_${process.pid}_${Date.now()}`;
  const db=await pool.connect();
  try {
    await admin.query(`CREATE ROLE ${runtimeRole} NOLOGIN`);
    await pool.query(`GRANT USAGE ON SCHEMA ${schema} TO ${runtimeRole}`);
    await pool.query(`GRANT SELECT ON users TO ${runtimeRole}`);
    await pool.query(`GRANT SELECT,UPDATE(owner_id,claim_hash) ON akay_devices TO ${runtimeRole}`);
    await pool.query(`GRANT SELECT,INSERT ON akay_ownership_history TO ${runtimeRole}`);
    await pool.query(`GRANT INSERT ON akay_audit_events TO ${runtimeRole}`);
    await pool.query(`GRANT SELECT,INSERT,UPDATE ON akay_rate_limits TO ${runtimeRole}`);
    const migration=readFileSync(require.resolve('../database/migrations/009_cane_registration_codes.sql'),'utf8')
      .replaceAll('__USERS_TABLE__','users').replaceAll('akay_runtime',runtimeRole);
    await pool.query(migration);await pool.query(migration);
    await pool.query(readFileSync(require.resolve('../database/migrations/010_cane_registration_authorizations.sql'),'utf8')
      .replaceAll('__USERS_TABLE__','users').replaceAll('akay_runtime',runtimeRole));
    const d=await device();
    await pool.query('INSERT INTO akay_cane_registration_authorizations(device_id,navigator_id) VALUES($1,$2)',[d.id,nav.id]);
    await db.query(`SET ROLE ${runtimeRole}`);
    const runtime=createPairingService({query:(...args)=>db.query(...args),connect:async()=>({query:(...args)=>db.query(...args),release(){}})},()=> 'users');
    const c=await runtime.requestCaneRegistration(nav);
    assert.equal((await runtime.confirmCaneRegistration(nav,c.registrationId,c.code)).accepted,true);
    await assert.rejects(db.query('DELETE FROM akay_cane_registration_codes'),e=>e.code==='42501');
  } finally {
    await db.query('RESET ROLE');db.release();
    await admin.query(`DROP OWNED BY ${runtimeRole}`);await admin.query(`DROP ROLE ${runtimeRole}`);
  }
});
