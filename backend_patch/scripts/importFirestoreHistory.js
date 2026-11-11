'use strict';
require('dotenv').config();
const firebase=require('../services/firebaseAdmin');
const pool=require('../database/db');
const {identifier}=require('../services/tripStore');
const storage=require('../services/postgresRecordStore').createPostgresRecordStore(pool);
const importer=require('../services/firestoreHistoryImport').createFirestoreHistoryImport(firebase,storage);
const {importDiagnostic}=require('../services/importDiagnostics');
let stage='argument validation';
function report(error) {
  console.error({stage,...importDiagnostic(error)});
}
async function main() {
  const [uid,...flags]=process.argv.slice(2);identifier(uid);
  if(flags.some(flag=>flag!=='--apply')) throw new Error('Use UID [--apply].');
  const options={apply:flags.includes('--apply')},counts={validated:0,failed:0};
  stage='account source read / destination import';
  await importer.account(uid,options);
  let query=firebase.firestore().collection('navigators').doc(uid).collection('trips').orderBy('__name__');
  while(true) {
    stage='trip summary source read';
    const page=await query.limit(50).get();
    for(const doc of page.docs) {
      try {
        stage='trip points source read';
        const points=[];let q=doc.ref.collection('points').orderBy('sequence');
        while(true) {
          const batch=await q.limit(500).get();points.push(...batch.docs.map(p=>p.data()));
          if(batch.size<500) break;
          q=doc.ref.collection('points').orderBy('sequence').startAfter(batch.docs.at(-1));
        }
        stage='trip validation / PostgreSQL import';
        await importer.trip(uid,doc.id,doc.data(),points,options);counts.validated++;
      } catch(error) {counts.failed++;if(counts.failed===1) report(error);}
    }
    if(page.size<50) break;
    query=firebase.firestore().collection('navigators').doc(uid).collection('trips').orderBy('__name__').startAfter(page.docs.at(-1));
  }
  for(const node of ['breadcrumb_shares','breadcrumb_links']) {
    stage='legacy archive source read';
    const doc=await firebase.firestore().collection('legacy_rtdb').doc(node).collection('records').doc(uid).get();
    if(doc.exists) {try {stage='legacy archive PostgreSQL import';await importer.archive(node,uid,doc.data(),options);counts.validated++;} catch(error) {counts.failed++;if(counts.failed===1) report(error);}}
  }
  console.log({...counts,applied:options.apply,sourceRetained:true});
  if(counts.failed) process.exitCode=1;
}
main().catch(error=>{console.error('History import failed; source data retained.');report(error);process.exitCode=1;})
  .finally(async()=>{await pool.end();const {getApps,deleteApp}=require('firebase-admin/app');await Promise.all(getApps().map(deleteApp));});
