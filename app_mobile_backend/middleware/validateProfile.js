'use strict';
// Shared account/profile input checks before SQL coercion or truncation.
const fields={name:100,phone:20,profilePicture:6000000,profile_picture:6000000,
  gender:50,medicalConditions:10000,medical_conditions:10000,allergies:10000,
  bloodType:16,blood_type:16,emergencyContact:250,emergency_contact:250,address:2000};
module.exports=function validateProfile(req,res,next) {
  const body=req.body;
  const invalid=()=>res.status(400).json({message:'Invalid profile fields. Use supported text lengths, whole-number age and YYYY-MM-DD birthdate.'});
  if(!body || typeof body!=='object' || Array.isArray(body)) return invalid();
  for(const [key,max] of Object.entries(fields)) {
    if(body[key]!=null && (typeof body[key]!=='string' || body[key].length>max)) return invalid();
  }
  for(const aliases of [['profilePicture','profile_picture'],['birthdate','birthDate'],['medicalConditions','medical_conditions'],['bloodType','blood_type'],['emergencyContact','emergency_contact']]) {
    if(aliases.every(key=>Object.hasOwn(body,key)) && body[aliases[0]]!==body[aliases[1]]) return invalid();
  }
  if(body.age!=null && body.age!=='' && !((typeof body.age==='number' || typeof body.age==='string' && /^\d{1,3}$/.test(body.age)) && Number.isInteger(Number(body.age)) && Number(body.age)>=0 && Number(body.age)<=150)) return invalid();
  const date=body.birthdate ?? body.birthDate;
  if(date!=null && date!=='') {
    if(typeof date!=='string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return invalid();
    const parsed=new Date(date+'T00:00:00Z');
    if(!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0,10)!==date || parsed>Date.now()) return invalid();
  }
  const picture=body.profilePicture ?? body.profile_picture;
  if(picture) {
    let safe=/^data:image\/(jpeg|png|webp|gif);base64,[A-Za-z0-9+/]+={0,2}$/.test(picture);
    try {const uri=new URL(picture);safe ||= uri.protocol==='https:' && !uri.username && !uri.password;} catch(_){}
    if(!safe) return invalid();
  }
  return next();
};
