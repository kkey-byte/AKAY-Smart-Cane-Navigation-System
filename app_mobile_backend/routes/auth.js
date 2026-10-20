const express = require("express");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("../database/db");
const { usersTable } = require("../database/ensureUsersTable");

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

function normalizeRole(role) {
  const value = String(role || "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "_");

  if (value === "caregiver") return "caregiver";
  if (
    value === "navigator" ||
    value === "vi" ||
    value === "visually_impaired" ||
    value.includes("visually_impaired")
  ) {
    return "visually_impaired";
  }
  return null;
}

function signToken(user) {
  return jwt.sign(
    {
      user_id: user.user_id,
      firebase_uid: user.firebase_uid,
      role: user.role,
    },
    process.env.JWT_SECRET || "gabay-dev-secret",
    { expiresIn: "7d" }
  );
}

/**
 * POST /api/auth/register
 * Body: { firebase_uid, email, password, role, name?, phone?, profile_picture? }
 * Firebase owns auth; Postgres also stores a bcrypt hash of password.
 */
router.post("/register", async (req, res) => {
  try {
    const body = req.body || {};
    console.log("POST /api/auth/register keys:", Object.keys(body));

    const email = body.email;
    const uid = body.firebase_uid || body.firebaseUid || body.uid;
    const password = body.password;
    const role = body.role;
    const name = body.name;
    const phone = body.phone;
    const profilePicture = body.profile_picture || body.profilePicture;

    const missing = [];
    if (!email) missing.push("email");
    if (!uid) missing.push("firebase_uid");
    if (!role) missing.push("role");
    if (!password) missing.push("password");

    if (missing.length > 0) {
      return res.status(400).json({
        message: `Missing required field(s): ${missing.join(", ")}`,
        received_keys: Object.keys(body),
      });
    }

    if (String(password).length < 6) {
      return res.status(400).json({
        message: "Password must be at least 6 characters",
      });
    }

    const normalizedRole = normalizeRole(role);
    if (!normalizedRole) {
      return res.status(400).json({
        message: "role must be 'caregiver' or 'visually_impaired'",
      });
    }

    const table = usersTable();
    const normalizedEmail = String(email).trim().toLowerCase();
    const passwordHash = await bcrypt.hash(String(password), 10);

    // Upsert: insert new row, or attach firebase_uid / password hash to existing email
    const result = await pool.query(
      `
        INSERT INTO ${table}
          (firebase_uid, name, email, password, role, phone, profile_picture)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (email) DO UPDATE SET
          firebase_uid = COALESCE(EXCLUDED.firebase_uid, ${table}.firebase_uid),
          password = EXCLUDED.password,
          role = EXCLUDED.role,
          name = COALESCE(EXCLUDED.name, ${table}.name),
          phone = COALESCE(EXCLUDED.phone, ${table}.phone),
          profile_picture = COALESCE(EXCLUDED.profile_picture, ${table}.profile_picture),
          updated_at = CURRENT_TIMESTAMP
        RETURNING user_id, firebase_uid, name, email, role, phone,
                  profile_picture, created_at, updated_at
      `,
      [
        uid,
        name || null,
        normalizedEmail,
        passwordHash,
        normalizedRole,
        phone || null,
        profilePicture || null,
      ]
    );

    const user = mapUser(result.rows[0]);
    return res.status(201).json({ user, token: signToken(user) });
  } catch (err) {
    console.error("register error:", err);

    // Unique firebase_uid conflict — return existing profile
    if (err.code === "23505") {
      try {
        const table = usersTable();
        const uid = (req.body || {}).firebase_uid || (req.body || {}).firebaseUid;
        const email = (req.body || {}).email;
        const existing = await pool.query(
          `
            SELECT * FROM ${table}
            WHERE firebase_uid = $1 OR LOWER(email) = LOWER($2)
            LIMIT 1
          `,
          [uid || null, email || ""]
        );
        if (existing.rows[0]) {
          const user = mapUser(existing.rows[0]);
          return res.status(200).json({ user, token: signToken(user) });
        }
      } catch (_) {}
    }

    return res.status(500).json({
      message: err.message || "Registration failed",
    });
  }
});

/**
 * POST /api/auth/login
 * Body: { firebase_uid }
 */
router.post("/login", async (req, res) => {
  try {
    const body = req.body || {};
    const uid = body.firebase_uid || body.firebaseUid || body.uid;
    const email = body.email ? String(body.email).trim().toLowerCase() : "";

    if (!uid && !email) {
      return res.status(400).json({
        message: "firebase_uid is required",
        received_keys: Object.keys(body),
      });
    }

    const table = usersTable();
    const result = await pool.query(
      `
        SELECT * FROM ${table}
        WHERE ($1::text IS NOT NULL AND firebase_uid = $1)
           OR ($2::text <> '' AND LOWER(email) = $2)
        LIMIT 1
      `,
      [uid || null, email]
    );
    const row = result.rows[0];

    if (!row) {
      return res.status(404).json({
        message:
          "No profile found for this Firebase account. Please sign up again.",
      });
    }

    const user = mapUser(row);
    return res.json({ user, token: signToken(user) });
  } catch (err) {
    console.error("login error:", err);
    return res.status(500).json({
      message: err.message || "Login failed",
    });
  }
});

module.exports = router;
