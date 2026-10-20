const pool = require("./db");

/**
 * Ensures the AKAY custom destinations table exists and seeds a few
 * accessible Panabo-area places when empty.
 */
async function ensurePlacesTable() {
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

  const count = await pool.query(`SELECT COUNT(*)::int AS c FROM places`);
  if ((count.rows[0]?.c ?? 0) === 0) {
    await pool.query(`
      INSERT INTO places
        (place_name, category, address, latitude, longitude, is_accessible, description)
      VALUES
        ('AKAY Safe Waiting Area', 'Landmark', 'DNSC Campus, Panabo City',
         7.3128, 125.6825, true,
         'Accessible waiting area with ramp and tactile path guidance.'),
        ('Panabo City Hall Accessible Entrance', 'Government Office', 'Quezon Avenue, Panabo City',
         7.3089, 125.6834, true,
         'Main accessible entrance with ramp and audio assistance point.'),
        ('Panabo Health Center', 'Hospital', 'Panabo City',
         7.3048, 125.6880, true,
         'Clinic with wheelchair access and accessible comfort room.'),
        ('PWD Assistance Desk', 'Government Office', 'Panabo City Hall Annex',
         7.3092, 125.6838, true,
         'PWD desk with audio assistance and accessible waiting area.'),
        ('Evacuation Center – New Visayas', 'Landmark', 'New Visayas, Panabo City',
         7.3120, 125.6788, true,
         'Emergency meeting point with accessible pathways.'),
        ('DNSC Main Gate Accessible Path', 'University', 'DNSC, Panabo City',
         7.3115, 125.6810, true,
         'Campus entrance with tactile path and ramp.'),
        ('Panabo Public Market Accessible CR', 'Market', 'Public Market, Panabo City',
         7.3060, 125.6855, true,
         'Accessible comfort room near market entrance.'),
        ('City Police Station Lobby', 'Police', 'City Police Station, Panabo City',
         7.3075, 125.6810, true,
         'Accessible lobby and waiting area.')
    `);
    console.log("✅ Places table seeded with AKAY sample destinations");
  }

  console.log("✅ Places table ready");
}

module.exports = ensurePlacesTable;
