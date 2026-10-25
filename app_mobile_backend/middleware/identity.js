'use strict';
const firebase = require('../services/firebaseAdmin');
const pool = require('../database/db');
const {usersTable} = require('../database/ensureUsersTable');
async function verifyFirebase(req,res,next) {
  const match = /^Bearer (\S+)$/.exec(req.headers.authorization || '');
  if(!match) return res.status(401).json({code:'sign_in_required',message:'A Firebase ID token is required.'});
  try {
    req.firebase = await firebase.auth().verifyIdToken(match[1],true);
    return next();
  } catch (error) {
    if(error.code?.startsWith('app/') || ['auth/invalid-credential','auth/internal-error'].includes(error.code)) return res.status(503).json({code:'identity_service_unavailable',message:'Identity verification is unavailable. Contact the service operator.'});
    return res.status(401).json({code:'session_invalid',message:'Sign in again to continue.'});
  }
}
async function requireProfile(req,res,next) {
  try {
    const result=await pool.query(`SELECT user_id AS id,firebase_uid AS uid,role,name FROM ${usersTable()} WHERE firebase_uid=$1`,[req.firebase.uid]);
    if(result.rows.length!==1) return res.status(403).json({code:'identity_ambiguous',message:'Account identity requires reconciliation.'});
    req.actor=result.rows[0];
    if(!req.actor || !['caregiver','visually_impaired'].includes(req.actor.role)) return res.status(403).json({code:'profile_required',message:'A recognized account profile is required.'});
    return next();
  } catch (_) { return res.status(503).json({code:'account_unavailable',message:'Account verification unavailable.'}); }
}
module.exports={verifyFirebase,requireProfile};
