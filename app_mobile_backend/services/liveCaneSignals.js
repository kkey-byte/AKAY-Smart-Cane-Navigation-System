'use strict';
// Restart-safe projections of committed PostgreSQL state. No historical events
// are appended to RTDB, and publication failure never rolls back a cane reading.
function createLiveCaneSignals(pool,usersTable,firebase) {
  async function publish(path,value) {
    await firebase.database().ref(path).transaction(current=>{
      if(current&&current.revision===value.revision) return;
      if(current&&current.observedAt>value.observedAt) return;
      if(path.startsWith('cane_status/')&&current&&current.timestamp>value.timestamp) return;
      return value;
    });
  }
  async function sync() {
    const observedAt=Date.now();
    const disabled=new Map();
    const isDisabled=uid=>{
      if(!disabled.has(uid)) disabled.set(uid,firebase.database().ref(`deleted_location_accounts/${uid}`).get().then(s=>s.val()===true));
      return disabled.get(uid);
    };
    const statuses=await pool.query(`SELECT u.firebase_uid AS uid,a.id AS assignment_id,d.id AS device_id,
      r.id AS reading_id,r.sampled_at,r.battery,r.status
      FROM akay_assignments a JOIN akay_devices d ON d.id=a.device_id AND d.owner_id=a.navigator_id
      JOIN ${usersTable()} u ON u.user_id=a.navigator_id
      JOIN LATERAL (SELECT id,sampled_at,battery,status FROM akay_readings WHERE assignment_id=a.id
        ORDER BY sampled_at DESC,sequence DESC LIMIT 1) r ON true
      WHERE a.ended_at IS NULL`);
    const alerts=await pool.query(`SELECT DISTINCT ON (a.navigator_id) u.firebase_uid AS uid,a.id,a.kind,a.created_at,a.resolved_at
      FROM akay_alerts a JOIN ${usersTable()} u ON u.user_id=a.navigator_id
      WHERE a.kind IN ('sos','motion')
      ORDER BY a.navigator_id,(a.resolved_at IS NULL) DESC,a.created_at DESC`);
    let failed=0;
    for(const row of statuses.rows) {
      if(!row.uid) continue;
      try {if(await isDisabled(row.uid)) continue;await publish(`cane_status/${row.uid}/${row.assignment_id}`,{
        deviceId:row.device_id,assignmentId:row.assignment_id,battery:row.battery,status:row.status,
        timestamp:new Date(row.sampled_at).getTime(),revision:String(row.reading_id),observedAt,
      });} catch(_) {failed++;}
    }
    for(const row of alerts.rows) {
      if(!row.uid) continue;
      const active=row.resolved_at==null;
      try {if(await isDisabled(row.uid)) continue;await publish(`urgent_signals/${row.uid}`,{
        id:row.id,kind:row.kind,active,timestamp:new Date(row.resolved_at??row.created_at).getTime(),
        revision:`${row.id}:${active?'active':'resolved'}`,observedAt,
      });} catch(_) {failed++;}
    }
    return {failed};
  }
  return {sync};
}
module.exports={createLiveCaneSignals};
