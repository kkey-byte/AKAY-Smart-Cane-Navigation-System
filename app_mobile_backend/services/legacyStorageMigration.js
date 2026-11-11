'use strict';
const {createHash}=require('node:crypto');

const {identifier}=require('./tripStore');
// Canonical JSON lets retries and conditional cleanup ignore object-key order.
function canonical(value) {
  if(Array.isArray(value)) return value.map(canonical);
  if(value&&typeof value==='object') return Object.fromEntries(Object.keys(value).sort().map(key=>[key,canonical(value[key])]));
  return value;
}
const digest=value=>createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
function createLegacyStorageMigration(firebase,trips,{recordStore,pool}={}) {
  const storage=recordStore??require('./postgresRecordStore').createPostgresRecordStore(pool??require('../database/db'));
  async function cleanup(ref,original,apply) {
    if(!apply) return {eligible:true,removed:false};
    // The Admin SDK can first invoke this callback with an empty local cache.
    // Returning undefined there aborts before reading the server. A null write
    // makes the SDK compare server state and retry with the actual source.
    const result=await ref.transaction(current=>current==null||digest(current)===digest(original)?null:undefined);
    return {eligible:true,removed:result.committed===true};
  }
  async function history(uid,id,raw,{apply=false,clean=false}={}) {
    identifier(uid);identifier(id);
    // Never turn a running legacy recording into a completed trip or remove it.
    if(raw?.status==='recording') return {skipped:true,reason:'active_recording'};
    if(!['completed','interrupted'].includes(raw?.status)) throw new Error('Invalid legacy history status.');
    await trips.migrate(uid,id,raw,{apply});
    if(!apply) return {validated:true,removed:false};
    const saved=await trips.detail(uid,id);
    const source=Object.entries(raw.points||{}).sort(([a],[b])=>a.localeCompare(b)).map(([,point])=>point);
    const target=Object.values(saved?.points||{});
    // Verify every capture, not merely the number of documents. No source
    // deletion is allowed for tombstones, collisions, or partially copied data.
    if(!saved||saved.ownerId!==uid||saved.name!==raw.name||saved.startedAt!==raw.startedAt||saved.status!==raw.status||
      saved.endedAt!==(raw.endedAt??source.at(-1)?.time)||saved.pointCount!==source.length||target.length!==source.length||
      source.some((p,i)=>target[i].latitude!==p.latitude||target[i].longitude!==p.longitude||
        target[i].time!==p.time||target[i].accuracy!==(p.accuracy??0))) throw new Error('History verification failed; source retained.');
    return clean?cleanup(firebase.database().ref(`breadcrumb_trips/${uid}/${id}`),raw,true):{validated:true,removed:false};
  }
  async function metadata(node,uid,raw,{apply=false,clean=false}={}) {
    // Retired grants are archived for reconciliation, never used as consent.
    if(!['breadcrumb_shares','breadcrumb_links'].includes(node)) throw new Error('Unsupported legacy metadata path.');
    identifier(uid);
    if(!raw||typeof raw!=='object'||Array.isArray(raw)) throw new Error('Invalid legacy metadata.');
    const encoded=JSON.stringify(raw);
    if(Buffer.byteLength(encoded)>800000) throw new Error('Legacy metadata requires manual reconciliation.');
    const hash=digest(raw),ref=storage.collection('legacy_rtdb').doc(node).collection('records').doc(uid);
    if(!apply) return {validated:true,removed:false};
    await storage.runTransaction(async tx=>{
      const previous=await tx.get(ref);
      if(previous.exists&&previous.data().sourceDigest!==hash) throw new Error('Metadata collision; source retained.');
      if(!previous.exists) tx.set(ref,{sourcePath:`${node}/${uid}`,sourceDigest:hash,payload:raw,archivedAt:Date.now()});
    });
    const saved=(await ref.get()).data();
    if(saved?.sourceDigest!==hash||digest(saved.payload)!==hash) throw new Error('Metadata verification failed; source retained.');
    return clean?cleanup(firebase.database().ref(`${node}/${uid}`),raw,true):{validated:true,removed:false};
  }
  return {history,metadata};
}
module.exports={createLegacyStorageMigration,digest};
