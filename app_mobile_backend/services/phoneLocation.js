'use strict';
const {ApiError}=require('./pairingService');
const validTime=(value,now)=>Number.isSafeInteger(value)&&value>=now-45000&&value<=now+30000;
function createPhoneLocationService(pool,usersTable,firebase,{clock=Date.now}={}) {
  async function owned(actor,operation) {
    if(actor.role!=='visually_impaired') throw new ApiError(403,'navigator_required','Only a navigator can publish phone location.');
    const db=await pool.connect();
    try {
      await db.query('BEGIN');
      const profile=await db.query(`SELECT user_id FROM ${usersTable()} WHERE user_id=$1 AND firebase_uid=$2
        AND role='visually_impaired' FOR SHARE`,[actor.id,actor.uid]);
      if(profile.rows.length!==1) throw new ApiError(403,'identity_invalid','Navigator identity unavailable.');
      const deleted=await firebase.database().ref(`deleted_location_accounts/${actor.uid}`).get();
      if(deleted.val()) throw new ApiError(410,'history_deleted','Location sharing is disabled for this account.');
      const result=await operation(firebase.database().ref(`phone_location/${actor.uid}`));
      await db.query('COMMIT');return result;
    } catch(error) {await db.query('ROLLBACK');throw error;}
    finally {db.release();}
  }
  async function publish(actor,body) {
    const now=clock();
    const allowed=new Set(['latitude','longitude','timestamp','source','speed','heading','accuracy']);
    if(!body||Object.keys(body).some(key=>!allowed.has(key))||body.source!=='phone_gps'||
      !Number.isFinite(body.latitude)||Math.abs(body.latitude)>90||!Number.isFinite(body.longitude)||Math.abs(body.longitude)>180||
      !validTime(body.timestamp,now)||
      (body.heading!=null&&(!Number.isFinite(body.heading)||body.heading<0||body.heading>360))||
      ['speed','accuracy'].some(key=>body[key]!=null&&(!Number.isFinite(body[key])||body[key]<0)))
      throw new ApiError(400,'invalid_location','A valid fresh phone location is required.');
    return owned(actor,async ref=>{
      if(!validTime(body.timestamp,clock())) return {accepted:true,applied:false};
      const result=await ref.transaction(old=>{
        if(old&&Number.isFinite(old.timestamp)&&old.timestamp>=body.timestamp) return;
        return {...body,source:'phone_gps',enabled:true,receivedAt:{'.sv':'timestamp'}};
      });
      return {accepted:true,applied:result.committed===true};
    });
  }
  async function clear(actor,body) {
    if(!validTime(body?.stoppedAt,clock())) throw new ApiError(400,'invalid_stop','A fresh stop timestamp is required.');
    return owned(actor,async ref=>{
      await ref.transaction(old=>{
        if(old&&Number.isFinite(old.timestamp)&&old.timestamp>body.stoppedAt) return;
        // Preserve a coordinate-free watermark: delayed writes cannot resurrect
        // a paused source, and an old stop cannot erase a newly resumed source.
        return {source:'phone_gps',enabled:false,timestamp:body.stoppedAt,receivedAt:{'.sv':'timestamp'}};
      });
      return {accepted:true};
    });
  }
  return {publish,clear};
}
module.exports={createPhoneLocationService};
