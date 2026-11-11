'use strict';
require('dotenv').config();
const firebase=require('../services/firebaseAdmin');
const historyPool=require('../database/db');
const store=require('../services/tripStore').createTripStore(firebase);
const {identifier}=require('../services/tripStore');
let stage='arguments';
async function main() {
  const [operation,uid,flag]=process.argv.slice(2);
  if(operation==='retain') {
    stage='retention';
    console.log(await store.retain(process.env.AKAY_TRIP_RETENTION_DAYS));
    return;
  }
  if(!['inspect','migrate','delete-account'].includes(operation)) throw new Error('Use inspect|migrate|delete-account NAVIGATOR_UID [--apply].');
  identifier(uid);
  if(operation==='delete-account') {
    stage='account removal';
    if(flag!=='--apply') throw new Error('Account history removal requires --apply.');
    await require('../services/locationRemoval').createLocationRemoval(historyPool,require('../database/ensureUsersTable').usersTable,store)(uid);
    console.log('Account location history removed.'); return;
  }
  {
    stage='PostgreSQL account table resolution';
    // Resolve the same approved table names as server startup, without running
    // bootstrap DDL. A standalone script cannot use an uninitialized resolver.
    const table=await require('../database/schemaCatalog').resolveTable(historyPool,
      ['Users','users'],process.env.AKAY_USERS_TABLE,['user_id','firebase_uid','role']);
    stage='PostgreSQL navigator lookup';
    const identity=await historyPool.query(`SELECT user_id FROM ${table} WHERE firebase_uid=$1 AND role='visually_impaired'`,[uid]);
    if(identity.rows.length!==1) {
      const error=new Error('Navigator identity requires reconciliation.');
      error.code='navigator_identity_unresolved';throw error;
    }
  }
  let cursor,scanned=0,validated=0,failed=0;
  do {
    stage='Firebase Realtime Database history read';
    let query=firebase.database().ref(`breadcrumb_trips/${uid}`).orderByKey();
    if(cursor) query=query.startAfter(cursor);
    const snapshot=await query.limitToFirst(50).get();
    const rows=[];
    snapshot.forEach(child=>{rows.push([child.key,child.val()]);});
    for(const [id,trip] of rows) {
      scanned++;
      try { await store.migrate(uid,id,trip,{apply:operation==='migrate'&&flag==='--apply'}); validated++; }
      catch(_) {failed++;} // Aggregate only: never print identities or coordinates.
    }
    cursor=rows.length===50?rows.at(-1)[0]:null;
  } while(cursor);
  console.log({scanned,validated,failed,applied:operation==='migrate'&&flag==='--apply'});
  if(failed) process.exitCode=1;
}
main().catch(error=>{
  console.error(`History operation failed at: ${stage}.`);
  const hints={
    navigator_identity_unresolved:'The UID must match exactly one PostgreSQL navigator profile with role visually_impaired.',
    'app/invalid-credential':'Check the private Firebase server credentials configuration.',
    'app/invalid-app-options':'Check FIREBASE_DATABASE_URL and Firebase server configuration.',
    'auth/invalid-credential':'Firebase server credentials could not be authenticated.',
    ENOENT:'A configured credentials file could not be found.',
    ENOTFOUND:'A database or Firebase hostname could not be resolved.',
    ECONNREFUSED:'A configured service refused the connection.',
    '42P01':'The required PostgreSQL table is unavailable.',
    '42703':'A required PostgreSQL column is unavailable.',
    '42501':'The PostgreSQL account lacks required read permissions.',
    PERMISSION_DENIED:'Firebase denied the server request. Check server IAM permissions.',
  };
  console.error(hints[error.code]||'Check the configuration and permissions for this step. Raw errors are suppressed to protect private data.');
  process.exitCode=1;
})
  .finally(async()=>{
    await historyPool.end();
    const {getApps,deleteApp}=require('firebase-admin/app');
    await Promise.all(getApps().map(deleteApp));
  });
