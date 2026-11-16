'use strict';
function batteryPercent(value) {
  if(typeof value!=='number' || !Number.isFinite(value) || value<0 || value>100) return null;
  // Existing firmware has emitted fractions and percentage readings. Preserve
  // the confirmed fraction contract while accepting current 0..100 telemetry.
  return Math.round(value<=1?value*100:value);
}
function createCaneBatteryService(pool,firebase,{timeoutMs=4000,clock=Date.now,includeSignals=false}={}) {
  async function readFlag(serial,field) {
    let timer;
    try {
      const snapshot=await Promise.race([
        Promise.resolve().then(()=>firebase.database().ref(`Device_Location/${serial}/${field}`).get()),
        new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Signal read timeout')),timeoutMs);}),
      ]);
      const value=snapshot.val();return typeof value==='boolean'?value:null;
    } catch(_) {return null;} finally {clearTimeout(timer);}
  }
  async function readDevices(devices) {
    return Promise.all(devices.map(async device=>{
      let timer;
      const result={id:device.id,assignment_id:device.assignment_id,serial:device.serial,battery:null,observedAt:null};
      if(typeof device.serial!=='string' || !device.serial || /[.#$\[\]/]/.test(device.serial)) return result;
      const signals=includeSignals?Promise.all([readFlag(device.serial,'unsafe'),readFlag(device.serial,'fallAlert')]):null;
      try {
        const snapshot=await Promise.race([
          Promise.resolve().then(()=>firebase.database().ref(`Device_Location/${device.serial}/batteryLevel`).get()),
          new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Battery read timeout')),timeoutMs);}),
        ]);
        result.battery=batteryPercent(snapshot.val());
        if(result.battery!==null) result.observedAt=new Date(clock()).toISOString();
      } catch(_) { /* Never substitute a stored or example battery on failure. */ }
      finally {clearTimeout(timer);}
      if(signals) {
        [result.sos,result.fall]=await signals;
        result.signalsObservedAt=result.sos!==null||result.fall!==null?new Date(clock()).toISOString():null;
      }
      return result;
    }));
  }
  async function read(navigator) {
    const {rows}=await pool.query(`SELECT d.id,d.serial,a.id AS assignment_id FROM akay_assignments a
      JOIN akay_devices d ON d.id=a.device_id AND d.owner_id=a.navigator_id
      WHERE a.navigator_id=$1 AND a.ended_at IS NULL ORDER BY a.started_at DESC,a.id DESC` ,[navigator.id]);
    return readDevices(rows);
  }
  return {read,readDevices};
}
module.exports={createCaneBatteryService,batteryPercent};
