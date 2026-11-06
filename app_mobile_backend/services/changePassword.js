'use strict';
const {randomBytes,scrypt}=require('node:crypto');
const deriveKey=require('node:util').promisify(scrypt);

// A database transaction cannot atomically commit a Firebase operation. Failures
// after contacting Firebase are explicitly reported as uncertain, never success.
module.exports=function changePassword({pool,usersTable,firebase,clock=Date.now}) {
  return async(req,res)=>{
    const password=req.body?.password;
    if(typeof password!=='string' || [...password].length<8 || password.length>4096 || !/[A-Z]/.test(password) || !/[^a-zA-Z0-9\s]/.test(password)) {
      return res.status(400).json({message:'Use at least 8 characters, an uppercase letter, and a special character.'});
    }
    const age=clock()/1000-req.firebase.auth_time;
    if(!Number.isFinite(age) || age< -30 || age>300 || req.firebase.firebase?.sign_in_provider!=='password') {
      return res.status(401).json({message:'Verify your current password again before changing it.'});
    }
    let db,contactedFirebase=false;
    try {
      const salt=randomBytes(16).toString('hex');
      const key=await deriveKey(password,salt,64,{N:131072,r:8,p:1,maxmem:256*1024*1024});
      const hash=`scrypt$131072$8$1$${salt}$${key.toString('hex')}`;
      db=await pool.connect();
      await db.query('BEGIN');
      const result=await db.query(`UPDATE ${usersTable()} SET password=$1,updated_at=NOW() WHERE firebase_uid=$2 RETURNING user_id`,[hash,req.firebase.uid]);
      if(result.rows.length!==1) {
        await db.query('ROLLBACK');
        return res.status(404).json({message:'No linked account profile. Complete registration.'});
      }
      contactedFirebase=true;
      await firebase.auth().updateUser(req.firebase.uid,{password});
      await db.query('COMMIT');
      return res.json({message:'Password updated successfully.'});
    } catch(error) {
      if(db) {try {await db.query('ROLLBACK');} catch(_) {}}
      if(error.code==='auth/password-does-not-meet-requirements' || error.code==='auth/invalid-password') {
        return res.status(400).json({message:'The new password does not meet the account password policy.'});
      }
      return res.status(503).json({
        code:contactedFirebase?'password_update_uncertain':'password_update_failed',
        message:contactedFirebase
          ? 'Password update could not be confirmed. Try signing in with your new password; if it works, repeat the change to synchronize your account.'
          : 'Password update unavailable. Please try again.',
      });
    } finally {if(db) db.release();}
  };
};
