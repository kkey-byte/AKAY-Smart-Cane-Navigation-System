'use strict';
const {ApiError}=require('./pairingService');
const {capture,identifier}=require('./tripStore');
function createCaneGps(pairing,pool,usersTable,trips,firebase,{clock=Date.now}={}) {
  return async function ingest(deviceId,key,body) {
    identifier(body.assignmentId);
    const sampledAt=capture(body.sampledAt,clock());
    return pairing.hardware(deviceId,key,async(db,_device,_credential,current)=>{
      // Resolve historical assignment AND custody at capture, never current owner.
      const assignment=(await db.query(`SELECT a.*,u.firebase_uid AS uid FROM akay_assignments a
        JOIN ${usersTable()} u ON u.user_id=a.navigator_id
        WHERE a.id=$1 AND a.device_id=$2 AND a.started_at<=$3
        AND (a.ended_at IS NULL OR a.ended_at>$3)
        AND EXISTS(SELECT 1 FROM akay_ownership_history h WHERE h.device_id=a.device_id
          AND h.owner_id=a.navigator_id AND h.started_at<=$3 AND (h.ended_at IS NULL OR h.ended_at>$3))`,
      [body.assignmentId,deviceId,new Date(sampledAt)])).rows[0];
      if(!assignment?.uid) throw new ApiError(403,'assignment_invalid','No valid device custody and assignment at capture.');
      const result=await trips.cane(assignment.uid,deviceId,assignment.id,body);
      // Independent of Flutter. Old assignment uploads are history only.
      if(current?.id===assignment.id&&clock()-sampledAt<=45000) {
        await firebase.database().ref(`cane_location/${assignment.uid}/${assignment.id}`).transaction(old=>{
          if(old&&old.timestamp>=sampledAt) return;
          return {latitude:body.latitude,longitude:body.longitude,timestamp:sampledAt,
            receivedAt:{'.sv':'timestamp'},source:'cane_gps',deviceId,assignmentId:assignment.id,
            connected:body.event!=='end',status:body.event==='end'?'idle':'moving'};
        });
      }
      return result;
    });
  };
}
module.exports={createCaneGps};
