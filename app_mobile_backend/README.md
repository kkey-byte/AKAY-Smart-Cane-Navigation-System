# AKAY mobile backend

Node.js / Express API for the AKAY Flutter app, backed by PostgreSQL.

## Setup

1. Install Node.js and PostgreSQL.
2. From this folder, run `npm ci`.
3. Copy `.env.example` to `.env` and set your PostgreSQL credentials and a strong `JWT_SECRET`.
4. Create the PostgreSQL database specified by `DB_NAME`.
5. Run `npm start`, or `npm run dev` for automatic restarts during development.

The server defaults to port 5000 and prepares the Users, PatientProfiles, and places tables at startup. Additional SQL and database inspection utilities are in `database/` and `scripts/`.

API route prefixes: `/api/auth`, `/api/search`, `/api/navigation`, and `/api/profile`.

Configure the Flutter app to use this server's reachable address. For a physical device, use the host computer's LAN address and allow the configured port through its firewall.

Local secrets, installed dependencies, and uploaded files are excluded from Git.
