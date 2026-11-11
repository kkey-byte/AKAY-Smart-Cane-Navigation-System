'use strict';
require('dotenv').config();
const firebase=require('../services/firebaseAdmin');
const pool=require('../database/db');
const {identifier,createTripStore}=require('../services/tripStore');
const migration=require('../services/legacyStorageMigration').createLegacyStorageMigration(firebase,createTripStore(firebase));
async function main() {
  const [uid,...flags]=process.argv.slice(2);
  identifier(uid);
  if(flags.some(flag=>!['--apply','--cleanup'].includes(flag))||flags.includes('--cleanup')&&!flags.includes('--apply'))
    throw new Error('Use USER_UID [--apply] [--cleanup].');
  const options={apply:flags.includes('--apply'),clean:flags.includes('--cleanup')};
  const counts={validated:0,skipped:0,removed:0,changed:0,failed:0};
  // Scope every operation to a single explicitly named account, never a root.
  let cursor;
  do {
    let query=firebase.database().ref(`breadcrumb_trips/${uid}`).orderByKey();
    if(cursor) query=query.startAfter(cursor);
    const snapshot=await query.limitToFirst(50).get(),rows=[];
    snapshot.forEach(child=>rows.push([child.key,child.val()]));
    for(const [id,raw] of rows) {
      try {
        const result=await migration.history(uid,id,raw,options);
        if(result.skipped) counts.skipped++;else counts.validated++;
        if(result.removed) counts.removed++;
        if(result.eligible&&!result.removed&&options.clean) counts.changed++;
      } catch(_) {counts.failed++;}
    }
    cursor=rows.length===50?rows.at(-1)[0]:null;
  } while(cursor);
  for(const node of ['breadcrumb_shares','breadcrumb_links']) {
    const raw=(await firebase.database().ref(`${node}/${uid}`).get()).val();
    if(raw==null) continue;
    try {
      const result=await migration.metadata(node,uid,raw,options);
      counts.validated++;
      if(result.removed) counts.removed++;
      if(result.eligible&&!result.removed&&options.clean) counts.changed++;
    } catch(_) {counts.failed++;}
  }
  // Aggregate only: never print account IDs, coordinates, or grant payloads.
  console.log({...counts,applied:options.apply,cleanup:options.clean});
  if(counts.failed||counts.changed) process.exitCode=1;
}
main().catch(()=>{
  console.error('Firebase storage migration failed. Check arguments, server credentials, and emulator or deployment configuration. Private data suppressed.');
  process.exitCode=1;
}).finally(async()=>{
  await pool.end();
  const {getApps,deleteApp}=require('firebase-admin/app');
  await Promise.all(getApps().map(deleteApp));
});
