'use strict';
const {ApiError}=require('./pairingService');
const timestamp=value=>{const time=typeof value==='number'?value:Date.parse(value);return Number.isFinite(time)?time:null;};
const coordinate=(value,bound)=>{if(value==null||typeof value==='boolean'||value==='') return null;const n=Number(value);return Number.isFinite(n)&&Math.abs(n)<=bound?n:null;};
function createDashboardService(pool,authorize,firebase,{clock=Date.now,tripStore,timeoutMs=4000}={}) {
  const trips=tripStore??require('./tripStore').createTripStore(firebase,{clock});
  const monitoring=require('./monitoringService').createMonitoringService(pool,firebase,trips,{clock,timeoutMs});
  // Ephemeral app activity only. GPS history remains in its existing database.
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
    let navigation=null,points=[],location=null,recordedTrip=null;
    const [saved,live]=await Promise.allSettled([
      monitoring.bounded(Promise.resolve().then(()=>pool.query(`SELECT sessionid,destinationlatitude,destinationlongitude,destinationaddress,
        status,starttime,endtime,updatedat FROM navigationsessions WHERE user_id=$1
        ORDER BY starttime DESC NULLS LAST,updatedat DESC NULLS LAST LIMIT 1`,[navigator.id]))),
      monitoring.read(navigator),
    ]);
    try {
      if(saved.status==='rejected') throw new Error('Navigation unavailable');
      const row=saved.value.rows[0];
      if(row) navigation={id:row.sessionid,status:row.status,destination:row.destinationaddress||null,
        latitude:coordinate(row.destinationlatitude,90),longitude:coordinate(row.destinationlongitude,180),
        updatedAt:row.updatedat,endedAt:row.endtime,
        active:['Active','Paused'].includes(row.status)&&timestamp(row.updatedat)!=null&&now-timestamp(row.updatedat)>=-30000&&now-timestamp(row.updatedat)<=120000};
      if(navigation&&['Active','Paused'].includes(navigation.status)&&!navigation.active) errors.push('Saved route status is not updating. Showing the last destination.');
    } catch(_) {errors.push('Saved navigation details are unavailable.');}
    if(live.status==='fulfilled') {
      location=live.value.location;points=live.value.points;recordedTrip=live.value.trip;
      errors.push(...live.value.errors);
    } else errors.push('Live GPS monitoring is unavailable.');
    const seen=activity.get(uid);
    const presence={state:seen?(seen.active&&now-seen.time<=45000?'active':'inactive'):'unknown',updatedAt:seen?new Date(seen.time).toISOString():null};
    await authorize(actor,uid); // Revoke during reads must hide the entire result.
    return {navigator:{uid,name:navigator.name||null},navigation,location,points,recordedTrip,presence,errors,serverTime:new Date(now).toISOString()};
  }
  return {presence,snapshot};
}
module.exports={createDashboardService};
