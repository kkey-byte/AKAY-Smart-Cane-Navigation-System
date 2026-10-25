const express = require("express");
const pool = require("../database/db");

const router = express.Router();
const {verifyFirebase,requireProfile}=require("../middleware/identity");
router.use(verifyFirebase,requireProfile);
router.use((_req,res,next)=>{res.set("Cache-Control","no-store");next();});

router.use(async(req,res,next)=>{
    if(!["/live","/end"].includes(req.path)) return next();
    if(req.actor.role!=="visually_impaired") return res.status(403).json({message:"Navigator account required."});
    const sessionId=req.body?.sessionId||req.body?.sessionid;
    if(!/^[0-9a-f-]{36}$/i.test(sessionId||"")) return res.status(400).json({message:"Valid session ID required."});
    try {
      const result=await pool.query("SELECT sessionid FROM navigationsessions WHERE sessionid=$1 AND user_id=$2",[sessionId,req.actor.id]);
      if(!result.rows.length) return res.status(403).json({message:"Session access denied."});
      return next();
    } catch(_) {return res.status(503).json({message:"Session verification unavailable."});}
});

/** Existing table: public.navigationsessions (created outside this repo). */
const TABLE = "navigationsessions";

const nullableNumber = value => value == null || !Number.isFinite(Number(value)) ? null : Number(value);
function mapSession(row) {
  if (!row) return null;
  return {
    sessionId: row.sessionid,
    userId: row.user_id,
    deviceId: row.deviceid,
    originLatitude: nullableNumber(row.originlatitude),
    originLongitude: nullableNumber(row.originlongitude),
    originAddress: row.originaddress,
    destinationLatitude: nullableNumber(row.destinationlatitude),
    destinationLongitude: nullableNumber(row.destinationlongitude),
    destinationAddress: row.destinationaddress,
    startTime: row.starttime,
    endTime: row.endtime,
    totalDistance: nullableNumber(row.totaldistance),
    duration: nullableNumber(row.duration),
    averageSpeed: row.averagespeed != null ? Number(row.averagespeed) : null,
    status: row.status,
    createdAt: row.createdat,
    updatedAt: row.updatedat,
  };
}

/**
 * POST /api/navigation/start
 * Creates a row in navigationsessions (status = Active).
 */
router.post("/start", async (req, res) => {
  let client;
  try {
    const body = req.body || {};
    const deviceId = body.deviceId || body.deviceid;
    const originLatitude = body.originLatitude ?? body.originlatitude;
    const originLongitude = body.originLongitude ?? body.originlongitude;
    const destinationLatitude =
      body.destinationLatitude ?? body.destinationlatitude;
    const destinationLongitude =
      body.destinationLongitude ?? body.destinationlongitude;
    const originAddress = body.originAddress ?? body.originaddress ?? null;
    const destinationAddress =
      body.destinationAddress ?? body.destinationaddress ?? null;

    if (
      !deviceId ||
      ![originLatitude, originLongitude, destinationLatitude, destinationLongitude].every(v => typeof v === 'number' && Number.isFinite(v)) ||
      Math.abs(originLatitude) > 90 || Math.abs(destinationLatitude) > 90 ||
      Math.abs(originLongitude) > 180 || Math.abs(destinationLongitude) > 180
    ) {
      return res.status(400).json({
        message:
          "deviceId, originLatitude, originLongitude, destinationLatitude, and destinationLongitude are required",
      });
    }

    const resolvedUserId = req.actor.id;
    if(req.actor.role!=="visually_impaired") return res.status(403).json({message:"Only a navigator can manage their own phone navigation."});

    if (!resolvedUserId) {
      return res.status(404).json({
        message:
          "User not found. Pass a valid userId (UUID) or firebaseUid linked in Users.",
      });
    }

    if(String(deviceId)!==`phone_${req.firebase.uid}`) return res.status(400).json({message:"Legacy navigation accepts only this account's phone source, not a cane Device ID."});
    client = await pool.connect();
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1))',[req.actor.id]);
    // End any stale Active sessions for this device/user first.
    await client.query(
      `
      UPDATE ${TABLE}
      SET status = 'Cancelled',
          endtime = COALESCE(endtime, CURRENT_TIMESTAMP),
          updatedat = CURRENT_TIMESTAMP
      WHERE user_id = $1
        AND deviceid = $2
        AND status IN ('Active','Paused')
      `,
      [resolvedUserId, deviceId]
    );

    const result = await client.query(
      `
      INSERT INTO ${TABLE} (
        user_id,
        deviceid,
        originlatitude,
        originlongitude,
        originaddress,
        destinationlatitude,
        destinationlongitude,
        destinationaddress,
        starttime,
        status,
        totaldistance,
        duration,
        createdat,
        updatedat
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8,
        CURRENT_TIMESTAMP, 'Active', 0, 0,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      )
      RETURNING *
      `,
      [
        resolvedUserId,
        String(deviceId),
        Number(originLatitude),
        Number(originLongitude),
        originAddress,
        Number(destinationLatitude),
        Number(destinationLongitude),
        destinationAddress,
      ]
    );

    await client.query('COMMIT');
    const session = mapSession(result.rows[0]);
    return res.status(201).json({
      message: "Navigation session started",
      session,
    });
  } catch (err) {
    try { await client?.query('ROLLBACK'); } catch (_) {}
    return res.status(500).json({ message: "Failed to start session" });
  } finally { client?.release(); }
});

/**
 * PUT /api/navigation/live
 * Updates distance/duration/speed while Active. Live GPS coords go to Firebase RTDB on the client.
 */
router.put("/live", async (req, res) => {
  try {
    const body = req.body || {};
    const sessionId = body.sessionId || body.sessionid;
    if (!sessionId) {
      return res.status(400).json({ message: "sessionId is required" });
    }

    const totalDistance = body.totalDistance ?? body.totaldistance;
    const duration = body.duration;
    const averageSpeed = body.averageSpeed ?? body.averagespeed;
    const status = body.status; // optional: Active | Paused
    if (status != null && !['Active','Paused'].includes(status)) return res.status(400).json({message:'Invalid live session state.'});
    if (![totalDistance,duration,averageSpeed].every(v => v == null || (typeof v === 'number' && Number.isFinite(v) && v >= 0))) return res.status(400).json({message:'Summary values must be nonnegative finite numbers.'});

    const result = await pool.query(
      `
      UPDATE ${TABLE}
      SET
        totaldistance = GREATEST($2, totaldistance),
        duration = GREATEST($3, duration),
        averagespeed = COALESCE($4, averagespeed),
        status = CASE
          WHEN $5::text IS NOT NULL AND $5 = ANY (ARRAY['Active','Paused'])
          THEN $5
          ELSE status
        END,
        updatedat = CURRENT_TIMESTAMP
      WHERE sessionid = $1 AND user_id = $6
        AND status IN ('Active', 'Paused')
      RETURNING *
      `,
      [
        sessionId,
        totalDistance != null ? Number(totalDistance) : null,
        duration != null ? Number(duration) : null,
        averageSpeed != null ? Number(averageSpeed) : null,
        status || null,
        req.actor.id,
      ]
    );

    if (!result.rows[0]) {
      return res.status(404).json({ message: "Active session not found" });
    }

    return res.json({
      message: "Live session updated",
      session: mapSession(result.rows[0]),
    });
  } catch (err) {
    return res.status(500).json({ message: "Failed to update session" });
  }
});

/**
 * POST /api/navigation/end
 * Completes or cancels a session and sets endtime.
 */
router.post("/end", async (req, res) => {
  try {
    const body = req.body || {};
    const sessionId = body.sessionId || body.sessionid;
    if (!sessionId) {
      return res.status(400).json({ message: "sessionId is required" });
    }

    const requested =
      body.status === "Cancelled" || body.status === "cancelled"
        ? "Cancelled"
        : "Completed";
    const totalDistance = body.totalDistance ?? body.totaldistance;
    const duration = body.duration;
    const averageSpeed = body.averageSpeed ?? body.averagespeed;
    if (![totalDistance,duration,averageSpeed].every(v => v == null || (typeof v === 'number' && Number.isFinite(v) && v >= 0))) return res.status(400).json({message:'Summary values must be nonnegative finite numbers.'});

    const result = await pool.query(
      `
      UPDATE ${TABLE}
      SET
        status = $2,
        endtime = CURRENT_TIMESTAMP,
        totaldistance = GREATEST($3, totaldistance),
        duration = GREATEST($4, duration),
        averagespeed = COALESCE($5, averagespeed),
        updatedat = CURRENT_TIMESTAMP
      WHERE sessionid = $1 AND user_id = $6
        AND status IN ('Active', 'Paused')
      RETURNING *
      `,
      [
        sessionId,
        requested,
        totalDistance != null ? Number(totalDistance) : null,
        duration != null ? Number(duration) : null,
        averageSpeed != null ? Number(averageSpeed) : null,
        req.actor.id,
      ]
    );

    if (!result.rows[0]) {
      return res.status(404).json({ message: "Active session not found" });
    }

    return res.json({
      message: `Navigation session ${requested.toLowerCase()}`,
      session: mapSession(result.rows[0]),
    });
  } catch (err) {
    return res.status(500).json({ message: "Failed to end session" });
  }
});

/**
 * GET /api/navigation/active?userId=...
 */
router.get("/active", async (req, res) => {
  try {
    const resolvedUserId = req.actor.id;
    if(req.actor.role!=="visually_impaired") return res.status(403).json({message:"Only a navigator can manage their own phone navigation."});
    if (!resolvedUserId) {
      return res.status(404).json({ message: "User not found", sessions: [] });
    }

    const result = await pool.query(
      `
      SELECT * FROM ${TABLE}
      WHERE user_id = $1 AND status IN ('Active', 'Paused')
      ORDER BY starttime DESC
      `,
      [resolvedUserId]
    );

    return res.json({
      sessions: result.rows.map(mapSession),
    });
  } catch (err) {
    return res.status(500).json({ message: "Failed to list sessions" });
  }
});

module.exports = router;
