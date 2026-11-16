'use strict';
// Reports schema/assignment readiness only. Never starts workers or sends alerts.
const pool=require('../database/db');
(async()=>{
  let db;
  try {
    const serial=process.argv[2];if(!serial) throw new Error('Missing serial');
    db=await pool.connect();await db.query('BEGIN READ ONLY');
    const schema=(await db.query(`SELECT
      to_regclass('public.akay_device_location_state') IS NOT NULL AS signal_state,
      to_regclass('public.akay_alerts') IS NOT NULL AS alerts,
      to_regclass('public.akay_alert_receipts') IS NOT NULL AS receipts,
      to_regclass('public.akay_alert_deliveries') IS NOT NULL AS push_deliveries,
      EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public'
        AND table_name='akay_readings' AND column_name='source') AS reading_source`)).rows[0];
    const assignment=(await db.query(`SELECT
      EXISTS(SELECT 1 FROM akay_devices WHERE serial=$1) AS registered,
      EXISTS(SELECT 1 FROM akay_assignments a JOIN akay_devices d ON d.id=a.device_id
        AND d.owner_id=a.navigator_id WHERE d.serial=$1 AND a.ended_at IS NULL) AS active_assignment`,[serial])).rows[0];
    await db.query('COMMIT');
    console.log(JSON.stringify({schema,assignment,readOnly:true}));
  } catch(_) {
    if(db) {try {await db.query('ROLLBACK');} catch(_) {}}
    console.error('Alert readiness check unavailable. Check existing database access and pairing/emergency/device-location migrations.');process.exitCode=1;
  } finally {db?.release();await pool.end();}
})();
