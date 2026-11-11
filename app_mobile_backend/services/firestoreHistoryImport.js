'use strict';
// Operator-only source reader. Runtime tracking/history never calls Firestore.
const {identifier,wire,point,capture}=require('./tripStore');
const {digest}=require('./legacyStorageMigration');
function createFirestoreHistoryImport(firebase,storage,{clock=Date.now}={}) {
  const source=()=>firebase.firestore();
  async function record(ref,value,apply) {
    const fingerprint=digest(value);
    if(!apply) return {validated:true};
    await storage.runTransaction(async tx=>{
      const existing=await tx.get(ref);
      if(existing.exists) {
        if(existing.data().importDigest!==fingerprint) throw new Error('Import collision; reconcile the destination.');
        return;
      }
      tx.set(ref,{...value,importDigest:fingerprint});
    });
    return {validated:true};
  }
  async function trip(uid,id,raw,rawPoints,{apply=false}={}) {
    identifier(uid);identifier(id);
    const summary=wire(raw),points=rawPoints.map(wire);
    if(summary.ownerId!==uid&&!summary.deleted) throw new Error('Trip ownership mismatch.');
    const ref=storage.collection('navigators').doc(uid).collection('trips').doc(id);
    if(summary.deleted) return record(ref,{deleted:true,startedAt:0,endedAt:null},apply);
    if(!['phone_gps','cane_gps'].includes(summary.sourceType)||!['recording','completed','interrupted'].includes(summary.status)||
      typeof summary.name!=='string'||summary.name.length>500||!Number.isInteger(summary.pointCount)||summary.pointCount<0||
      (summary.status==='recording'?summary.pointCount>points.length:summary.pointCount!==points.length)||
      summary.sourceType==='phone_gps'&&points.length>500) throw new Error('Invalid source summary.');
    capture(summary.startedAt,clock());
    if(summary.endedAt!=null) capture(summary.endedAt,clock());
    if((summary.status==='recording')!==(summary.endedAt==null)) throw new Error('Invalid source end time.');
    // A recording may have an unfinished point batch: keep its original summary
    // count and validate against its actual points below, without fabricating data.
    points.sort((a,b)=>a.sequence-b.sequence);
    points.forEach((p,i)=>{
      point(p,clock());
      if(p.sequence!==i||p.sampledAt<summary.startedAt||i>0&&p.sampledAt<points[i-1].sampledAt||
        summary.endedAt!=null&&p.sampledAt>summary.endedAt) throw new Error('Invalid source captures.');
    });
    if(summary.sourceType==='cane_gps') {identifier(summary.deviceId);identifier(summary.assignmentId);}
    const fingerprint=digest({summary,points});
    if(!apply) return {validated:true,pointCount:points.length};
    await storage.runTransaction(async tx=>{
      const account=await tx.get(storage.collection('navigators').doc(uid));
      const existing=await tx.get(ref);
      if(account.data()?.historyDeleted) throw new Error('Destination account history is deleted.');
      if(existing.exists) {
        if(existing.data().importDigest!==fingerprint) throw new Error('Import collision; source retained.');
        return;
      }
      tx.set(ref,{...summary,importDigest:fingerprint});
      for(const p of points) tx.set(ref.collection('points').doc(String(p.sequence).padStart(summary.sourceType==='cane_gps'?12:8,'0')),p);
    });
    // Verify committed data separately before reporting a successful import.
    const saved=(await ref.get()).data();
    const savedPoints=[];
    let query=ref.collection('points').orderBy('sequence');
    while(true) {
      const page=await query.limit(500).get();savedPoints.push(...page.docs.map(d=>d.data()));
      if(page.size<500) break;
      query=ref.collection('points').orderBy('sequence').startAfter(page.docs.at(-1));
    }
    const {importDigest,...savedSummary}=saved;
    if(importDigest!==fingerprint||digest({summary:savedSummary,points:savedPoints})!==fingerprint)
      throw new Error('Destination changed or failed verification; source retained.');
    return {validated:true,pointCount:points.length};
  }
  async function account(uid,{apply=false}={}) {
    identifier(uid);
    const doc=await source().collection('navigators').doc(uid).get();
    if(!doc.exists) return {validated:true};
    return record(storage.collection('navigators').doc(uid),wire(doc.data()),apply);
  }
  async function archive(node,uid,raw,{apply=false}={}) {
    if(!['breadcrumb_shares','breadcrumb_links'].includes(node)) throw new Error('Unsupported archive.');
    identifier(uid);
    return record(storage.collection('legacy_rtdb').doc(node).collection('records').doc(uid),wire(raw),apply);
  }
  return {trip,account,archive};
}
module.exports={createFirestoreHistoryImport};
