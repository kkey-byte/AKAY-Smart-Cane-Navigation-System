'use strict';
const {randomUUID}=require('node:crypto');
const {isDeepStrictEqual}=require('node:util');
const {batteryPercent}=require('./caneBatteryService');
const {caneCoordinates}=require('./caneCoordinates');

// The firmware record has no capture timestamp. All times below are backend
// observation times, never a claim about when the hardware sampled a location.
function parseDeviceLocation(raw) {
  if(!raw || typeof raw!=='object' || Array.isArray(raw)) return null;
  if(typeof raw.unsafe!=='boolean' || typeof raw.fallAlert!=='boolean') return null;
  const battery=batteryPercent(raw.batteryLevel);
  const coordinates=Number.isFinite(raw.latitude) && Number.isFinite(raw.longitude)
    && Math.abs(raw.latitude)<=90 && Math.abs(raw.longitude)<=180;
  return {sos:raw.unsafe,fall:raw.fallAlert,battery,
    latitude:coordinates?raw.latitude:null,longitude:coordinates?raw.longitude:null};
}

function transition(state,sample,now,{initial=false}={}) {
  const sos=sample.sos && !state.sos_active;
  let started=state.fall_started_at==null?null:new Date(state.fall_started_at).getTime();
  let notified=state.fall_notified;
  if(!sample.fall) {started=null;notified=false;}
  else if(started===null || (initial && !notified)) started=now;
  const motion=sample.fall && !notified && now-started>=3000;
  if(motion) notified=true;
  return {sos,motion,started,notified,wait:sample.fall&&!notified?Math.max(0,3000-(now-started)):null};
}

function createDeviceLocationService(pool,firebase,{onError=()=>{}}={}) {
  const watches=new Map();
  let stopped=false;
  async function save(device,sample,initial) {
    const db=await pool.connect();
    try {
      await db.query('BEGIN');
      // Custody is checked and locked for each observation, including timer reads.
      const active=await db.query(`SELECT a.id,a.device_id,a.navigator_id FROM akay_assignments a
        JOIN akay_devices d ON d.id=a.device_id AND d.owner_id=a.navigator_id
        WHERE a.id=$1 AND a.ended_at IS NULL AND d.serial=$2 FOR SHARE OF a,d`,[device.id,device.serial]);
      const assignment=active.rows[0];
      if(!assignment) {await db.query('ROLLBACK');return null;}
      await db.query('INSERT INTO akay_device_location_state(assignment_id) VALUES($1) ON CONFLICT DO NOTHING',[device.id]);
      const result=await db.query(`SELECT *,clock_timestamp() AS now FROM akay_device_location_state
        WHERE assignment_id=$1 FOR UPDATE`,[device.id]);
      const state=result.rows[0];
      const now=new Date(state.now).getTime();
      const next=sample.coordinatesOnly
        ? {sos:false,motion:false,started:state.fall_started_at==null?null:new Date(state.fall_started_at).getTime(),
          notified:state.fall_notified,wait:null}
        : transition(state,sample,now,{initial});
      if(!isDeepStrictEqual(state.payload,sample) || next.sos || next.motion) {
        const reading=await db.query(`INSERT INTO akay_readings(device_id,assignment_id,navigator_id,
          credential_id,sequence,sampled_at,latitude,longitude,battery,status,source)
          VALUES($1,$2,$3,NULL,$4,$5,$6,$7,$8,$9,'device_location') RETURNING id`,
        [assignment.device_id,assignment.id,assignment.navigator_id,Number(state.sequence)+1,new Date(now),
          sample.latitude,sample.longitude,sample.battery,sample.fall?'fault':null]);
        for(const kind of [next.sos?'sos':null,next.motion?'motion':null].filter(Boolean)) {
          await db.query(`INSERT INTO akay_alerts(reading_id,navigator_id,device_id,assignment_id,kind,event_id)
            VALUES($1,$2,$3,$4,$5,$6)`,[reading.rows[0].id,assignment.navigator_id,assignment.device_id,
            assignment.id,kind,`rtdb_${randomUUID()}`]);
        }
        state.sequence=Number(state.sequence)+1;
      }
      await db.query(`UPDATE akay_device_location_state SET sequence=$2,sos_active=$3,
        fall_started_at=$4,fall_notified=$5,payload=$6,observed_at=$7 WHERE assignment_id=$1`,
      [device.id,state.sequence,sample.coordinatesOnly?state.sos_active:sample.sos,next.started===null?null:new Date(next.started),next.notified,JSON.stringify(sample),new Date(now)]);
      await db.query('COMMIT');return next.wait;
    } catch(error) {await db.query('ROLLBACK');throw error;} finally {db.release();}
  }
  function remove(watch) {
    watch.closed=true;clearTimeout(watch.timer);
    watch.ref.off('value',watch.listener);
  }
  function watchDevice(device) {
    const ref=firebase.database().ref(`Device_Location/${device.serial}`);
    const watch={ref,serial:device.serial,closed:false,queue:Promise.resolve(),timer:null,revision:0,initial:true};
    const enqueue=(raw,revision,confirmation=false)=>{
      watch.queue=watch.queue.then(async()=>{
        if(watch.closed || (confirmation && revision!==watch.revision)) return;
        const sample=parseDeviceLocation(raw)??(caneCoordinates(raw)?{
          ...caneCoordinates(raw),battery:batteryPercent(raw.batteryLevel),coordinatesOnly:true,
        }:null);
        clearTimeout(watch.timer);
        if(!sample) {
          await pool.query(`UPDATE akay_device_location_state SET payload=NULL,fall_started_at=NULL
            WHERE assignment_id=$1`,[device.id]);
          watch.initial=true;return;
        }
        const wait=await save(device,sample,watch.initial);
        watch.initial=false;
        if(wait!==null && !watch.closed && revision===watch.revision) {
          watch.timer=setTimeout(async()=>{
            try {
              // Confirm the physical reset has not cleared the signal. Never
              // notify solely from an old snapshot or a disconnected timer.
              const snapshot=await ref.get();
              if(revision===watch.revision && !watch.closed) enqueue(snapshot.val(),revision,true);
            } catch(_) {watch.failed=true;onError();}
          },Math.max(1,wait));
          watch.timer.unref?.();
        }
      }).catch(()=>{watch.failed=true;onError();});
    };
    watch.listener=snapshot=>enqueue(snapshot.val(),++watch.revision);
    ref.on('value',watch.listener,()=>{clearTimeout(watch.timer);watch.failed=true;onError();});
    return watch;
  }
  async function reconcile() {
    if(stopped) return;
    const {rows}=await pool.query(`SELECT a.id,d.serial FROM akay_assignments a
      JOIN akay_devices d ON d.id=a.device_id AND d.owner_id=a.navigator_id WHERE a.ended_at IS NULL`);
    if(stopped) return;
    const valid=new Map(rows.filter(d=>typeof d.serial==='string' && !/[.#$\[\]/]/.test(d.serial)).map(d=>[d.id,d]));
    for(const [id,watch] of watches) {
      if(!valid.has(id) || valid.get(id).serial!==watch.serial || watch.failed) {remove(watch);watches.delete(id);}
    }
    for(const [id,device] of valid) if(!watches.has(id)) watches.set(id,watchDevice(device));
  }
  function stop() {stopped=true;for(const watch of watches.values()) remove(watch);watches.clear();}
  return {reconcile,stop};
}
module.exports={createDeviceLocationService,parseDeviceLocation,transition};
