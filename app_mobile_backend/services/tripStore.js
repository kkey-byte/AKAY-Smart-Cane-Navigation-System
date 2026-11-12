'use strict';
const Timestamp={fromMillis:value=>value};
const FieldValue={serverTimestamp:()=>Date.now()};
const FieldPath={documentId:()=>'__name__'};
const {ApiError}=require('./pairingService');
const {createHash}=require('node:crypto');
const invalid=message=>{throw new ApiError(400,'invalid_trip',message);};
const identifier=value=>{
  if(typeof value!=='string'||! /^[A-Za-z0-9_-]{1,128}$/.test(value)) invalid('Invalid identifier.');
  return value;
};
const millis=value=>value?.toMillis?value.toMillis():value instanceof Date?value.getTime():value;
function capture(value,now=Date.now()) {
  if(!Number.isSafeInteger(value)||value<0||value>now+30000) invalid('Invalid capture time.');
  return value;
}
function point(raw,now) {
  if(!raw||!Number.isSafeInteger(raw.sequence)||raw.sequence<0||
    !Number.isFinite(raw.latitude)||Math.abs(raw.latitude)>90||
    !Number.isFinite(raw.longitude)||Math.abs(raw.longitude)>180||
    (raw.accuracyMeters!=null&&(!Number.isFinite(raw.accuracyMeters)||raw.accuracyMeters<0))) invalid('Invalid GPS point.');
  return {latitude:raw.latitude,longitude:raw.longitude,sequence:raw.sequence,
    sampledAt:Timestamp.fromMillis(capture(raw.sampledAt,now)),
    ...(raw.accuracyMeters==null?{}:{accuracyMeters:raw.accuracyMeters})};
}
function meters(a,b) {
  if(!a||!b) return 0;
  const r=Math.PI/180, dLat=(b.latitude-a.latitude)*r,dLon=(b.longitude-a.longitude)*r;
  const h=Math.sin(dLat/2)**2+Math.cos(a.latitude*r)*Math.cos(b.latitude*r)*Math.sin(dLon/2)**2;
  return 6371000*2*Math.asin(Math.sqrt(Math.min(1,h)));
}
const location=p=>p?{latitude:p.latitude,longitude:p.longitude}:null;
function wire(data) {
  if(data==null) return data;
  if(data.toMillis) return data.toMillis();
  if(Array.isArray(data)) return data.map(wire);
  if(typeof data==='object') return Object.fromEntries(Object.entries(data).map(([k,v])=>[k,wire(v)]));
  return data;
}
function legacyShape(uid,data,points) {
  const result={...wire(data),ownerId:uid,points:{}};
  for(const p of points||[]) result.points[String(p.sequence).padStart(8,'0')]={latitude:p.latitude,longitude:p.longitude,time:millis(p.sampledAt),accuracy:p.accuracyMeters??0};
  return result;
}
function createTripStore(firebase,{clock=Date.now,recordStore,pool}={}) {
  const persistent=recordStore??require('./postgresRecordStore').createPostgresRecordStore(pool??require('../database/db'));
  const db=()=>persistent;
  const trips=uid=>db().collection('navigators').doc(identifier(uid)).collection('trips');
  const account=uid=>db().collection('navigators').doc(identifier(uid));
  async function writable(tx,uid,ref) {
    const [owner,trip]=await Promise.all([tx.get(account(uid)),tx.get(ref)]);
    if(owner.data()?.historyDeleted||trip.data()?.deleted) throw new ApiError(410,'history_deleted','Location history was deleted.');
    return trip.data();
  }
  async function phoneBatch(uid,id,body) {
    identifier(id);
    if(!Array.isArray(body.points)||body.points.length<1||body.points.length>40) invalid('Upload 1–40 points per request.');
    const startedAt=capture(body.startedAt,clock());
    if(typeof body.name!=='string'||body.name.length>500) invalid('Invalid trip name.');
    const points=body.points.map(p=>point(p,clock()));
    if(points.some(p=>p.sequence>=500||millis(p.sampledAt)<startedAt)||new Set(points.map(p=>p.sequence)).size!==points.length) invalid('Invalid point sequence.');
    const ref=trips(uid).doc(id);
    await db().runTransaction(async tx=>{
      const prior=await writable(tx,uid,ref);
      if(prior&&(prior.sourceType!=='phone_gps'||millis(prior.startedAt)!==startedAt)) invalid('Trip identity cannot change.');
      const refs=points.map(p=>ref.collection('points').doc(String(p.sequence).padStart(8,'0')));
      const old=await Promise.all(refs.map(r=>tx.get(r)));
      if(prior?.status&&prior.status!=='recording'&&!prior.legacyOpen) {
        // Lost final acknowledgement: identical retries remain successful.
        if(points.some((p,i)=>!old[i].exists||millis(old[i].data().sampledAt)!==millis(p.sampledAt)||old[i].data().latitude!==p.latitude||old[i].data().longitude!==p.longitude||old[i].data().accuracyMeters!==p.accuracyMeters))
          throw new ApiError(409,'trip_closed','Trip is already finalized.');
        return;
      }
      if(!prior) tx.set(ref,{ownerId:uid,name:body.name,startedAt:Timestamp.fromMillis(startedAt),endedAt:null,status:'recording',sourceType:'phone_gps',deviceId:null,assignmentId:null,
        origin:null,destination:null,distanceMeters:0,durationSeconds:0,pointCount:0,syncedAt:FieldValue.serverTimestamp()});
      else if(prior.legacyOpen) tx.update(ref,{status:'recording',endedAt:null});
      points.forEach((p,i)=>{
        const previous=old[i].data();
        if(!previous||millis(previous.sampledAt)<millis(p.sampledAt)) tx.set(refs[i],{...p,sourceType:'phone_gps',receivedAt:FieldValue.serverTimestamp()});
        else if(millis(previous.sampledAt)===millis(p.sampledAt)&&(previous.latitude!==p.latitude||previous.longitude!==p.longitude)) invalid('Conflicting point retry.');
      });
    });
    return {accepted:true};
  }
  async function finalizePhone(uid,id,body,{legacyImport=false,legacyOpen=false}={}) {
    const ref=trips(uid).doc(identifier(id));
    if(!Number.isInteger(body.pointCount)||body.pointCount<1||body.pointCount>500||!['recording','completed','interrupted'].includes(body.status)) invalid('Invalid summary.');
    const endedAt=body.endedAt==null?null:capture(body.endedAt,clock());
    if((body.status==='recording')!==(endedAt===null)) invalid('Trip end time required.');
    await db().runTransaction(async tx=>{
      const prior=await writable(tx,uid,ref);
      if(!prior||prior.sourceType!=='phone_gps') invalid('Phone trip required.');
      const rows=await tx.get(ref.collection('points').orderBy('sequence').limit(501));
      const points=rows.docs.map(d=>d.data());
      if(points.length!==body.pointCount||points.some((p,i)=>p.sequence!==i||(i>0&&millis(p.sampledAt)<millis(points[i-1].sampledAt)))) throw new ApiError(409,'upload_incomplete','Upload all ordered points before finalizing.');
      const lastSampledAt=capture(body.lastSampledAt??millis(points.at(-1).sampledAt),clock());
      if(lastSampledAt<millis(points.at(-1).sampledAt)) invalid('Freshness precedes the last recorded point.');
      if(endedAt!=null&&(endedAt<millis(prior.startedAt)||endedAt<lastSampledAt)) invalid('End precedes capture.');
      if(prior.status!=='recording') {
        if(prior.status!==body.status||millis(prior.endedAt)!==endedAt) throw new ApiError(409,'trip_closed','Trip is already finalized.');
        return;
      }
      if(lastSampledAt<millis(prior.lastSampledAt??prior.startedAt)) throw new ApiError(409,'stale_summary','A newer location snapshot is already saved.');
      let distance=0;
      for(let i=1;i<points.length;i++) distance+=meters(points[i-1],points[i]);
      tx.update(ref,{status:body.status,endedAt:endedAt==null?null:Timestamp.fromMillis(endedAt),
        origin:location(points[0]),destination:location(points.at(-1)),pointCount:points.length,distanceMeters:distance,
        durationSeconds:Math.max(0,Math.floor(((endedAt??lastSampledAt)-millis(prior.startedAt))/1000)),
        lastSampledAt:Timestamp.fromMillis(lastSampledAt),syncedAt:FieldValue.serverTimestamp()});
      if(legacyImport) tx.update(ref,{migratedFrom:'breadcrumb_trips',legacyOpen});
      else tx.update(ref,{legacyOpen:false});
    });
    return {accepted:true};
  }
  async function list(uid,{limit=100,cursor,sourceType,deviceId,assignmentId}={}) {
    if(!Number.isInteger(limit)||limit<1||limit>1000) invalid('Invalid page size.');
    let query=trips(uid);
    if(sourceType) query=query.where('sourceType','==',sourceType);
    if(deviceId) query=query.where('deviceId','==',identifier(deviceId));
    if(assignmentId) query=query.where('assignmentId','==',identifier(assignmentId));
    query=query.orderBy('startedAt','desc').orderBy(FieldPath.documentId(),'desc');
    if(cursor) {
      let value;
      try { value=JSON.parse(Buffer.from(cursor,'base64url').toString()); } catch(_) {invalid('Invalid cursor.');}
      if(!Array.isArray(value)||value.length!==2) invalid('Invalid cursor.');
      query=query.startAfter(Timestamp.fromMillis(capture(value[0],clock())),identifier(value[1]));
    }
    const rows=await query.limit(limit).get();
    const last=rows.docs.at(-1);
    return {trips:Object.fromEntries(rows.docs.filter(d=>!d.data().deleted).map(d=>[d.id,legacyShape(uid,d.data())])),
      nextCursor:rows.size===limit?Buffer.from(JSON.stringify([millis(last.data().startedAt),last.id])).toString('base64url'):null};
  }
  async function detail(uid,id) {
    const ref=trips(uid).doc(identifier(id)),doc=await ref.get();
    if(!doc.exists||doc.data().deleted) return null;
    const points=[];
    let query=ref.collection('points').orderBy('sequence');
    while(true) {
      const page=await query.limit(500).get();
      points.push(...page.docs.map(d=>d.data()));
      if(page.size<500) break;
      query=ref.collection('points').orderBy('sequence').startAfter(page.docs.at(-1));
    }
    // A deletion that raced the point reads must not return cached coordinates.
    if((await ref.get()).data()?.deleted) return null;
    return legacyShape(uid,doc.data(),points);
  }
  async function preview(uid,id) {
    const ref=trips(uid).doc(identifier(id)),doc=await ref.get();
    if(!doc.exists||doc.data().deleted) return null;
    const rows=await ref.collection('points').orderBy('sequence','desc').limit(500).get();
    if((await ref.get()).data()?.deleted) return null;
    return legacyShape(uid,doc.data(),rows.docs.map(d=>d.data()).sort((a,b)=>a.sequence-b.sequence));
  }
  async function remove(uid,id) {
    const ref=trips(uid).doc(identifier(id));
    // Keep a tombstone to reject durable outboxes and migration retries.
    await ref.set({deleted:true,startedAt:Timestamp.fromMillis(0),endedAt:null});
    await db().recursiveDelete(ref.collection('points'));
    await firebase.database().ref(`breadcrumb_trips/${uid}/${id}`).remove();
    return {deleted:true};
  }
  async function removeAccount(uid) {
    await account(uid).set({historyDeleted:true},{merge:true});
    await firebase.database().ref(`deleted_location_accounts/${uid}`).set(true);
    const rows=await trips(uid).get();
    for(const doc of rows.docs) await remove(uid,doc.id);
    await firebase.database().ref(`breadcrumb_trips/${uid}`).remove();
    await firebase.database().ref(`phone_location/${uid}`).remove();
    await firebase.database().ref(`cane_location/${uid}`).remove();
    await firebase.database().ref(`cane_status/${uid}`).remove();
    await firebase.database().ref(`urgent_signals/${uid}`).remove();
    await firebase.database().ref(`destination_assignments/${uid}`).remove();
    await firebase.database().ref(`destination_progress/${uid}`).remove();
    return {deleted:true};
  }
  async function retain(days) {
    if(days==null||days==='') return {enabled:false};
    if(!Number.isInteger(Number(days))||Number(days)<=0) invalid('Retention days must be a positive integer.');
    const cutoff=Timestamp.fromMillis(clock()-Number(days)*86400000);
    const rows=await db().collectionGroup('trips').where('endedAt','<',cutoff).limit(100).get();
    for(const doc of rows.docs) await remove(doc.ref.parent.parent.id,doc.id);
    return {enabled:true,deleted:rows.size};
  }
  async function migrate(uid,id,raw,{apply=false}={}) {
    identifier(uid); identifier(id);
    if(!raw||raw.ownerId!==uid||typeof raw.name!=='string'||!['recording','completed','interrupted'].includes(raw.status)) invalid('Legacy trip requires reconciliation.');
    const values=Object.entries(raw.points||{}).sort(([a],[b])=>a.localeCompare(b)).map(([,v])=>v);
    if(!values.length||values.length>500) invalid('Legacy point count requires reconciliation.');
    const startedAt=capture(raw.startedAt,clock());
    const points=values.map((v,sequence)=>point({...v,sequence,sampledAt:v.time,accuracyMeters:v.accuracy},clock()));
    if(points.some((p,i)=>millis(p.sampledAt)<startedAt||(i>0&&millis(p.sampledAt)<millis(points[i-1].sampledAt)))) invalid('Legacy capture order requires reconciliation.');
    const endedAt=raw.endedAt??millis(points.at(-1).sampledAt);
    capture(endedAt,clock());
    if(endedAt<millis(points.at(-1).sampledAt)) invalid('Legacy end precedes capture.');
    const prior=await trips(uid).doc(id).get();
    if(prior.data()?.deleted) return {skipped:true};
    if(prior.exists&&(prior.data().sourceType!=='phone_gps'||millis(prior.data().startedAt)!==startedAt)) invalid('Legacy identity collision.');
    if(prior.data()?.migratedFrom==='breadcrumb_trips') return {validated:true,alreadyMigrated:true};
    if(!apply) return {validated:true,pointCount:points.length};
    for(let offset=0;offset<points.length;offset+=40) await phoneBatch(uid,id,{name:raw.name,startedAt,
      points:points.slice(offset,offset+40).map(p=>({...p,sampledAt:millis(p.sampledAt)}))});
    const status=raw.status==='recording'?'interrupted':raw.status;
    await finalizePhone(uid,id,{status,pointCount:points.length,endedAt},{legacyImport:true,legacyOpen:raw.status==='recording'});
    const result=await detail(uid,id);
    if(result.pointCount!==points.length||Object.keys(result.points).length!==points.length) throw new Error('Migration validation failed. Legacy retained.');
    return {validated:true,pointCount:points.length};
  }
  async function cane(uid,deviceId,assignmentId,body) {
    identifier(body.sessionId);
    if(!['start','point','end'].includes(body.event)) invalid('Explicit session event required.');
    const p=point(body,clock());
    const id='cane_'+createHash('sha256').update(`${deviceId}:${assignmentId}:${body.sessionId}`).digest('hex');
    const ref=trips(uid).doc(id),pr=ref.collection('points').doc(String(p.sequence).padStart(12,'0'));
    await db().runTransaction(async tx=>{
      const prior=await writable(tx,uid,ref),old=await tx.get(pr);
      if(prior&&(prior.sourceType!=='cane_gps'||prior.deviceId!==deviceId||prior.assignmentId!==assignmentId)) invalid('Cane trip identity cannot change.');
      if(old.exists) {
        const saved=old.data();
        if(saved.event!==body.event||millis(saved.sampledAt)!==millis(p.sampledAt)||saved.latitude!==p.latitude||saved.longitude!==p.longitude) invalid('Conflicting GPS retry.');
        return;
      }
      if((!prior&&(body.event!=='start'||p.sequence!==0))||(prior&&(body.event==='start'||prior.status!=='recording'||p.sequence!==prior.pointCount||millis(p.sampledAt)<millis(prior.lastSampledAt))))
        throw new ApiError(409,'session_order','Replay the pending session events in sequence.');
      tx.set(pr,{...p,sourceType:'cane_gps',event:body.event,receivedAt:FieldValue.serverTimestamp()});
      tx.set(ref,{ownerId:uid,name:'Cane track',sourceType:'cane_gps',deviceId,assignmentId,
        startedAt:prior?.startedAt??p.sampledAt,endedAt:body.event==='end'?p.sampledAt:null,status:body.event==='end'?'completed':'recording',
        origin:prior?.origin??location(p),destination:location(p),distanceMeters:(prior?.distanceMeters??0)+meters(prior?.destination,p),
        durationSeconds:Math.floor((millis(p.sampledAt)-millis(prior?.startedAt??p.sampledAt))/1000),pointCount:p.sequence+1,
        lastSampledAt:p.sampledAt,syncedAt:FieldValue.serverTimestamp()});
    });
    return {accepted:true,tripId:id};
  }
  return {phoneBatch,finalizePhone,list,detail,preview,remove,removeAccount,retain,cane,migrate};
}
module.exports={createTripStore,identifier,capture,point,meters,millis,wire};
