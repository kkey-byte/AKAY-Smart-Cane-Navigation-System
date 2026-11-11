'use strict';
const {ApiError}=require('./pairingService');
const timestamp=value=>{const time=typeof value==='number'?value:Date.parse(value);return Number.isFinite(time)?time:null;};
const coordinate=(value,bound)=>{if(value==null||typeof value==='boolean'||value==='') return null;const n=Number(value);return Number.isFinite(n)&&Math.abs(n)<=bound?n:null;};
function createDashboardService(pool,authorize,firebase,{clock=Date.now,tripStore}={}) {
  const trips=tripStore??require('./tripStore').createTripStore(firebase,{clock});
  // Ephemeral activity only; history uses PostgreSQL and latest GPS uses RTDB.
  const activity=new Map();
  function presence(actor,active) {
    if(actor.role!=='visually_impaired') throw new ApiError(403,'role_required','Navigator activity only.');
    if(typeof active!=='boolean') throw new ApiError(400,'invalid_activity','App activity must be true or false.');
    const now=clock();
    for(const [uid,item] of activity) if(now-item.time>3600000) activity.delete(uid);
    activity.set(actor.uid,{active,time:now});
    return {accepted:true};
  }
  async function snapshot(actor,uid) {
    const navigator=await authorize(actor,uid);
    const now=clock(),errors=[];
    let navigation=null,points=[],location=null;
    try {
      const row=(await pool.query(`SELECT sessionid,destinationlatitude,destinationlongitude,destinationaddress,
        status,starttime,endtime,updatedat FROM navigationsessions WHERE user_id=$1
        ORDER BY starttime DESC NULLS LAST,updatedat DESC NULLS LAST LIMIT 1`,[navigator.id])).rows[0];
      if(row) navigation={id:row.sessionid,status:row.status,destination:row.destinationaddress||null,
        latitude:coordinate(row.destinationlatitude,90),longitude:coordinate(row.destinationlongitude,180),
        updatedAt:row.updatedat,endedAt:row.endtime,
        active:['Active','Paused'].includes(row.status)&&timestamp(row.updatedat)!=null&&now-timestamp(row.updatedat)>=-30000&&now-timestamp(row.updatedat)<=120000};
      if(navigation&&['Active','Paused'].includes(navigation.status)&&!navigation.active) errors.push('Saved route status is not updating. Showing the last destination.');
    } catch(_) {errors.push('Saved navigation details are unavailable.');}
    try {
      const read=async fetch=>{
        let timer;
        try{return await Promise.race([fetch(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('GPS read timeout')),4000);})]);}
        finally{clearTimeout(timer);}
      };
      const [history,phoneRead]=await Promise.allSettled([
        read(async()=>{
          const page=await trips.list(uid,{limit:1});
          const id=Object.keys(page.trips)[0];
          return id?trips.preview(uid,id):null;
        }),
        read(()=>firebase.database().ref(`phone_location/${uid}`).get()),
      ]);
      if(history.status==='rejected') errors.push('Recorded path is unavailable.');
      if(phoneRead.status==='rejected') errors.push('Phone GPS is unavailable.');
      const trip=history.status==='fulfilled'?history.value:null;
      points=Object.values(trip?.points||{}).filter(point=>coordinate(point?.latitude,90)!=null&&coordinate(point?.longitude,180)!=null&&typeof point.time==='number'&&Number.isFinite(point.time)&&point.time>=0&&point.time<=now+30000)
        .sort((a,b)=>a.time-b.time).slice(-500).map(point=>({latitude:Number(point.latitude),longitude:Number(point.longitude),time:point.time}));
      if(points.length) location={...points.at(-1),heading:null};
      const phone=phoneRead.status==='fulfilled'?phoneRead.value.val():null;
      if(phone&&coordinate(phone.latitude,90)!=null&&coordinate(phone.longitude,180)!=null&&typeof phone.timestamp==='number'&&Number.isFinite(phone.timestamp)&&phone.timestamp>=0&&phone.timestamp<=now+30000&&(!location||phone.timestamp>location.time)) {
        location={latitude:Number(phone.latitude),longitude:Number(phone.longitude),time:phone.timestamp,
          heading:typeof phone.heading==='number'&&phone.heading>=0&&phone.heading<=360?phone.heading:null};
      }
    } catch(_) {errors.push('Live GPS history is unavailable.');}
    const seen=activity.get(uid);
    const presence={state:seen?(seen.active&&now-seen.time<=45000?'active':'inactive'):'unknown',updatedAt:seen?new Date(seen.time).toISOString():null};
    await authorize(actor,uid); // Revoke during reads must hide the entire result.
    return {navigator:{uid,name:navigator.name||null},navigation,location,points,presence,errors,serverTime:new Date(now).toISOString()};
  }
  return {presence,snapshot};
}
module.exports={createDashboardService};
