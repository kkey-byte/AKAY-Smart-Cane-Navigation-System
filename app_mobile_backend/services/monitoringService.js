'use strict';
const time=value=>typeof value==='number'?value:Date.parse(value);
const coordinate=(value,bound)=>typeof value==='number'&&Number.isFinite(value)&&Math.abs(value)<=bound;
function createMonitoringService(pool,firebase,trips,{clock=Date.now,timeoutMs=4000}={}) {
  async function bounded(promise) {
    let timer;
    try {return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Monitoring timeout')),timeoutMs);})]);}
    finally {clearTimeout(timer);}
  }
  function sample(raw,source,now,assignment) {
    if(!raw||raw.source!==source||raw.enabled===false||!coordinate(raw.latitude,90)||!coordinate(raw.longitude,180)||
      !Number.isSafeInteger(raw.timestamp)||raw.timestamp<0||raw.timestamp>now+30000) return null;
    if(assignment&&(!Number.isFinite(time(assignment.started_at))||raw.deviceId!==assignment.id||raw.assignmentId!==assignment.assignment_id||raw.timestamp<time(assignment.started_at))) return null;
    return {latitude:raw.latitude,longitude:raw.longitude,time:raw.timestamp,source,
      live:raw.connected!==false&&now-raw.timestamp<=45000,
      heading:typeof raw.heading==='number'&&Number.isFinite(raw.heading)&&raw.heading>=0&&raw.heading<=360?raw.heading:null,
      ...(assignment?{deviceId:assignment.id,assignmentId:assignment.assignment_id}:{}),
      status:['idle','moving','fault'].includes(raw.status)?raw.status:null};
  }
  async function read(navigator,{history=true}={}) {
    const now=clock(),uid=navigator.uid,errors=[];
    const [phoneResult,assignmentsResult]=await Promise.allSettled([
      bounded(Promise.resolve().then(()=>firebase.database().ref(`phone_location/${uid}`).get())),
      bounded(Promise.resolve().then(()=>pool.query(`SELECT d.id,d.serial,a.id AS assignment_id,a.started_at FROM akay_assignments a
        JOIN akay_devices d ON d.id=a.device_id AND d.owner_id=a.navigator_id
        WHERE a.navigator_id=$1 AND a.ended_at IS NULL ORDER BY a.started_at DESC,a.id DESC`,[navigator.id]))),
    ]);
    if(phoneResult.status==='rejected') errors.push('Phone GPS is unavailable.');
    if(assignmentsResult.status==='rejected') errors.push('Cane assignments are unavailable.');
    const phone=phoneResult.status==='fulfilled'?sample(phoneResult.value.val(),'phone_gps',now):null;
    const assignments=assignmentsResult.status==='fulfilled'?assignmentsResult.value.rows:[];
    const readings=await Promise.allSettled(assignments.map(async assignment=>{
      const snapshot=await bounded(firebase.database().ref(`cane_location/${uid}/${assignment.assignment_id}`).get());
      const location=sample(snapshot.val(),'cane_gps',now,assignment);
      return location?{...assignment,location}:null;
    }));
    if(readings.some(r=>r.status==='rejected')) errors.push('Cane GPS is unavailable.');
    const devices=readings.filter(r=>r.status==='fulfilled'&&r.value).map(r=>r.value)
      .sort((a,b)=>b.location.time-a.location.time||String(a.assignment_id).localeCompare(String(b.assignment_id)));
    // Preserve the phone-first workflow; use a currently assigned cane only
    // when phone GPS has no fresh live sample. Never splice their route points.
    let location=phone?.live?phone:devices.find(d=>d.location.live)?.location??
      [phone,...devices.map(d=>d.location)].filter(Boolean).sort((a,b)=>b.time-a.time)[0]??null;
    let trip=null,tripId=null,points=[];
    if(history) {
      try {
        const source=location?.source??'phone_gps';
        const page=await bounded(trips.list(uid,{limit:1,sourceType:source,
          ...(source==='cane_gps'?{deviceId:location.deviceId,assignmentId:location.assignmentId}:{})}));
        const id=Object.keys(page.trips)[0];
        tripId=id??null;
        trip=id?await bounded((trips.preview??trips.detail)(uid,id)):null;
        const matching=trip&&(!trip.sourceType||trip.sourceType===source)&&
          (source!=='cane_gps'||(trip.deviceId===location.deviceId&&trip.assignmentId===location.assignmentId));
        if(!matching) trip=null;
        const ended=time(trip?.endedAt);
        // A new live session must not draw an old completed path as its route.
        const latestCapture=time(trip?.lastSampledAt??Object.values(trip?.points||{}).at(-1)?.time??trip?.startedAt);
        const belongs=trip&&(!location||!location.live||
          (location.time>=time(trip.startedAt||0)&&
            (trip.status==='recording'
              ? (!Number.isFinite(latestCapture)||location.time-latestCapture<=90000)
              : (!Number.isFinite(ended)||location.time<=ended))));
        if(belongs) points=Object.values(trip.points||{}).filter(p=>coordinate(p?.latitude,90)&&coordinate(p?.longitude,180)&&
          Number.isSafeInteger(p.time)&&p.time>=0&&p.time<=now+30000).sort((a,b)=>a.time-b.time).slice(-500)
          .map(p=>({latitude:p.latitude,longitude:p.longitude,time:p.time}));
        if(!location&&points.length) location={...points.at(-1),source,live:false,recordedOnly:true,heading:null};
      } catch(_) {errors.push('Recorded path is unavailable.');}
    }
    return {location,points,trip:trip?{id:tripId,status:trip.status,sourceType:trip.sourceType}:null,
      phoneLocation:phone?{...phone,time:new Date(phone.time).toISOString(),fresh:phone.live}:null,devices,errors};
  }
  return {read,bounded};
}
module.exports={createMonitoringService};
