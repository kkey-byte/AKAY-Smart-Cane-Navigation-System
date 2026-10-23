const express=require('express');
const pool=require('../database/db');
const {usersTable}=require('../database/ensureUsersTable');
const {verifyFirebase}=require('../middleware/identity');
const router=express.Router();
router.use(verifyFirebase);
router.use((_req,res,next)=>{res.set('Cache-Control','no-store');next();});
const columns='user_id,firebase_uid,name,email,role,phone,profile_picture,created_at,updated_at';
router.post('/register',require('../middleware/validateProfile'),async(req,res)=>{
  const role=req.body?.role;
  if(!['caregiver','visually_impaired'].includes(role)) return res.status(400).json({message:'Recognized role required.'});
  if(!req.firebase.email || (req.body.firebase_uid && req.body.firebase_uid!==req.firebase.uid)) return res.status(403).json({message:'Firebase identity mismatch.'});
  try {
    const result=await pool.query(`INSERT INTO ${usersTable()}(firebase_uid,email,role,name,phone,profile_picture)
      VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(firebase_uid) DO NOTHING RETURNING ${columns}`,
      [req.firebase.uid,req.firebase.email.toLowerCase(),role,req.body.name||null,req.body.phone||null,req.body.profilePicture||req.body.profile_picture||null]);
    const user=result.rows[0]||(await pool.query(`SELECT ${columns} FROM ${usersTable()} WHERE firebase_uid=$1`,[req.firebase.uid])).rows[0];
    return res.status(200).json({user});
  } catch(error) {
    if(error.code==='23505') return res.status(409).json({message:'Account needs reconciliation. Registration cannot take over an existing email.'});
    return res.status(503).json({message:'Registration unavailable.'});
  }
});
router.post('/login',async(req,res)=>{
  try {
    const result=await pool.query(`SELECT ${columns} FROM ${usersTable()} WHERE firebase_uid=$1`,[req.firebase.uid]);
    if(result.rows.length!==1) return res.status(404).json({message:'No linked account profile. Complete registration.'});
    if(!['caregiver','visually_impaired'].includes(result.rows[0].role)) return res.status(403).json({message:'Account role requires reconciliation.'});
    return res.json({user:result.rows[0]});
  } catch(_) {return res.status(503).json({message:'Account lookup unavailable.'});}
});
module.exports=router;
