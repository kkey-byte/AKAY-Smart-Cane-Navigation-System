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
const pairingRoutes = require("./routes/pairing");

const app = express();
const {corsOptions,initializeStorage,storageGuard}=require('./services/httpPolicy');
let storage={profileReady:false,searchReady:false};

if (process.env.RENDER === "true") {
    app.set("trust proxy", 1);
} else if (process.env.TRUSTED_PROXY_CIDRS) {
    app.set(
        "trust proxy",
        process.env.TRUSTED_PROXY_CIDRS
            .split(",")
            .map(value => value.trim())
            .filter(Boolean)
    );
}
app.use((req,res,next)=>{
    if(process.env.NODE_ENV==='production' && !req.secure) return res.status(426).json({message:'HTTPS is required.'});
    return next();
});
app.use('/api/v2',express.json({limit:'16kb'}));
app.use(cors(corsOptions()));
// Profile pictures may be sent as compressed base64 data URLs.
app.use(express.json({ limit: "8mb" }));
app.use(express.urlencoded({ extended: true, limit: "8mb" }));

app.get("/", (req, res) => {
    res.set('X-Akay-Auth-Contract','firebase-id-token-v2');
    res.send("AKAY Backend Running");
});


// Flutter AuthService calls: POST /api/auth/register and /api/auth/login
app.use("/api/auth", authRoutes);
// Destination search: Nominatim + PostgreSQL places
app.use("/api/search",storageGuard(()=>storage.searchReady,'Search'), searchRoutes);
// Navigation sessions → PostgreSQL navigationsessions
app.use("/api/routing", require("./routes/routing"));
app.use("/api/navigation", navigationRoutes);
// Progressive profile completion → Users + patientprofiles
app.use("/api/profile",storageGuard(()=>storage.profileReady,'Profile'), profileRoutes);
app.use('/api/health-status', storageGuard(()=>storage.profileReady,'Health status'), require('./routes/healthStatus'));
app.use("/api/v2", pairingRoutes);

app.use((error,_req,res,_next)=> {
    const status = error.type === 'entity.too.large' ? 413 : error.type === 'entity.parse.failed' ? 400 : 503;
    res.status(status).json({message: status === 413 ? 'Request too large.' : status === 400 ? 'Invalid JSON request.' : 'Service unavailable.'});
});

const PORT = process.env.PORT || 5000;

async function start() {
    try {
        if(process.env.NODE_ENV==='production' && process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP==='yes') throw new Error('Production schema bootstrap is disabled; use reviewed migrations.');
        storage=await initializeStorage({accounts:ensureUsersTable,profiles:ensurePatientProfilesTable,places:ensurePlacesTable});
        if(!storage.profileReady) console.warn('Profile routes unavailable until the approved patient table/schema is configured. Authentication remains available.');
        if(!storage.searchReady) console.warn('Search routes unavailable until the catalog schema is configured.');
    } catch (err) {
        console.error('Failed to prepare database tables.');
        console.error("Check DB_* values in .env, then restart the server.");
        process.exit(1);
    }

    app.listen(PORT, "0.0.0.0", () => {
        console.log(`Server running on port ${PORT}`);
    });
}

start();
