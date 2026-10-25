const pool = require("./db");

/**
 * Validates the destination catalog. Explicit development bootstrap creates
 * empty tables only; accessibility data must be supplied and verified separately.
 */
async function ensurePlacesTable() {
  if (process.env.AKAY_ALLOW_SCHEMA_BOOTSTRAP !== 'yes') {
    await require('./schemaCatalog').resolveTable(pool,['places'],null,
      ['place_id','place_name','category','address','latitude','longitude','is_accessible','description']);
    return;
  }
  await pool.query(`
    CREATE TABLE IF NOT EXISTS places (
      place_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      place_name VARCHAR(255) NOT NULL,
      category VARCHAR(100) NOT NULL DEFAULT 'Landmark',
      address TEXT,
      latitude DOUBLE PRECISION NOT NULL,
      longitude DOUBLE PRECISION NOT NULL,
      is_accessible BOOLEAN NOT NULL DEFAULT false,
      description TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_places_name_trgm
    ON places (LOWER(place_name))
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_places_category
    ON places (LOWER(category))
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_places_coords
    ON places (latitude, longitude)
  `);


}

module.exports = ensurePlacesTable;
