'use strict';
const pool = require('../database/db');
const {patientProfilesTable} = require('../database/ensurePatientProfilesTable');
const model = require('../models/patientHealthStatus');
// Actor comes only from verified Firebase middleware; no caller-selected patient.
async function patient(db, actor, lock = false) {
  return (await db.query(`SELECT profile_id FROM ${patientProfilesTable()} WHERE user_id=$1${lock ? ' FOR UPDATE' : ''}`, [actor.id])).rows[0];
}
async function get(req,res) {
  try {
    const owner = await patient(pool,req.actor);
    return res.json({health_status: owner ? await model.fetch(pool,owner.profile_id) : null});
  } catch (_) { return res.status(503).json({message:'Health status unavailable. Check the health migration and database access.'}); }
}
async function put(req,res) {
  let patch;
  try { patch = model.validate(req.body); }
  catch (error) { return res.status(400).json({message:error.message}); }
  let client;
  try {
    client=await pool.connect();
    await client.query('BEGIN');
    // Serialize first writes and partial merges using the existing patient row.
    const owner=await patient(client,req.actor,true);
    if (!owner) {
      await client.query('ROLLBACK');
      return res.status(409).json({message:'Save your patient profile before adding health status.'});
    }
    const result=await model.save(client,owner.profile_id,patch);
    await client.query('COMMIT');
    return res.json({health_status:result});
  } catch (_) {
    if(client) await client.query('ROLLBACK').catch(()=>{});
    return res.status(503).json({message:'Health status could not be saved.'});
  } finally { client?.release(); }
}
module.exports={get,put};
