'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {readFileSync}=require('node:fs');
const {Pool}=require('pg');
const {createPairingService,hash}=require('../services/pairingService');
const {createAccountPairingService}=require('../services/accountPairingService');

test('dedicated pairings records support instant activation, method tracking and existing access revocation',async()=>{
  const schema=`akay_account_pair_test_${process.pid}_${Date.now()}`;
  const config={host:'127.0.0.1',port:55439,database:'postgres',user:'akay_test',password:'',connectionTimeoutMillis:3000};
  const admin=new Pool(config);let pool,created=false;
  try {
    await admin.query(`CREATE SCHEMA ${schema}`);created=true;
    pool=new Pool({...config,options:`-c search_path=${schema},public`});
    await pool.query('CREATE TABLE users(user_id uuid PRIMARY KEY,firebase_uid text UNIQUE,name text,profile_picture text,role text NOT NULL)');
    await pool.query('CREATE TABLE patientprofiles(profile_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid UNIQUE REFERENCES users(user_id),allergies text)');
    for(const name of ['004_accessible_pairing','005_pairings']) {
      const sql=readFileSync(require.resolve(`../database/migrations/${name}.sql`),'utf8').replaceAll('__USERS_TABLE__','users');
      await pool.query(sql);await pool.query(sql);
    }
    const [nav,nav2,caregiver,other]=['visually_impaired','visually_impaired','caregiver','caregiver'].map(role=>({id:randomUUID(),uid:randomUUID(),role}));
    for(const person of [nav,nav2,caregiver,other]) await pool.query('INSERT INTO users(user_id,firebase_uid,name,role) VALUES($1,$2,$3,$4)',[person.id,person.uid,'Synthetic person',person.role]);
    await pool.query("INSERT INTO patientprofiles(user_id,allergies) VALUES($1,'Synthetic value')",[nav.id]);
    const service=createAccountPairingService(pool,()=> 'users');
    const legacy=createPairingService(pool,()=> 'users');
    const options={authorize_pairing:true,pairing_method:'alphanumeric'};
    await assert.rejects(service.generate(nav,{}),e=>e.code==='consent_required');
    await assert.rejects(service.generate(caregiver,options),e=>e.code==='role_required');
    const first=await service.generate(nav,options);
    assert.match(first.code,/^[A-HJ-NP-Z2-9]{6}$/);
    assert.equal(first.pairing.vi_user_id,nav.id);assert.equal(first.pairing.status,'pending');
    assert.equal(first.pairing.caregiver_id,null);assert.equal(first.pairing.paired_at,null);
    const next=await service.generate(nav,{...options,device_id:first.pairing.device_id});
    assert.equal(next.pairing.device_id,first.pairing.device_id);assert.notEqual(next.code,first.code);
    await assert.rejects(service.redeem(caregiver,{code:first.code,pairing_method:'alphanumeric'}),e=>e.code==='invalid_pairing');
    const result=await service.redeem(caregiver,{code:next.code.toLowerCase(),pairing_method:'qr_code'});
    assert.equal(result.pairing.caregiver_id,caregiver.id);assert.equal(result.pairing.status,'active');
    assert.equal(result.pairing.pairing_method,'qr_code');assert.ok(result.pairing.paired_at);assert.equal(result.pairing.unpaired_at,null);
    assert.equal((await legacy.authorize(caregiver,nav.uid)).id,nav.id);
    await assert.rejects(service.redeem(other,{code:next.code,pairing_method:'alphanumeric'}),e=>e.code==='invalid_pairing');
    const second=await service.generate(nav2,{...options,pairing_method:'qr_code'});
    await service.redeem(caregiver,{code:second.code,pairing_method:'alphanumeric'});
    assert.equal((await legacy.connections(caregiver)).filter(row=>row.status==='active').length,2);
    const listed=await service.list(caregiver);assert.equal(listed.length,2);assert.equal(Object.hasOwn(listed[0],'pairing_code'),false);
    assert.equal((await pool.query('SELECT p.allergies FROM pairings r JOIN patientprofiles p ON p.user_id=r.vi_user_id WHERE r.pairing_id=$1',[next.pairing.pairing_id])).rows[0].allergies,'Synthetic value');
    await legacy.revoke(nav,result.connection_id);
    const closed=(await pool.query('SELECT status,unpaired_at FROM pairings WHERE pairing_id=$1',[next.pairing.pairing_id])).rows[0];
    assert.equal(closed.status,'unpaired');assert.ok(closed.unpaired_at);
    await assert.rejects(legacy.authorize(caregiver,nav.uid),e=>e.code==='access_revoked');
    const expiring=await service.generate(nav,options);
    await pool.query("UPDATE akay_invitations SET expires_at=now()-interval '1 minute' WHERE code_hash=$1",[hash(expiring.code)]);
    await assert.rejects(service.redeem(other,{code:expiring.code,pairing_method:'qr_code'}),e=>e.code==='invalid_pairing');
    // Existing manual-consent invitations keep their original behavior.
    const oldInvite=await legacy.invite(nav);
    assert.equal(oldInvite.code.length,43);
    assert.equal((await legacy.redeem(other,oldInvite.code)).status,'pending');
    const contested=await service.generate(nav,options);
    const outcomes=await Promise.allSettled([caregiver,other].map(actor=>service.redeem(actor,{code:contested.code,pairing_method:'alphanumeric'})));
    assert.equal(outcomes.filter(outcome=>outcome.status==='fulfilled').length,1);
  } finally {await pool?.end();if(created) await admin.query(`DROP SCHEMA ${schema} CASCADE`);await admin.end();}
});

test('original physical-device pairings schema upgrades without changing cane or profile tables',async()=>{
  const schema=`akay_legacy_pair_test_${process.pid}_${Date.now()}`;
  const config={host:'127.0.0.1',port:55439,database:'postgres',user:'akay_test',password:'',connectionTimeoutMillis:3000};
  const admin=new Pool(config);let pool,created=false;
  try {
    await admin.query(`CREATE SCHEMA ${schema}`);created=true;
    pool=new Pool({...config,options:`-c search_path=${schema},public`});
    await pool.query('CREATE TABLE users(user_id uuid PRIMARY KEY,role text)');
    await pool.query('CREATE TABLE smartcanes(device_id uuid PRIMARY KEY)');
    await pool.query(`CREATE TABLE pairings(pairing_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      device_id uuid NOT NULL REFERENCES smartcanes(device_id),vi_user_id uuid NOT NULL REFERENCES users(user_id),
      caregiver_id uuid NOT NULL REFERENCES users(user_id),pairing_code varchar(50) NOT NULL UNIQUE,
      pairing_method varchar(20) NOT NULL CHECK(pairing_method IN ('QR_CODE','MANUAL_CODE','NFC','BLUETOOTH')),
      status varchar(20) NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','PENDING','UNPAIRED','EXPIRED')),
      paired_at timestamp DEFAULT CURRENT_TIMESTAMP,unpaired_at timestamp)`);
    const nav=randomUUID(),caregiver=randomUUID(),device=randomUUID();
    await pool.query("INSERT INTO users VALUES($1,'visually_impaired'),($2,'caregiver')",[nav,caregiver]);
    await pool.query('INSERT INTO smartcanes VALUES($1)',[device]);
    await pool.query("INSERT INTO pairings(device_id,vi_user_id,caregiver_id,pairing_code,pairing_method) VALUES($1,$2,$3,'LEGACY','MANUAL_CODE')",[device,nav,caregiver]);
    for(const name of ['004_accessible_pairing','005_pairings']) await pool.query(readFileSync(require.resolve(`../database/migrations/${name}.sql`),'utf8').replaceAll('__USERS_TABLE__','users'));
    const original=(await pool.query("SELECT * FROM pairings WHERE pairing_code='LEGACY'")).rows[0];
    assert.equal(original.status,'active');assert.equal(original.pairing_method,'alphanumeric');assert.equal(original.device_id,device);
    assert.equal((await pool.query('SELECT * FROM smartcanes')).rowCount,1);
    const app=randomUUID();await pool.query('INSERT INTO pairing_app_instances(device_id,vi_user_id) VALUES($1,$2)',[app,nav]);
    const pending=(await pool.query("INSERT INTO pairings(device_id,vi_user_id,pairing_code,pairing_method) VALUES($1,$2,'ABC234','qr_code') RETURNING *",[app,nav])).rows[0];
    assert.equal(pending.caregiver_id,null);assert.equal(pending.paired_at,null);assert.equal(pending.status,'pending');
    assert.equal((await pool.query('SELECT * FROM smartcanes')).rowCount,1);
  } finally {await pool?.end();if(created) await admin.query(`DROP SCHEMA ${schema} CASCADE`);await admin.end();}
});
