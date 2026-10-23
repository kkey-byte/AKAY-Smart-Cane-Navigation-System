const express = require("express");
const cors = require("cors");
require("dotenv").config();

const pool = require("./database/db");
const ensureUsersTable = require("./database/ensureUsersTable");
const ensurePlacesTable = require("./database/ensurePlacesTable");
const ensurePatientProfilesTable = require("./database/ensurePatientProfilesTable");
const authRoutes = require("./routes/auth");
const searchRoutes = require("./routes/search");
const navigationRoutes = require("./routes/navigation");
const profileRoutes = require("./routes/profile");

const app = express();

if (process.env.RAILWAY_ENVIRONMENT_ID) {
    app.set("trust proxy", 1);
}

app.use(cors({ origin: true, credentials: true }));
// Profile pictures may be sent as compressed base64 data URLs.
app.use(express.json({ limit: "8mb" }));
app.use(express.urlencoded({ extended: true, limit: "8mb" }));

app.get("/", (req, res) => {
    res.send("AKAY Backend Running");
});

app.get("/test-db", async (req, res) => {
    try {
        const result = await pool.query("SELECT NOW()");
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({
            message: "Database Error"
        });
    }
});

// Flutter AuthService calls: POST /api/auth/register and /api/auth/login
app.use("/api/auth", authRoutes);
// Destination search: Nominatim + PostgreSQL places
app.use("/api/search", searchRoutes);
// Navigation sessions → PostgreSQL navigationsessions
app.use("/api/navigation", navigationRoutes);
// Progressive profile completion → Users + PatientProfiles
app.use("/api/profile", profileRoutes);

const PORT = process.env.PORT || 5000;

async function start() {
    try {
        // Create "Users" if missing — required before signup/login can work
        await ensureUsersTable();
        await ensurePatientProfilesTable();
        await ensurePlacesTable();
    } catch (err) {
        console.error('❌ Failed to prepare database tables:', err.message);
        console.error("Check DB_* values in .env, then restart the server.");
        process.exit(1);
    }

    app.listen(PORT, "0.0.0.0", () => {
        console.log(`Server running on port ${PORT}`);
    });
}

start();
