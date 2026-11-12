'use strict';
const {ApiError}=require('./pairingService');
const validId=id=>typeof id==='string'&&/^[a-zA-Z0-9_-]{1,128}$/.test(id);
function arrived(destination,fix,now=Date.now()) {
  if(!fix||!Number.isFinite(fix.accuracy)||fix.accuracy<0||fix.accuracy>35||
    !Number.isSafeInteger(fix.timestamp)||fix.timestamp<now-45000||fix.timestamp>now+30000||
    !Number.isFinite(fix.latitude)||Math.abs(fix.latitude)>90||!Number.isFinite(fix.longitude)||Math.abs(fix.longitude)>180) return false;
  const rad=x=>x*Math.PI/180;
  const a=Math.sin(rad(fix.latitude-destination.latitude)/2)**2+
    Math.cos(rad(fix.latitude))*Math.cos(rad(destination.latitude))*Math.sin(rad(fix.longitude-destination.longitude)/2)**2;
  return 6371000*2*Math.asin(Math.sqrt(Math.min(1,a)))<=35;
}
function createDestinationProgress(authorize,firebase,pool) {
  const ref=path=>firebase.database().ref(path);
  const current=uid=>ref(`destination_progress/${uid}`);
  async function clearPending(uid,id,navigatorId) {
    await ref(`destination_assignments/${uid}`).transaction(old=>
      old?.id===id&&old.navigator_id===navigatorId?null:undefined);
  }
  async function send(message) {
    let timer;
    try {
      await Promise.race([Promise.resolve().then(()=>firebase.messaging().send(message)),new Promise((_,reject)=>{
        timer=setTimeout(()=>reject(new Error('Push timed out.')),10000);
      })]);
    } finally {clearTimeout(timer);}
  }
  async function finish(actor,id,status) {
    if(actor.role!=='visually_impaired'||!validId(id)) throw new ApiError(403,'navigator_required','Navigator account required.');
    const value=(await current(actor.uid).get()).val();
    if(!value||value.id!==id||value.navigator_id!==actor.id) return {accepted:false};
    const navigator=await authorize({id:value.caregiver_id,uid:value.caregiver_uid,role:'caregiver'},actor.uid);
    if(value.notified) {
      await clearPending(actor.uid,id,actor.id);
      return {accepted:true};
    }
    if(status==='not_arrived'&&!value.outcome) {
      const fix=(await ref(`phone_location/${actor.uid}`).get()).val();
      if(fix?.enabled!==false&&fix?.timestamp>=value.createdAt&&arrived(value.destination,fix)) status='arrived';
    }
    await current(actor.uid).transaction(old=>old?.id===id&&!old.outcome?{...old,outcome:status,finishedAt:Date.now()}:undefined);
    const saved=(await current(actor.uid).get()).val();
    if(saved?.id!==id||!saved.outcome) return {accepted:false};
    await clearPending(actor.uid,id,actor.id);
    const notification={id,navigator_uid:actor.uid,caregiver_uid:saved.caregiver_uid,caregiver_id:saved.caregiver_id,
      navigatorName:navigator.name||'Your navigator',status:saved.outcome,createdAt:saved.finishedAt};
    // Stable keys make retries safe after an uncertain network response.
    await ref(`destination_notifications/${saved.caregiver_uid}/${id}`).transaction(old=>old||notification);
    await ref(`destination_push_queue/${id}`).transaction(old=>old||{...notification,nextAttemptAt:0});
    await current(actor.uid).transaction(old=>old?.id===id?{...old,notified:true}:undefined);
    return {accepted:true};
  }
  return {
    async start(assignment) {
      const previous=(await current(assignment.navigator_uid).get()).val();
      if(previous&&!previous.outcome) {
        try {await finish({id:previous.navigator_id,uid:previous.navigator_uid,role:'visually_impaired'},previous.id,'not_arrived');}
        catch(error) {if(error.status!==403&&error.status!==404) throw error;}
      }
      await current(assignment.navigator_uid).set(assignment);
    },
    async location(actor,fix) {
      const value=(await current(actor.uid).get()).val();
      if(!value||value.navigator_id!==actor.id) return;
      if(value.outcome) {
        if(!value.notified) await finish(actor,value.id,value.outcome);
        return;
      }
      if(fix.timestamp>=value.createdAt&&arrived(value.destination,fix)) await finish(actor,value.id,'arrived');
    },
    cancel:(actor,id)=>finish(actor,id,'not_arrived'),
    async list(actor) {
      if(actor.role!=='caregiver') throw new ApiError(403,'caregiver_required','Caregiver account required.');
      const values=(await ref(`destination_notifications/${actor.uid}`).orderByChild('createdAt').limitToLast(100).get()).val()||{};
      const notifications=[];
      for(const value of Object.values(values)) {
        if(value.caregiver_id!==actor.id) continue;
        try {await authorize(actor,value.navigator_uid);} catch(error) {if(error.status===403||error.status===404) continue;throw error;}
        notifications.push(value);
      }
      return {notifications:notifications.sort((a,b)=>b.createdAt-a.createdAt)};
    },
    async receipt(actor,id,action) {
      if(!validId(id)||!['read','dismiss'].includes(action)) throw new ApiError(400,'invalid_response','Invalid notification response.');
      const {notifications}=await this.list(actor);
      if(!notifications.some(n=>n.id===id)) throw new ApiError(403,'access_revoked','Active navigator consent required.');
      await ref(`destination_notifications/${actor.uid}/${id}`).update(action==='read'?{isRead:true}:{dismissed:true});
      return {accepted:true};
    },
    async dispatch() {
      const jobs=(await ref('destination_push_queue').orderByChild('nextAttemptAt').endAt(Date.now()).limitToFirst(20).get()).val()||{};
      for(const job of Object.values(jobs)) {
        const queue=ref(`destination_push_queue/${job.id}`);
        if(Date.now()-job.createdAt>86400000) {await queue.remove();continue;}
        try {
          await authorize({id:job.caregiver_id,uid:job.caregiver_uid,role:'caregiver'},job.navigator_uid);
          const tokens=await pool.query('SELECT token,token_hash FROM akay_push_tokens WHERE caregiver_id=$1',[job.caregiver_id]);
          for(const token of tokens.rows) {
            if(job.sent?.[token.token_hash]) continue;
            await send({token:token.token,notification:{title:job.status==='arrived'?'Navigator arrived':'Navigator has not arrived',
              body:job.status==='arrived'?'Your navigator reached the assigned destination.':'Navigation to the assigned destination was cancelled before arrival.'},
              data:{type:'destination_progress',notificationId:job.id},android:{priority:'high'},apns:{payload:{aps:{sound:'default'}}}});
            await queue.child(`sent/${token.token_hash}`).set(true);
          }
          // Retain jobs without tokens so later device registration can receive them.
          if(tokens.rows.length) await queue.remove();
          else await queue.update({nextAttemptAt:Date.now()+30000});
        } catch(error) {
          if(error.status===403||error.status===404) await queue.remove();
          else await queue.update({nextAttemptAt:Date.now()+30000});
        }
      }
    },
  };
}
module.exports={createDestinationProgress,arrived};
