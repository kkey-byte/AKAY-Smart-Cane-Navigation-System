const express = require("express");
const pool = require("../database/db");
const { usersTable } = require("../database/ensureUsersTable");

const router = express.Router();

/** Existing table: public.navigationsessions (created outside this repo). */
const TABLE = "navigationsessions";

function mapSession(row) {
  if (!row) return null;
  return {
    sessionId: row.sessionid,
    userId: row.user_id,
    deviceId: row.deviceid,
    originLatitude: Number(row.originlatitude),
    originLongitude: Number(row.originlongitude),
    originAddress: row.originaddress,
    destinationLatitude: Number(row.destinationlatitude),
    destinationLongitude: Number(row.destinationlongitude),
    destinationAddress: row.destinationaddress,
    startTime: row.starttime,
    endTime: row.endtime,
    totalDistance: row.totaldistance != null ? Number(row.totaldistance) : 0,
    duration: row.duration != null ? Number(row.duration) : 0,
    averageSpeed: row.averagespeed != null ? Number(row.averagespeed) : null,
    status: row.status,
    createdAt: row.createdat,
    updatedAt: row.updatedat,
  };
}

async function resolveUserId({ userId, firebaseUid }) {
  if (userId) {
    const byId = await pool.query(
      `SELECT user_id FROM ${usersTable()} WHERE user_id = $1 LIMIT 1`,
      [userId]
    );
    if (byId.rows[0]) return byId.rows[0].user_id;
  }

  if (firebaseUid) {
    const byFb = await pool.query(
      `SELECT user_id FROM ${usersTable()} WHERE firebase_uid = $1 LIMIT 1`,
      [firebaseUid]
    );
    if (byFb.rows[0]) return byFb.rows[0].user_id;
  }

  return null;
}

/**
 * POST /api/navigation/start
 * Creates a row in navigationsessions (status = Active).
 */
router.post("/start", async (req, res) => {
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
      originLatitude == null ||
      originLongitude == null ||
      destinationLatitude == null ||
      destinationLongitude == null
    ) {
      return res.status(400).json({
        message:
          "deviceId, originLatitude, originLongitude, destinationLatitude, and destinationLongitude are required",
      });
    }

    const resolvedUserId = await resolveUserId({
      userId: body.userId || body.user_id,
      firebaseUid: body.firebaseUid || body.firebase_uid,
    });

    if (!resolvedUserId) {
      return res.status(404).json({
        message:
          "User not found. Pass a valid userId (UUID) or firebaseUid linked in Users.",
      });
    }

    // End any stale Active sessions for this device/user first.
    await pool.query(
      `
      UPDATE ${TABLE}
      SET status = 'Cancelled',
          endtime = COALESCE(endtime, CURRENT_TIMESTAMP),
          updatedat = CURRENT_TIMESTAMP
      WHERE user_id = $1
        AND deviceid = $2
        AND status = 'Active'
      `,
      [resolvedUserId, deviceId]
    );

    const result = await pool.query(
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

    const session = mapSession(result.rows[0]);
    return res.status(201).json({
      message: "Navigation session started",
      session,
    });
  } catch (err) {
    console.error("POST /api/navigation/start:", err.message);
    return res.status(500).json({ message: err.message || "Failed to start session" });
  }
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

    const result = await pool.query(
      `
      UPDATE ${TABLE}
      SET
        totaldistance = COALESCE($2, totaldistance),
        duration = COALESCE($3, duration),
        averagespeed = COALESCE($4, averagespeed),
        status = CASE
          WHEN $5::text IS NOT NULL AND $5 = ANY (ARRAY['Active','Paused'])
          THEN $5
          ELSE status
        END,
        updatedat = CURRENT_TIMESTAMP
      WHERE sessionid = $1
        AND status IN ('Active', 'Paused')
      RETURNING *
      `,
      [
        sessionId,
        totalDistance != null ? Number(totalDistance) : null,
        duration != null ? Number(duration) : null,
        averageSpeed != null ? Number(averageSpeed) : null,
        status || null,
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
    console.error("PUT /api/navigation/live:", err.message);
    return res.status(500).json({ message: err.message || "Failed to update session" });
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

    const result = await pool.query(
      `
      UPDATE ${TABLE}
      SET
        status = $2,
        endtime = CURRENT_TIMESTAMP,
        totaldistance = COALESCE($3, totaldistance),
        duration = COALESCE($4, duration),
        averagespeed = COALESCE($5, averagespeed),
        updatedat = CURRENT_TIMESTAMP
      WHERE sessionid = $1
        AND status IN ('Active', 'Paused')
      RETURNING *
      `,
      [
        sessionId,
        requested,
        totalDistance != null ? Number(totalDistance) : null,
        duration != null ? Number(duration) : null,
        averageSpeed != null ? Number(averageSpeed) : null,
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
    console.error("POST /api/navigation/end:", err.message);
    return res.status(500).json({ message: err.message || "Failed to end session" });
  }
});

/**
 * GET /api/navigation/active?userId=...
 */
router.get("/active", async (req, res) => {
  try {
    const userId = req.query.userId || req.query.user_id;
    const firebaseUid = req.query.firebaseUid || req.query.firebase_uid;
    const resolvedUserId = await resolveUserId({ userId, firebaseUid });
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
    console.error("GET /api/navigation/active:", err.message);
    return res.status(500).json({ message: err.message || "Failed to list sessions" });
  }
});

module.exports = router;
