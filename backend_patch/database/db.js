const { Pool } = require("pg");
require('./dateTypes');
require("dotenv").config();

const pool = new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    // pg requires a string; undefined causes SASL auth failures.
    password: String(process.env.DB_PASSWORD ?? ""),
});

pool.connect()
    .then(client => { client.release(); console.log("PostgreSQL Connected"); })
    .catch(() => console.error("Database connection unavailable."));

module.exports = pool;




