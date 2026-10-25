'use strict';
// Operator-only physical provisioning. Never an HTTP registration endpoint.
const {writeFileSync}=require('node:fs');
const {isAbsolute}=require('node:path');
const pool=require('../database/db');
const {hash,secret}=require('../services/pairingService');
(async()=>{
  const [serial,privateOutput]=process.argv.slice(2);
  if(!serial || !isAbsolute(privateOutput||'') || !privateOutput.endsWith('.private.json')) {console.error('Usage: provisionCane SERIAL ABSOLUTE_PATH.private.json');await pool.end();process.exitCode=1;return;}
  const db=await pool.connect();
  try {
    await db.query('BEGIN');
    const claimCode=secret(), key=secret();
    const device=(await db.query('INSERT INTO akay_devices(serial,claim_hash) VALUES($1,$2) RETURNING id',[serial,hash(claimCode)])).rows[0];
    await db.query('INSERT INTO akay_device_credentials(device_id,secret_hash) VALUES($1,$2)',[device.id,hash(key)]);
    // Refuse overwriting; a failed write rolls the inventory transaction back.
    writeFileSync(privateOutput,JSON.stringify({claimQr:{deviceId:device.id,claimCode},firmware:{deviceId:device.id,key}},null,2),{flag:'wx',mode:0o600});
    await db.query('COMMIT');
    console.log('Provisioned device. Private output written; do not commit or share firmware credentials.');
  } catch(error){await db.query('ROLLBACK'); console.error('Provisioning failed. Check serial uniqueness and private output path.');process.exitCode=1;}
  finally{db.release();await pool.end();}
})();
