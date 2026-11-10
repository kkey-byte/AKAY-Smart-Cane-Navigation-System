'use strict';
const {ApiError}=require('./pairingService');
function createLocationRemoval(pool,usersTable,trips) {
  return async function removeAccount(uid) {
    const rows=await pool.query(`SELECT user_id AS id FROM ${usersTable()} WHERE firebase_uid=$1 AND role='visually_impaired'`,[uid]);
    if(rows.rows.length!==1) throw new ApiError(404,'not_available','Navigator unavailable.');
    const db=await pool.connect();
    try {
      await db.query('BEGIN');
      const locked=await db.query(`SELECT user_id FROM ${usersTable()} WHERE user_id=$1 AND firebase_uid=$2
        AND role='visually_impaired' FOR UPDATE`,[rows.rows[0].id,uid]);
      if(locked.rows.length!==1) throw new ApiError(404,'not_available','Navigator unavailable.');
      await db.query(`SELECT d.id FROM akay_devices d JOIN akay_assignments a ON a.device_id=d.id
        WHERE a.navigator_id=$1 AND a.ended_at IS NULL ORDER BY d.id FOR UPDATE OF d`,[rows.rows[0].id]);
      // Synchronize with phone publishers and machine ingestion before clearing
      // Firebase, so an in-flight live write cannot resurrect erased data.
      await trips.removeAccount(uid);
      await db.query(`UPDATE akay_device_credentials SET revoked_at=clock_timestamp() WHERE revoked_at IS NULL
        AND device_id IN(SELECT device_id FROM akay_assignments WHERE navigator_id=$1 AND ended_at IS NULL)`,[rows.rows[0].id]);
      await db.query('UPDATE akay_assignments SET ended_at=clock_timestamp() WHERE navigator_id=$1 AND ended_at IS NULL',[rows.rows[0].id]);
      // Preserve sensor/alert rows; erase their location-bearing columns only.
      await db.query('UPDATE akay_readings SET latitude=NULL,longitude=NULL WHERE navigator_id=$1',[rows.rows[0].id]);
      await db.query(`UPDATE navigationsessions SET originlatitude=NULL,originlongitude=NULL,originaddress=NULL,
        destinationlatitude=NULL,destinationlongitude=NULL,destinationaddress=NULL WHERE user_id=$1`,[rows.rows[0].id]);
      await db.query('COMMIT');
    } catch(error) {await db.query('ROLLBACK');throw error;}
    finally {db.release();}
    return {deleted:true};
  };
}
module.exports={createLocationRemoval};
