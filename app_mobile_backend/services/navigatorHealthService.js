'use strict';
const {ApiError}=require('./pairingService');
const healthModel=require('../models/patientHealthStatus');

// Read-only linked-navigator information. Never repurpose the actor-only /profile
// or /health-status endpoints by accepting a caller-supplied account identity.
function createNavigatorHealthService(pool,authorize,users,patients,{health=healthModel}={}) {
  async function snapshot(actor,uid) {
    const navigator=await authorize(actor,uid);
    const row=(await pool.query(`SELECT u.user_id,u.firebase_uid,u.name,u.phone,
      p.profile_id,p.age,p.gender,p.birthdate,p.medical_conditions,p.allergies,
      p.blood_type,p.emergency_contact,p.address
      FROM ${users()} u LEFT JOIN ${patients()} p ON p.user_id=u.user_id
      WHERE u.user_id=$1 AND u.firebase_uid=$2`,[navigator.id,uid])).rows[0];
    if(!row) throw new ApiError(404,'not_available','Navigator information unavailable.');
    let status=null,healthUnavailable=false;
    if(row.profile_id) {
      try {status=await health.fetch(pool,row.profile_id);}
      catch (_) {healthUnavailable=true;}
    }
    // A connection revoked during a database read must hide the whole result.
    await authorize(actor,uid);
    return {
      navigator:{uid:row.firebase_uid,userId:row.user_id,name:row.name,phone:row.phone},
      patientProfile:row.profile_id ? {
        age:row.age,gender:row.gender,birthdate:row.birthdate,
        medicalConditions:row.medical_conditions,allergies:row.allergies,
        bloodType:row.blood_type,emergencyContact:row.emergency_contact,address:row.address,
      } : null,
      health_status:status ? {
        height:status.height,weight:status.weight,medical_conditions:status.medical_conditions,
        allergies:status.allergies,emergency_contact_phone:status.emergency_contact_phone,
      } : null,
      healthUnavailable,
    };
  }
  return {snapshot};
}
module.exports={createNavigatorHealthService};
