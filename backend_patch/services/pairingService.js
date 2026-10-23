'use strict';
const { randomBytes, createHash, timingSafeEqual } = require('node:crypto');
const hash = value => createHash('sha256').update(String(value)).digest('hex');
const secret = () => randomBytes(32).toString('base64url');
class ApiError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}
const fail = (status, code, message) => { throw new ApiError(status, code, message); };
const uuid = value => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
function match(value, digest) {
  if (typeof value !== 'string' || !digest) return false;
  const a = Buffer.from(hash(value)), b = Buffer.from(digest);
  return a.length === b.length && timingSafeEqual(a, b);
}
function createPairingService(pool, usersTable) {
  const users = () => usersTable(); // Trusted resolver, never request text.
  async function tx(fn) {
    const db = await pool.connect();
    try {
      await db.query('BEGIN'); const result = await fn(db); await db.query('COMMIT'); return result;
    } catch (error) { await db.query('ROLLBACK'); throw error; }
    finally { db.release(); }
  }
  const one = async (db, sql, values) => (await db.query(sql, values)).rows[0];
  // Check after a lock is acquired; transaction-start now() can be stale after
  // waiting for another writer, allowing an expired invitation to be redeemed.
  const unexpired = async (db, expires) =>
    (await one(db,'SELECT $1::timestamptz > clock_timestamp() AS valid',[expires])).valid;
  const role = (actor, required) => {
    if (actor.role !== required) fail(403, 'role_required', `A ${required} account is required.`);
  };
  const id = value => { if (!uuid(value)) fail(400, 'invalid_id', 'Invalid record identifier.'); return value; };
  async function audit(db, actor, action, record) {
    await db.query('INSERT INTO akay_audit_events(actor_id,action,record_id) VALUES($1,$2,$3)', [actor.id, action, record]);
  }
  async function limit(actor, action, maximum, seconds = 60) {
    // Separate committed query: invalid/rolled-back operations still spend attempts.
    const row = await one(pool, `INSERT INTO akay_rate_limits(actor,action,bucket,attempts)
      VALUES($1,$2,floor(extract(epoch FROM clock_timestamp())/$3)::bigint,1)
      ON CONFLICT(actor,action,bucket) DO UPDATE SET attempts=akay_rate_limits.attempts+1 RETURNING attempts`,
    [actor, action, seconds]);
    if (row.attempts > maximum) fail(429, 'rate_limited', 'Too many attempts. Wait before trying again.');
  }
  async function authorize(actor, navigatorUid) {
    return tx(async db => {
      const navigator = await one(db, `SELECT user_id AS id,firebase_uid AS uid,name,profile_picture
        FROM ${users()} WHERE firebase_uid=$1 AND role='visually_impaired'`, [navigatorUid]);
      if (!navigator) fail(404, 'not_available', 'Navigator unavailable.');
      if (actor.id !== navigator.id) {
        const connection = await one(db, `SELECT id FROM akay_connections WHERE navigator_id=$1 AND caregiver_id=$2 AND status='active'`, [navigator.id, actor.id]);
        if (actor.role !== 'caregiver' || !connection) fail(403, 'access_revoked', 'Active navigator consent is required.');
      }
      return navigator;
    });
  }
  return {
    authorize, limit,
    async invite(actor) {
      role(actor, 'visually_impaired'); await limit(actor.id, 'invite', 10, 3600);
      const code = secret();
      const invitation = await one(pool, `INSERT INTO akay_invitations(navigator_id,code_hash,expires_at)
        VALUES($1,$2,clock_timestamp()+interval '10 minutes') RETURNING id,expires_at`, [actor.id,hash(code)]);
      return { ...invitation, code };
    },
    async redeem(actor, code, ip = 'unknown') {
      role(actor, 'caregiver'); await limit(actor.id,'redeem',5); await limit(hash(ip),'redeem-ip',30);
      if (typeof code !== 'string' || code.length !== 43) fail(400,'invalid_invitation','Invitation invalid, expired or already used.');
      return tx(async db => {
        const invitation = await one(db,'SELECT *,expires_at>clock_timestamp() AS valid FROM akay_invitations WHERE code_hash=$1 FOR UPDATE',[hash(code)]);
        if (!invitation || invitation.redeemed_at || !await unexpired(db,invitation.expires_at)) fail(410,'invalid_invitation','Invitation invalid, expired or already used.');
        await db.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`${invitation.navigator_id}:${actor.id}`]);
        const prior = await one(db,'SELECT * FROM akay_connections WHERE navigator_id=$1 AND caregiver_id=$2 FOR UPDATE',[invitation.navigator_id,actor.id]);
        if (prior && (prior.status === 'active' || (prior.status === 'pending' && new Date(prior.expires_at)>new Date()))) fail(409,'connection_exists','You already have an active or pending connection.');
        if (!await unexpired(db,invitation.expires_at)) fail(410,'invalid_invitation','Invitation expired while waiting. Request a new invitation.');
        const connection = await one(db,`INSERT INTO akay_connections(navigator_id,caregiver_id,status,invitation_id,expires_at)
          VALUES($1,$2,'pending',$3,clock_timestamp()+interval '24 hours') ON CONFLICT(navigator_id,caregiver_id)
          DO UPDATE SET status='pending',invitation_id=$3,requested_at=clock_timestamp(),expires_at=clock_timestamp()+interval '24 hours',consented_at=NULL,revoked_at=NULL RETURNING *`,
        [invitation.navigator_id,actor.id,invitation.id]);
        await db.query('UPDATE akay_invitations SET redeemed_at=clock_timestamp(),redeemed_by=$2 WHERE id=$1',[invitation.id,actor.id]);
        await audit(db,actor,'pairing_requested',connection.id); return connection;
      });
    },
    async connections(actor) {
      // Listing is read-only; expired pending state is derived without a write
      // on every five-second poll. Decisions still check database wall time.
      return (await pool.query(`SELECT c.*, CASE WHEN c.status='pending' AND c.expires_at<=clock_timestamp() THEN 'expired' ELSE c.status END AS status, n.firebase_uid AS navigator_uid,n.name AS navigator_name,
        n.profile_picture AS navigator_picture,g.firebase_uid AS caregiver_uid,g.name AS caregiver_name
        FROM akay_connections c JOIN ${users()} n ON n.user_id=c.navigator_id JOIN ${users()} g ON g.user_id=c.caregiver_id
        WHERE c.navigator_id=$1 OR c.caregiver_id=$1 ORDER BY c.requested_at DESC`,[actor.id])).rows;
    },
    async decide(actor, connectionId, accept) {
      role(actor,'visually_impaired'); id(connectionId);
      return tx(async db => {
        const c = await one(db,'SELECT *,expires_at>clock_timestamp() AS valid FROM akay_connections WHERE id=$1 FOR UPDATE',[connectionId]);
        if (!c || c.navigator_id!==actor.id) fail(403,'forbidden','Only the invited navigator can decide this request.');
        const target=accept?'active':'rejected';
        if (c.status===target) return c;
        if (c.status!=='pending' || !await unexpired(db,c.expires_at)) fail(409,'request_closed','Request expired or already decided.');
        const result=await one(db,`UPDATE akay_connections SET status=$2,consented_at=CASE WHEN $2='active' THEN clock_timestamp() END WHERE id=$1 RETURNING *`,[c.id,target]);
        await audit(db,actor,accept?'consent_accepted':'consent_rejected',c.id); return result;
      });
    },
    async revoke(actor, connectionId) {
      id(connectionId);
      return tx(async db => {
        const c=await one(db,'SELECT * FROM akay_connections WHERE id=$1 FOR UPDATE',[connectionId]);
        if (!c || (c.navigator_id!==actor.id && c.caregiver_id!==actor.id)) fail(403,'forbidden','This connection is not yours.');
        await db.query("UPDATE akay_connections SET status='revoked',revoked_at=clock_timestamp() WHERE id=$1",[c.id]);
        await audit(db,actor,'consent_revoked',c.id); return {status:'revoked'};
      });
    },
    async claim(actor, deviceId, code) {
      role(actor,'visually_impaired'); id(deviceId); await limit(actor.id,'claim',10,3600);
      return tx(async db => {
        const device=await one(db,'SELECT * FROM akay_devices WHERE id=$1 FOR UPDATE',[deviceId]);
        if (!device) fail(404,'device_unknown','Device not provisioned. Contact the device custodian.');
        if (device.owner_id===actor.id) return {id:device.id,serial:device.serial};
        if (device.owner_id) fail(409,'already_owned','Device already registered. Its owner must transfer or release it.');
        if (!match(code,device.claim_hash)) fail(403,'claim_invalid','Private claim code invalid or unavailable.');
        await db.query('UPDATE akay_devices SET owner_id=$2,claim_hash=NULL WHERE id=$1',[deviceId,actor.id]);
        await db.query('INSERT INTO akay_ownership_history(device_id,owner_id) VALUES($1,$2)',[deviceId,actor.id]);
        await audit(db,actor,'device_claimed',deviceId); return {id:device.id,serial:device.serial};
      });
    },
    async devices(actor) {
      role(actor,'visually_impaired');
      return (await pool.query(`SELECT d.id,d.serial,a.id AS assignment_id,a.started_at FROM akay_devices d
        LEFT JOIN akay_assignments a ON a.device_id=d.id AND a.ended_at IS NULL WHERE d.owner_id=$1 ORDER BY d.created_at`,[actor.id])).rows;
    },
    async assign(actor, deviceId) {
      role(actor,'visually_impaired'); id(deviceId);
      return tx(async db=>{
        const d=await one(db,'SELECT * FROM akay_devices WHERE id=$1 FOR UPDATE',[deviceId]);
        if (!d || d.owner_id!==actor.id) fail(403,'not_owner','Only the registered navigator custodian can assign this cane to themselves.');
        const prior=await one(db,'SELECT * FROM akay_assignments WHERE device_id=$1 AND ended_at IS NULL',[deviceId]);
        if (prior) { if(prior.navigator_id!==actor.id) fail(409,'assignment_conflict','Cane already assigned. Release the assignment first.'); return prior; }
        const result=await one(db,'INSERT INTO akay_assignments(device_id,navigator_id,assigned_by) VALUES($1,$2,$2) RETURNING *',[deviceId,actor.id]);
        await audit(db,actor,'device_assigned',result.id); return result;
      });
    },
    async release(actor, deviceId, ownership=false) {
      role(actor,'visually_impaired'); id(deviceId);
      return tx(async db=>{
        const d=await one(db,'SELECT * FROM akay_devices WHERE id=$1 FOR UPDATE',[deviceId]);
        if (!d || d.owner_id!==actor.id) fail(403,'not_owner','Only the registered custodian can release this device.');
        await db.query('UPDATE akay_assignments SET ended_at=clock_timestamp() WHERE device_id=$1 AND ended_at IS NULL',[deviceId]);
        if (ownership) {
          await db.query('UPDATE akay_devices SET owner_id=NULL,claim_hash=NULL WHERE id=$1',[deviceId]);
          await db.query('UPDATE akay_ownership_history SET ended_at=clock_timestamp() WHERE device_id=$1 AND ended_at IS NULL',[deviceId]);
        }
        await audit(db,actor,ownership?'ownership_released':'assignment_released',deviceId); return {status:'released'};
      });
    },
    async transfer(actor, deviceId, targetUid) {
      role(actor,'visually_impaired'); id(deviceId);
      return tx(async db=>{
        const d=await one(db,'SELECT * FROM akay_devices WHERE id=$1 FOR UPDATE',[deviceId]);
        if (!d || d.owner_id!==actor.id) fail(403,'not_owner','Only the registered custodian can initiate a transfer.');
        const target=await one(db,`SELECT user_id FROM ${users()} WHERE firebase_uid=$1 AND role='visually_impaired'`,[targetUid]);
        if (!target || target.user_id===actor.id) fail(400,'invalid_target','Recipient must be another registered navigator.');
        const code=secret();
        const result=await one(db,`INSERT INTO akay_transfers(device_id,from_id,to_id,code_hash,expires_at)
          VALUES($1,$2,$3,$4,clock_timestamp()+interval '10 minutes') RETURNING id,expires_at`,[deviceId,actor.id,target.user_id,hash(code)]);
        await audit(db,actor,'transfer_requested',result.id); return {...result,code};
      });
    },
    async acceptTransfer(actor, code) {
      role(actor,'visually_impaired'); await limit(actor.id,'transfer',5);
      if(typeof code!=='string' || code.length!==43) fail(400,'transfer_invalid','A private transfer code is required.');
      return tx(async db=>{
        const t=await one(db,'SELECT *,expires_at>clock_timestamp() AS valid FROM akay_transfers WHERE code_hash=$1 FOR UPDATE',[hash(code)]);
        if (!t || t.accepted_at || t.to_id!==actor.id || !await unexpired(db,t.expires_at)) fail(410,'transfer_invalid','Transfer invalid, expired, used or intended for another account.');
        const d=await one(db,'SELECT * FROM akay_devices WHERE id=$1 FOR UPDATE',[t.device_id]);
        // Ownership history prevents an old offer surviving a release/reclaim cycle.
        const owner=await one(db,'SELECT * FROM akay_ownership_history WHERE device_id=$1 AND ended_at IS NULL',[d.id]);
        if (d.owner_id!==t.from_id || !owner || new Date(owner.started_at)>new Date(t.created_at)) fail(409,'owner_changed','Device ownership changed. Request a new transfer.');
        if (!await unexpired(db,t.expires_at)) fail(410,'transfer_invalid','Transfer expired while waiting. Request a new transfer.');
        await db.query('UPDATE akay_assignments SET ended_at=clock_timestamp() WHERE device_id=$1 AND ended_at IS NULL',[d.id]);
        await db.query('UPDATE akay_ownership_history SET ended_at=clock_timestamp() WHERE device_id=$1 AND ended_at IS NULL',[d.id]);
        await db.query('UPDATE akay_devices SET owner_id=$2,claim_hash=NULL WHERE id=$1',[d.id,actor.id]);
        await db.query('INSERT INTO akay_ownership_history(device_id,owner_id) VALUES($1,$2)',[d.id,actor.id]);
        await db.query('UPDATE akay_transfers SET accepted_at=clock_timestamp() WHERE id=$1',[t.id]);
        await audit(db,actor,'transfer_accepted',d.id); return {id:d.id};
      });
    },
    async hardware(deviceId, key, operation) {
      id(deviceId);
      return tx(async db=>{
        const d=await one(db,'SELECT * FROM akay_devices WHERE id=$1 FOR UPDATE',[deviceId]);
        const credential=await one(db,'SELECT * FROM akay_device_credentials WHERE device_id=$1 AND revoked_at IS NULL FOR UPDATE',[deviceId]);
        if (!d || !credential || !match(key,credential.secret_hash)) fail(401,'device_auth_failed','Device authentication failed.');
        const assignment=await one(db,'SELECT *,clock_timestamp() AS checked_at FROM akay_assignments WHERE device_id=$1 AND ended_at IS NULL',[deviceId]);
        return operation(db,d,credential,assignment);
      });
    },
    async ingest(deviceId,key,body) {
      return this.hardware(deviceId,key,async(db,d,credential,assignment)=>{
        if (!assignment || assignment.id!==body.assignmentId) fail(409,'assignment_changed','Refresh the current device assignment before transmitting.');
        if (!Number.isSafeInteger(body.sequence) || body.sequence<=Number(credential.last_sequence)) fail(409,'replayed_reading','Sequence already used or out of order.');
        if(typeof body.sampledAt!=='string' || !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(body.sampledAt)) fail(400,'invalid_sample_time','An ISO timestamp with a timezone is required.');
        const sample=new Date(body.sampledAt);
        const checkedAt=new Date(assignment.checked_at).getTime();
        if (!Number.isFinite(sample.getTime()) || sample.getTime()>checkedAt+30000 || sample.getTime()<checkedAt-300000 || sample<new Date(assignment.started_at)) fail(400,'invalid_sample_time','A fresh sample timestamp from the current assignment is required.');
        const lat=body.latitude??null,lon=body.longitude??null,battery=body.battery??null,status=body.status??null;
        if ((lat===null)!==(lon===null) || (lat!==null && (!Number.isFinite(lat)||!Number.isFinite(lon)||Math.abs(lat)>90||Math.abs(lon)>180)) ||
          (battery!==null && (!Number.isInteger(battery)||battery<0||battery>100)) || (status!==null && !['idle','moving','fault'].includes(status)) ||
          (body.alert!=null && !['sos','obstacle','battery_low','device_fault'].includes(body.alert))) fail(400,'invalid_reading','Reading fields are invalid.');
        const reading=await one(db,`INSERT INTO akay_readings(device_id,assignment_id,navigator_id,credential_id,sequence,sampled_at,latitude,longitude,battery,status)
          VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id`,[d.id,assignment.id,assignment.navigator_id,credential.id,body.sequence,sample,lat,lon,battery,status]);
        await db.query('UPDATE akay_device_credentials SET last_sequence=$2 WHERE id=$1',[credential.id,body.sequence]);
        if(body.alert) await db.query('INSERT INTO akay_alerts(reading_id,navigator_id,device_id,assignment_id,kind) VALUES($1,$2,$3,$4,$5)',[reading.id,assignment.navigator_id,d.id,assignment.id,body.alert]);
        return reading;
      });
    },
    async snapshot(actor,navigatorUid) {
      const navigator=await authorize(actor,navigatorUid);
      const devices=(await pool.query(`SELECT d.id,d.serial,a.id AS assignment_id,a.started_at,r.sampled_at,r.received_at,r.latitude,r.longitude,r.battery,r.status
        FROM akay_assignments a JOIN akay_devices d ON d.id=a.device_id LEFT JOIN LATERAL
        (SELECT * FROM akay_readings WHERE assignment_id=a.id ORDER BY sampled_at DESC,received_at DESC LIMIT 1) r ON true
        WHERE a.navigator_id=$1 AND a.ended_at IS NULL ORDER BY a.started_at DESC`,[navigator.id])).rows;
      const alerts=(await pool.query('SELECT id,device_id,assignment_id,kind,created_at FROM akay_alerts WHERE navigator_id=$1 ORDER BY created_at DESC LIMIT 50',[navigator.id])).rows;
      // Recheck after reads, so revocation racing this request cannot return cached data.
      await authorize(actor,navigatorUid); return {navigator,devices,alerts,source:'cane',serverTime:new Date().toISOString()};
    },
  };
}
module.exports={createPairingService,ApiError,hash,secret,match};


