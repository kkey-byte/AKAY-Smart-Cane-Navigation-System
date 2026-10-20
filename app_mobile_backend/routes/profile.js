const express = require("express");
const pool = require("../database/db");
const { usersTable } = require("../database/ensureUsersTable");
const {
  patientProfilesTable,
} = require("../database/ensurePatientProfilesTable");

const router = express.Router();

function mapUser(row) {
  return {
    user_id: row.user_id,
    firebase_uid: row.firebase_uid,
    name: row.name,
    email: row.email,
    role: row.role,
    phone: row.phone,
    profile_picture: row.profile_picture,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

function mapPatient(row) {
  if (!row) return null;
  return {
    profileId: row.profile_id,
    userId: row.user_id,
    age: row.age,
    gender: row.gender,
    birthdate: row.birthdate,
    medicalConditions: row.medical_conditions,
    allergies: row.allergies,
    bloodType: row.blood_type,
    emergencyContact: row.emergency_contact,
    address: row.address,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function resolveUserId({ userId, firebaseUid }) {
  const table = usersTable();
  if (userId) {
    const byId = await pool.query(
      `SELECT user_id FROM ${table} WHERE user_id = $1 LIMIT 1`,
      [userId]
    );
    if (byId.rows[0]) return byId.rows[0].user_id;
  }
  if (firebaseUid) {
    const byFb = await pool.query(
      `SELECT user_id FROM ${table} WHERE firebase_uid = $1 LIMIT 1`,
      [firebaseUid]
    );
    if (byFb.rows[0]) return byFb.rows[0].user_id;
  }
  return null;
}

function parseBirthdate(value) {
  if (value == null || value === "") return null;
  // Accept YYYY-MM-DD directly without timezone shift.
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value.trim())) {
    return value.trim();
  }
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function computeAge(birthdate) {
  if (!birthdate) return null;
  const d = new Date(`${birthdate}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) return null;
  const today = new Date();
  let age = today.getUTCFullYear() - d.getUTCFullYear();
  const m = today.getUTCMonth() - d.getUTCMonth();
  if (m < 0 || (m === 0 && today.getUTCDate() < d.getUTCDate())) age -= 1;
  return age >= 0 ? age : null;
}

function isProfileComplete(user, patient) {
  const hasAccount =
    Boolean(user?.name && String(user.name).trim()) &&
    Boolean(user?.phone && String(user.phone).trim());
  const hasHealth =
    Boolean(patient?.birthdate) &&
    Boolean(patient?.gender && String(patient.gender).trim()) &&
    Boolean(patient?.blood_type || patient?.bloodType);
  return hasAccount && hasHealth;
}

/**
 * GET /api/profile?userId=...&firebaseUid=...
 */
router.get("/", async (req, res) => {
  try {
    const resolvedUserId = await resolveUserId({
      userId: req.query.userId || req.query.user_id,
      firebaseUid: req.query.firebaseUid || req.query.firebase_uid,
    });
    if (!resolvedUserId) {
      return res.status(404).json({ message: "User not found" });
    }

    const users = usersTable();
    const patients = patientProfilesTable();

    const userResult = await pool.query(
      `SELECT * FROM ${users} WHERE user_id = $1 LIMIT 1`,
      [resolvedUserId]
    );
    const user = userResult.rows[0];
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const patientResult = await pool.query(
      `SELECT * FROM ${patients} WHERE user_id = $1 LIMIT 1`,
      [resolvedUserId]
    );

    const patient = patientResult.rows[0] || null;

    return res.json({
      user: mapUser(user),
      patientProfile: mapPatient(patient),
      profileComplete: isProfileComplete(user, patient),
      _meta: { patientTable: patients },
    });
  } catch (err) {
    console.error("GET /api/profile:", err.message);
    return res.status(500).json({ message: err.message || "Failed to load profile" });
  }
});

/**
 * PUT /api/profile
 * Transactional update into Users + patientprofiles.
 */
router.put("/", async (req, res) => {
  const client = await pool.connect();
  try {
    const body = req.body || {};
    console.log("PUT /api/profile body keys:", Object.keys(body));

    const resolvedUserId = await resolveUserId({
      userId: body.userId || body.user_id,
      firebaseUid: body.firebaseUid || body.firebase_uid,
    });

    if (!resolvedUserId) {
      return res.status(404).json({
        message:
          "User not found. Pass a valid userId or firebaseUid linked in Users.",
      });
    }

    const name = body.name ?? null;
    const phone = body.phone ?? null;
    const profilePicture =
      body.profilePicture ?? body.profile_picture ?? null;

    const birthdate = parseBirthdate(body.birthdate ?? body.birthDate);
    const ageFromBody =
      body.age != null && body.age !== "" ? Number(body.age) : null;
    let age = Number.isFinite(ageFromBody) ? ageFromBody : computeAge(birthdate);
    if (age != null && age < 0) age = 0;

    const gender = body.gender ?? null;
    const medicalConditions =
      body.medicalConditions ?? body.medical_conditions ?? null;
    const allergies = body.allergies ?? null;
    const bloodType = body.bloodType ?? body.blood_type ?? null;
    let emergencyContact =
      body.emergencyContact ?? body.emergency_contact ?? null;
    // patientprofiles.emergency_contact may be varchar — keep it reasonable.
    if (typeof emergencyContact === "string" && emergencyContact.length > 250) {
      emergencyContact = emergencyContact.slice(0, 250);
    }
    const address = body.address ?? null;

    const users = usersTable();
    const patients = patientProfilesTable();

    await client.query("BEGIN");

    const pictureValue =
      profilePicture != null && String(profilePicture).trim() !== ""
        ? String(profilePicture).trim()
        : null;

    const userResult = await client.query(
      `
      UPDATE ${users}
      SET
        name = COALESCE($2, name),
        phone = COALESCE($3, phone),
        profile_picture = CASE
          WHEN $4::text IS NOT NULL THEN $4
          ELSE profile_picture
        END,
        updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
      RETURNING *
      `,
      [
        resolvedUserId,
        name != null && String(name).trim() !== "" ? String(name).trim() : null,
        phone != null && String(phone).trim() !== "" ? String(phone).trim() : null,
        pictureValue,
      ]
    );

    if (!userResult.rows[0]) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "User not found" });
    }

    // Upsert without relying solely on ON CONFLICT (works even if unique
    // constraint name differs). Prefer update-then-insert for clarity.
    const existing = await client.query(
      `SELECT profile_id FROM ${patients} WHERE user_id = $1 LIMIT 1`,
      [resolvedUserId]
    );

    let patientResult;
    if (existing.rows[0]) {
      patientResult = await client.query(
        `
        UPDATE ${patients}
        SET
          age = $2,
          gender = $3,
          birthdate = $4,
          medical_conditions = $5,
          allergies = $6,
          blood_type = $7,
          emergency_contact = $8,
          address = $9,
          updated_at = CURRENT_TIMESTAMP
        WHERE user_id = $1
        RETURNING *
        `,
        [
          resolvedUserId,
          age,
          gender,
          birthdate,
          medicalConditions,
          allergies,
          bloodType,
          emergencyContact,
          address,
        ]
      );
    } else {
      patientResult = await client.query(
        `
        INSERT INTO ${patients} (
          user_id,
          age,
          gender,
          birthdate,
          medical_conditions,
          allergies,
          blood_type,
          emergency_contact,
          address,
          created_at,
          updated_at
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9,
          CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
        RETURNING *
        `,
        [
          resolvedUserId,
          age,
          gender,
          birthdate,
          medicalConditions,
          allergies,
          bloodType,
          emergencyContact,
          address,
        ]
      );
    }

    await client.query("COMMIT");

    const user = userResult.rows[0];
    const patient = patientResult.rows[0];

    console.log(
      `PUT /api/profile saved user=${resolvedUserId} patient=${patient?.profile_id} table=${patients}`
    );

    return res.json({
      message: "Profile saved successfully",
      user: mapUser(user),
      patientProfile: mapPatient(patient),
      profileComplete: isProfileComplete(user, patient),
      _meta: { patientTable: patients },
    });
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {
      // ignore
    }
    console.error("PUT /api/profile:", err.message);
    return res.status(500).json({
      message: err.message || "Failed to save profile",
    });
  } finally {
    client.release();
  }
});

module.exports = router;
