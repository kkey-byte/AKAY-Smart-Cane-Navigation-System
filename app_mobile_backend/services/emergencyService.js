'use strict';
const {ApiError,hash}=require('./pairingService');
const fail=(status,code,message)=>{throw new ApiError(status,code,message);};
const uuid=value=>typeof value==='string'&&/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value);
const role=actor=>{if(actor.role!=='caregiver') fail(403,'caregiver_required','A caregiver account is required.');};
function createEmergencyService(pool,usersTable,firebase,{pushTimeoutMs=10000}={}) {
  async function send(message) {
    let timer;
    try {
      return await Promise.race([Promise.resolve().then(()=>firebase.messaging().send(message)),new Promise((_,reject)=>{
        timer=setTimeout(()=>reject(new Error('Push delivery receipt timed out.')),pushTimeoutMs);
      })]);
    } finally {clearTimeout(timer);}
  }
  const active=`EXISTS(SELECT 1 FROM akay_connections c WHERE c.navigator_id=a.navigator_id AND c.caregiver_id=$1 AND c.status='active')`;
  const title=row=>`${row.kind==='sos'?'SOS':'Possible fall or impact'} — ${row.navigator_name?.trim()||'Linked navigator'}`;
  return {
    async list(actor) {
      role(actor);
      // Consent is evaluated in the same statement as the returned data, with no cached feed.
      const result=await pool.query(`SELECT a.*,u.firebase_uid AS navigator_uid,u.name AS navigator_name,
        r.sampled_at,r.latitude,r.longitude,ar.read_at,ar.dismissed_at
        FROM akay_alerts a JOIN ${usersTable()} u ON u.user_id=a.navigator_id
        JOIN akay_readings r ON r.id=a.reading_id
        LEFT JOIN akay_alert_receipts ar ON ar.alert_id=a.id AND ar.caregiver_id=$1
        WHERE a.kind IN ('sos','motion') AND ${active}
        AND (a.resolved_at IS NULL OR ar.dismissed_at IS NULL)
        ORDER BY (a.resolved_at IS NULL) DESC,a.created_at DESC LIMIT 200`,[actor.id]);
      return {alerts:result.rows.map(row=>({...row,title:title(row)}))};
    },
    async respond(actor,id,action) {
      role(actor);
      if(!uuid(id)||!['read','dismiss','acknowledge','resolve','false_alarm'].includes(action)) fail(400,'invalid_response','Invalid alert response.');
      const db=await pool.connect();
      try {
        await db.query('BEGIN');
        // Lock consent through mutation so a concurrent revoke cannot authorize a later response.
        const allowed=await db.query(`SELECT a.id,a.resolved_at FROM akay_alerts a
          JOIN akay_connections c ON c.navigator_id=a.navigator_id
          WHERE a.id=$2 AND c.caregiver_id=$1 AND c.status='active' AND a.kind IN ('sos','motion') FOR UPDATE OF a FOR SHARE OF c`,[actor.id,id]);
        const alert=allowed.rows[0];
        if(!alert) fail(403,'access_revoked','Active navigator consent is required.');
        if(action==='dismiss'&&!alert.resolved_at) fail(409,'unresolved_alert','Resolve the incident before removing its notification.');
        if(['acknowledge','resolve','false_alarm'].includes(action)) {
          await db.query(`UPDATE akay_alerts SET acknowledged_at=COALESCE(acknowledged_at,clock_timestamp()),
            acknowledged_by=COALESCE(acknowledged_by,$2),
            resolved_at=CASE WHEN $3='acknowledge' THEN resolved_at ELSE COALESCE(resolved_at,clock_timestamp()) END,
            resolved_by=CASE WHEN $3='acknowledge' THEN resolved_by ELSE COALESCE(resolved_by,$2) END,
            resolution=CASE WHEN $3='acknowledge' THEN resolution ELSE COALESCE(resolution,$4) END WHERE id=$1`,
          [id,actor.id,action,action==='false_alarm'?'false_alarm':'resolved']);
          await db.query('INSERT INTO akay_audit_events(actor_id,action,record_id) VALUES($1,$2,$3)',[actor.id,`alert_${action}`,id]);
        }
        await db.query(`INSERT INTO akay_alert_receipts(alert_id,caregiver_id,read_at,dismissed_at)
          VALUES($1,$2,clock_timestamp(),CASE WHEN $3='dismiss' THEN clock_timestamp() ELSE NULL END)
          ON CONFLICT(alert_id,caregiver_id) DO UPDATE SET read_at=COALESCE(akay_alert_receipts.read_at,EXCLUDED.read_at),
          dismissed_at=COALESCE(akay_alert_receipts.dismissed_at,EXCLUDED.dismissed_at)`,[id,actor.id,action]);
        await db.query('COMMIT');return {accepted:true};
      } catch(error) {await db.query('ROLLBACK');throw error;} finally {db.release();}
    },
    async token(actor,token,remove=false) {
      role(actor);
      if(typeof token!=='string'||token.length<20||token.length>4096||/\s/.test(token)) fail(400,'invalid_token','Invalid notification registration.');
      if(remove) await pool.query('DELETE FROM akay_push_tokens WHERE token_hash=$1 AND caregiver_id=$2',[hash(token),actor.id]);
      else await pool.query(`INSERT INTO akay_push_tokens(token_hash,token,caregiver_id) VALUES($1,$2,$3)
        ON CONFLICT(token_hash) DO UPDATE SET token=EXCLUDED.token,caregiver_id=EXCLUDED.caregiver_id,updated_at=clock_timestamp()`,[hash(token),token,actor.id]);
      return {accepted:true};
    },
    async dispatch() {
      let deliveryUnavailable=false;
      // Durable queue derived from committed alerts: restart/retry never depends on an in-memory callback.
      await pool.query(`INSERT INTO akay_alert_deliveries(alert_id,token_hash,caregiver_id)
        SELECT a.id,t.token_hash,c.caregiver_id FROM akay_alerts a
        JOIN akay_connections c ON c.navigator_id=a.navigator_id AND c.status='active'
        JOIN akay_push_tokens t ON t.caregiver_id=c.caregiver_id
        WHERE a.kind IN ('sos','motion') AND a.resolved_at IS NULL
        AND a.created_at>clock_timestamp()-interval '24 hours' ON CONFLICT DO NOTHING`);
      for(let i=0;i<20;i++) {
        const db=await pool.connect();
        try {
          await db.query('BEGIN');
          const result=await db.query(`SELECT j.*,t.token,a.kind,u.name AS navigator_name
            FROM akay_alert_deliveries j JOIN akay_alerts a ON a.id=j.alert_id
            JOIN akay_push_tokens t ON t.token_hash=j.token_hash AND t.caregiver_id=j.caregiver_id
            JOIN akay_connections c ON c.navigator_id=a.navigator_id AND c.caregiver_id=j.caregiver_id AND c.status='active'
            JOIN ${usersTable()} u ON u.user_id=a.navigator_id
            WHERE j.sent_at IS NULL AND j.next_attempt_at<=clock_timestamp() AND j.attempts<12
            AND a.resolved_at IS NULL AND a.created_at>clock_timestamp()-interval '24 hours'
            ORDER BY a.created_at LIMIT 1 FOR UPDATE OF j SKIP LOCKED FOR SHARE OF c,t,a`);
          const job=result.rows[0];
          if(!job) {await db.query('COMMIT');break;}
          try {
            await send({token:job.token,
              notification:{title:title(job),body:job.kind==='sos'?'Assistance requested. Open AKAY to check and respond.':'Cane detected unusual movement. Please check on this navigator.'},
              data:{type:'cane_alert',alertId:job.alert_id},
              android:{priority:'high',ttl:300000,notification:{channelId:'akay_emergencies',tag:job.alert_id,sound:'default'}},
              apns:{payload:{aps:{sound:'default'}},headers:{'apns-priority':'10','apns-expiration':String(Math.floor(Date.now()/1000)+300)}},
              webpush:{headers:{Urgency:'high',TTL:'300'},notification:{tag:job.alert_id}}});
            await db.query('UPDATE akay_alert_deliveries SET sent_at=clock_timestamp(),attempts=attempts+1 WHERE alert_id=$1 AND token_hash=$2 AND caregiver_id=$3',[job.alert_id,job.token_hash,job.caregiver_id]);
          } catch(error) {
            deliveryUnavailable=true;
            if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(error.code))
              await db.query('DELETE FROM akay_push_tokens WHERE token_hash=$1',[job.token_hash]);
            else await db.query(`UPDATE akay_alert_deliveries SET attempts=attempts+1,next_attempt_at=clock_timestamp()+interval '30 seconds'*LEAST(60,power(2,attempts)::integer)
              WHERE alert_id=$1 AND token_hash=$2 AND caregiver_id=$3`,[job.alert_id,job.token_hash,job.caregiver_id]);
          }
          await db.query('COMMIT');
        } catch(error) {await db.query('ROLLBACK');throw error;} finally {db.release();}
      }
      return {deliveryUnavailable};
    },
  };
}
module.exports={createEmergencyService};
