'use strict';
// Operator-only, after physical possession and firmware reprovisioning.
const {writeFileSync}=require('node:fs');
const {isAbsolute}=require('node:path');
const pool=require('../database/db');
const {hash,secret}=require('../services/pairingService');
(async()=>{
  const [deviceId,privateOutput,confirmation]=process.argv.slice(2);
  if(!/^[0-9a-f-]{36}$/i.test(deviceId||'') || !isAbsolute(privateOutput||'') || !privateOutput.endsWith('.private.json') || confirmation!=='--physical-confirmed') {
    console.error('Usage: rearmCane DEVICE_UUID ABSOLUTE_PATH.private.json --physical-confirmed');await pool.end();process.exitCode=1;return;
  }
  const db=await pool.connect();
  try {
    await db.query('BEGIN');
    const device=(await db.query('SELECT * FROM akay_devices WHERE id=$1 FOR UPDATE',[deviceId])).rows[0];
    if(!device || device.owner_id) throw new Error('Device must be released by its registered custodian first.');
    const claimCode=secret(),key=secret();
    await db.query('UPDATE akay_devices SET claim_hash=$2 WHERE id=$1',[deviceId,hash(claimCode)]);
    await db.query('UPDATE akay_device_credentials SET revoked_at=now() WHERE device_id=$1 AND revoked_at IS NULL',[deviceId]);
    await db.query('INSERT INTO akay_device_credentials(device_id,secret_hash) VALUES($1,$2)',[deviceId,hash(key)]);
    await db.query("INSERT INTO akay_audit_events(action,record_id) VALUES('physical_device_rearmed',$1)",[deviceId]);
    writeFileSync(privateOutput,JSON.stringify({claimQr:{deviceId,claimCode},firmware:{deviceId,key}},null,2),{flag:'wx',mode:0o600});
    await db.query('COMMIT');console.log('Rearmed released inventory without changing its permanent Device ID. Flash the new firmware credential physically.');
  } catch(_) {await db.query('ROLLBACK');console.error('Rearming failed. Check released ownership and private output path.');process.exitCode=1;}
  finally{db.release();await pool.end();}
})();
