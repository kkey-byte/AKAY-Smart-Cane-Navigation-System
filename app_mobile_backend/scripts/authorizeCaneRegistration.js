'use strict';
// Operator-only preparation; never lets a mobile client select arbitrary inventory.
function failure(message) {const error=new Error(message);error.safeMessage=message;throw error;}
function describe(error) {
  if(error.safeMessage) return error.safeMessage;
  if(error.code==='42P01') return 'Required tables are missing. Review/apply pairing migrations 001/002 and registration migrations 009/010 in this backend database.';
  if(error.code==='42703') return 'Required columns are missing. Check that registration migrations 009 and 010 were applied to this backend database.';
  if(error.code==='42501') return 'The database account lacks permission. Run preparation with the authorized operator database identity.';
  if(['ECONNREFUSED','ENOTFOUND','28P01','3D000'].includes(error.code)) return 'Cannot access the configured database. Check the backend database configuration.';
  return 'Database operation failed. Check connectivity, operator permissions and the reviewed migration state. No private database error details are printed.';
}
async function authorize(pool,serial,uid,{checkOnly=false,resolveTable=require('../database/schemaCatalog').resolveTable}={}) {
  serial=typeof serial==='string'?serial.trim():'';
  uid=typeof uid==='string'?uid.trim():'';
  if(!serial || !uid) failure('Cane serial or navigator UID is empty. Set $caneSerial and $navigatorUid in this PowerShell session before running the command.');
  if(serial==='CANE_SERIAL' || uid==='NAVIGATOR_FIREBASE_UID') failure('Replace CANE_SERIAL and NAVIGATOR_FIREBASE_UID with actual values. They are placeholders.');
  let db,started=false;
  try {
    db=await pool.connect();
    await db.query(checkOnly?'BEGIN READ ONLY':'BEGIN');started=true;
    let users;
    try {users=await resolveTable(db,['Users','users'],process.env.AKAY_USERS_TABLE,
      ['user_id','firebase_uid','role'],['user_id','firebase_uid']);}
    catch(error) {if(error.code) throw error;failure('Backend account schema is missing, ambiguous or lacks required identity columns/uniqueness. Review the Users table configuration and pairing migrations.');}
    const navigator=(await db.query(`SELECT user_id,role FROM ${users} WHERE firebase_uid=$1`,[uid])).rows[0];
    if(!navigator) failure('No backend account matches this Firebase UID. Sign in/register the navigator in this backend first; a Firebase Authentication entry alone is insufficient.');
    if(navigator.role!=='visually_impaired') failure('The matching backend account is not a navigator. Use the navigator Firebase Authentication UID, not a caregiver account.');
    const device=(await db.query(`SELECT id,owner_id,claim_hash FROM akay_devices WHERE serial=$1${checkOnly?'':' FOR UPDATE'}`,[serial])).rows[0];
    if(!device) failure('No provisioned cane matches this serial in the backend inventory. A Device_Location Firebase record alone does not provision a cane.');
    if(device.owner_id) failure('This cane is already owned. Use its existing registration or the supported transfer/release process; this command will not overwrite ownership.');
    if(!device.claim_hash) failure('This cane has no active claim proof. An operator must provision or rearm it before authorization.');
    const tables=(await db.query(`SELECT to_regclass('public.akay_cane_registration_codes') IS NOT NULL AS codes,
      to_regclass('public.akay_cane_registration_authorizations') IS NOT NULL AS authorizations`)).rows[0];
    if(!tables.codes || !tables.authorizations) failure('Registration tables are missing. Review/apply migrations 009_cane_registration_codes and 010_cane_registration_authorizations to this backend database.');
    if(checkOnly) {await db.query('COMMIT');started=false;return 'Checks passed. The navigator and unowned provisioned cane are eligible. No records were changed.';}
    await db.query('UPDATE akay_cane_registration_codes SET expires_at=clock_timestamp() WHERE device_id=$1 AND consumed_at IS NULL',[device.id]);
    await db.query(`INSERT INTO akay_cane_registration_authorizations(device_id,navigator_id)
      VALUES($1,$2) ON CONFLICT(device_id) DO UPDATE SET navigator_id=$2,
      expires_at=clock_timestamp()+interval '24 hours',consumed_at=NULL,created_at=clock_timestamp()`,[device.id,navigator.user_id]);
    await db.query('COMMIT');
    started=false;
    return 'Cane registration authorized for 24 hours.';
  } catch(error) {
    if(started) {try {await db.query('ROLLBACK');} catch(_) { /* Keep the original diagnostic. */ }}
    throw error;
  } finally {db?.release();}
}
if(require.main===module) {
  const pool=require('../database/db');
  const args=process.argv.slice(2),checkOnly=args.includes('--check');
  const [serial,uid]=args.filter(arg=>arg!=='--check');
  authorize(pool,serial,uid,{checkOnly})
    .then(message=>console.log(message))
    .catch(error=>{console.error(`Authorization failed: ${describe(error)}`);process.exitCode=1;})
    .finally(()=>pool.end());
}
module.exports={authorize,describe};
