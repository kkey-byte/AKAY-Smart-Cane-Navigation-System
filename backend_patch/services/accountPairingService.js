'use strict';
const {randomInt,randomUUID}=require('node:crypto');
const {createPairingService,ApiError,hash}=require('./pairingService');
const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const newCode=()=>Array.from({length:6},()=>alphabet[randomInt(alphabet.length)]).join('');
const fail=(status,code,message)=>{throw new ApiError(status,code,message);};
const methods=['qr_code','alphanumeric'];
function createAccountPairingService(pool,usersTable) {
  const guard=createPairingService(pool,usersTable);
  const one=async(db,sql,args)=>(await db.query(sql,args)).rows[0];
  const tx=async action=>{
    const db=await pool.connect();
    try {await db.query('BEGIN');const result=await action(db);await db.query('COMMIT');return result;}
    catch(error){await db.query('ROLLBACK');throw error;}finally{db.release();}
  };
  return {
    async generate(actor,body={}) {
      if(actor.role!=='visually_impaired') fail(403,'role_required','Only a Navigator can create a pairing code.');
      if(body.authorize_pairing!==true) fail(400,'consent_required','Confirm that redeeming this code authorizes caregiver access.');
      if(!methods.includes(body.pairing_method)) fail(400,'invalid_method','Choose QR code or alphanumeric.');
      const device=body.device_id ?? randomUUID();
      if(typeof device!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(device)) fail(400,'invalid_device','App instance identifier is invalid.');
      await guard.limit(actor.id,'invite',10,3600);
      return tx(async db=>{
        // Serialize regeneration for this account/app instance.
        await db.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`pair-code:${actor.id}:${device}`]);
        await db.query('INSERT INTO pairing_app_instances(device_id,vi_user_id) VALUES($1,$2) ON CONFLICT(device_id) DO NOTHING',[device,actor.id]);
        const instance=await one(db,'SELECT vi_user_id FROM pairing_app_instances WHERE device_id=$1',[device]);
        if(instance.vi_user_id!==actor.id) fail(403,'invalid_device','This app instance belongs to another account.');
        for(let attempt=0;attempt<5;attempt++) {
          const code=newCode();
          const invitation=await one(db,`INSERT INTO akay_invitations(navigator_id,code_hash,expires_at)
            VALUES($1,$2,clock_timestamp()+interval '10 minutes') ON CONFLICT(code_hash) DO NOTHING RETURNING id,expires_at`,[actor.id,hash(code)]);
          if(!invitation) continue;
          const pairing=await one(db,`INSERT INTO pairings(device_id,vi_user_id,pairing_code,pairing_method,status)
            VALUES($1,$2,$3,$4,'pending') ON CONFLICT(pairing_code) DO NOTHING RETURNING *`,[device,actor.id,code,body.pairing_method]);
          if(!pairing) {await db.query('DELETE FROM akay_invitations WHERE id=$1',[invitation.id]);continue;}
          await db.query("UPDATE pairings SET status='unpaired',unpaired_at=clock_timestamp() WHERE vi_user_id=$1 AND device_id=$2 AND status='pending' AND pairing_id<>$3",[actor.id,device,pairing.pairing_id]);
          return {pairing,code,expires_at:invitation.expires_at};
        }
        fail(503,'code_unavailable','A pairing code could not be created. Please try again.');
      });
    },
    async redeem(actor,body={},ip='unknown') {
      if(actor.role!=='caregiver') fail(403,'role_required','Only a Caregiver can redeem a code.');
      await guard.limit(actor.id,'redeem',5);await guard.limit(hash(ip),'redeem-ip',30);
      const code=typeof body.code==='string'?body.code.trim().toUpperCase():'';
      if(!/^[A-HJ-NP-Z2-9]{6}$/.test(code)||!methods.includes(body.pairing_method)) fail(400,'invalid_pairing','Enter a valid six-character pairing code and method.');
      return tx(async db=>{
        const pairing=await one(db,`SELECT p.*,i.id AS invitation_id,i.expires_at,i.redeemed_at
          FROM pairings p JOIN akay_invitations i ON i.code_hash=$2 AND i.navigator_id=p.vi_user_id
          WHERE p.pairing_code=$1 FOR UPDATE OF p,i`,[code,hash(code)]);
        const available=async()=>pairing && pairing.status==='pending' && !pairing.redeemed_at &&
          (await one(db,'SELECT $1::timestamptz>clock_timestamp() AS valid',[pairing.expires_at])).valid;
        if(!await available()) fail(410,'invalid_pairing','Code expired, replaced or already used. Ask the Navigator for a new code.');
        const navigator=await one(db,`SELECT user_id FROM ${usersTable()} WHERE user_id=$1 AND role='visually_impaired'`,[pairing.vi_user_id]);
        if(!navigator || pairing.vi_user_id===actor.id) fail(403,'invalid_pairing','Navigator account unavailable.');
        await db.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`${pairing.vi_user_id}:${actor.id}`]);
        const previous=await one(db,'SELECT * FROM akay_connections WHERE navigator_id=$1 AND caregiver_id=$2 FOR UPDATE',[pairing.vi_user_id,actor.id]);
        if(previous?.status==='active') fail(409,'connection_exists','You are already paired with this Navigator.');
        if(!await available()) fail(410,'invalid_pairing','Code expired while pairing. Ask for a new code.');
        const connection=await one(db,`INSERT INTO akay_connections(navigator_id,caregiver_id,status,invitation_id,expires_at,consented_at)
          VALUES($1,$2,'active',$3,clock_timestamp()+interval '24 hours',clock_timestamp())
          ON CONFLICT(navigator_id,caregiver_id) DO UPDATE SET status='active',invitation_id=$3,requested_at=clock_timestamp(),
          expires_at=clock_timestamp()+interval '24 hours',consented_at=clock_timestamp(),revoked_at=NULL RETURNING *`,[pairing.vi_user_id,actor.id,pairing.invitation_id]);
        await db.query('UPDATE akay_invitations SET redeemed_at=clock_timestamp(),redeemed_by=$2 WHERE id=$1',[pairing.invitation_id,actor.id]);
        const result=await one(db,`UPDATE pairings SET caregiver_id=$2,pairing_method=$3,status='active',paired_at=clock_timestamp(),unpaired_at=NULL
          WHERE pairing_id=$1 RETURNING pairing_id,device_id,vi_user_id,caregiver_id,pairing_method,status,paired_at,unpaired_at`,[pairing.pairing_id,actor.id,body.pairing_method]);
        await db.query("INSERT INTO akay_audit_events(actor_id,action,record_id) VALUES($1,'pairing_code_accepted',$2)",[actor.id,connection.id]);
        return {pairing:result,connection_id:connection.id};
      });
    },
    async list(actor) {
      return (await pool.query(`SELECT pairing_id,device_id,vi_user_id,caregiver_id,pairing_method,status,paired_at,unpaired_at
        FROM pairings WHERE vi_user_id=$1 OR caregiver_id=$1 ORDER BY paired_at DESC NULLS LAST`,[actor.id])).rows;
    },
  };
}
module.exports={createAccountPairingService};
