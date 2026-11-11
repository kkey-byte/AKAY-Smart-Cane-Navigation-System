'use strict';
const {randomUUID}=require('node:crypto');
const {ApiError}=require('./pairingService');
function createDestinationAssignment(authorize,firebase) {
  const ref=uid=>firebase.database().ref(`destination_assignments/${uid}`);
  const fail=(status,message)=>{throw new ApiError(status,'destination_assignment',message);};
  return {
    async send(actor,uid,body) {
      if(actor.role!=='caregiver'||actor.uid===uid) fail(403,'Caregiver account required.');
      const navigator=await authorize(actor,uid);
      const d=body.destination;
      if(body.navigator_id!==uid||!d||typeof d.name!=='string'||!d.name.trim()||d.name.length>300||
        typeof d.address!=='string'||d.address.length>1000||
        typeof d.latitude!=='number'||!Number.isFinite(d.latitude)||Math.abs(d.latitude)>90||
        typeof d.longitude!=='number'||!Number.isFinite(d.longitude)||Math.abs(d.longitude)>180) fail(400,'Valid navigator and destination required.');
      const assignment={id:randomUUID(),navigator_id:navigator.id,navigator_uid:uid,
        caregiver_id:actor.id,caregiver_uid:actor.uid,createdAt:Date.now(),
        destination:{name:d.name,address:d.address,latitude:d.latitude,longitude:d.longitude}};
      await ref(uid).set(assignment);
      return {assignment};
    },
    async pending(actor) {
      if(actor.role!=='visually_impaired') fail(403,'Navigator account required.');
      const assignment=(await ref(actor.uid).get()).val();
      if(!assignment) return {assignment:null};
      if(assignment.navigator_id!==actor.id||assignment.navigator_uid!==actor.uid) return {assignment:null};
      await authorize({id:assignment.caregiver_id,uid:assignment.caregiver_uid,role:'caregiver'},actor.uid);
      return {assignment};
    },
    async acknowledge(actor,id) {
      if(actor.role!=='visually_impaired') fail(403,'Navigator account required.');
      await ref(actor.uid).transaction(current=>current?.id===id&&current.navigator_id===actor.id?null:undefined);
      return {ok:true};
    },
  };
}
module.exports={createDestinationAssignment};
