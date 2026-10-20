/**
 * AKAY destination search: Nominatim (OSM) + PostgreSQL places,
 * merged, de-duplicated, distance-ranked, accessibility-aware.
 */

const pool = require("../database/db");

const NOMINATIM_BASE = "https://nominatim.openstreetmap.org";
const USER_AGENT = "AKAY-GABAY/1.0 (accessibility-navigation-app)";

/** Category keyword → Nominatim amenity / search boost terms */
const CATEGORY_QUERIES = {
  hospital: "hospital clinic",
  restaurant: "restaurant",
  school: "school",
  atm: "atm",
  bank: "bank",
  police: "police",
  "fire station": "fire_station",
  church: "place_of_worship church",
  mall: "mall shopping_centre",
  market: "marketplace market",
  "bus terminal": "bus_station",
  hotel: "hotel",
  park: "park",
  pharmacy: "pharmacy",
  "government office": "townhall government",
  "tourist spot": "attraction tourism",
  university: "university college",
  "gas station": "fuel",
  "barangay hall": "community_centre townhall",
};

function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function walkingTimeLabel(meters) {
  // ~4.5 km/h walking pace
  const minutes = Math.max(1, Math.round(meters / 75));
  if (minutes >= 60) {
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return m === 0 ? `${h}h walk` : `${h}h ${m}m walk`;
  }
  return `${minutes} mins`;
}

function distanceLabel(meters) {
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
  return `${Math.round(meters)} m`;
}

function normalizeCategory(raw, query) {
  const q = (query || "").toLowerCase();
  for (const key of Object.keys(CATEGORY_QUERIES)) {
    if (q.includes(key) || (raw && String(raw).toLowerCase().includes(key))) {
      return key
        .split(" ")
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
        .join(" ");
    }
  }
  if (raw && String(raw).trim()) {
    const s = String(raw).replace(/_/g, " ");
    return s.charAt(0).toUpperCase() + s.slice(1);
  }
  return "Place";
}

function inferAccessible(text) {
  const t = (text || "").toLowerCase();
  return (
    t.includes("wheelchair") ||
    t.includes("accessible") ||
    t.includes("ramp") ||
    t.includes("tactile") ||
    t.includes("pwd") ||
    t.includes("audio assistance")
  );
}

function resolveSearchQuery(query) {
  const q = query.trim().toLowerCase();
  for (const [key, mapped] of Object.entries(CATEGORY_QUERIES)) {
    if (q === key || q.includes(key)) return mapped;
  }
  return query.trim();
}

async function searchNominatim(query, lat, lon, radiusMeters, limit = 12) {
  const delta = Math.min(0.2, Math.max(0.02, radiusMeters / 111000));
  const left = lon - delta;
  const right = lon + delta;
  const top = lat + delta;
  const bottom = lat - delta;
  const q = resolveSearchQuery(query);

  const uri = new URL(`${NOMINATIM_BASE}/search`);
  uri.searchParams.set("q", q);
  uri.searchParams.set("format", "json");
  uri.searchParams.set("addressdetails", "1");
  uri.searchParams.set("limit", String(limit));
  uri.searchParams.set("lat", String(lat));
  uri.searchParams.set("lon", String(lon));
  uri.searchParams.set("viewbox", `${left},${top},${right},${bottom}`);
  uri.searchParams.set("bounded", "0");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);

  try {
    const res = await fetch(uri, {
      headers: {
        Accept: "application/json",
        "User-Agent": USER_AGENT,
      },
      signal: controller.signal,
    });
    if (!res.ok) return [];
    const data = await res.json();
    if (!Array.isArray(data)) return [];

    return data
      .map((item) => {
        const latitude = parseFloat(item.lat);
        const longitude = parseFloat(item.lon);
        if (Number.isNaN(latitude) || Number.isNaN(longitude)) return null;

        const address = item.display_name || "";
        const amenity =
          item.address?.amenity ||
          item.address?.shop ||
          item.address?.tourism ||
          item.type ||
          item.class;
        const name =
          (item.name && String(item.name).trim()) ||
          address.split(",")[0]?.trim() ||
          query;
        const distance = Math.round(haversineMeters(lat, lon, latitude, longitude));
        const importance = typeof item.importance === "number" ? item.importance : 0;
        const accessible = inferAccessible(`${name} ${address} ${item.extratags || ""}`);

        return {
          id: `osm_${item.place_id || `${latitude}_${longitude}`}`,
          name,
          category: normalizeCategory(amenity, query),
          address,
          latitude,
          longitude,
          distance,
          walkingTime: walkingTimeLabel(distance),
          distanceLabel: distanceLabel(distance),
          source: "OpenStreetMap",
          isAccessible: accessible,
          importance,
        };
      })
      .filter(Boolean)
      .filter((p) => p.distance <= radiusMeters * 1.35);
  } catch (err) {
    console.warn("Nominatim search failed:", err.message);
    return [];
  } finally {
    clearTimeout(timer);
  }
}

async function searchPostgres(query, lat, lon, radiusMeters, limit = 20) {
  const q = `%${query.trim().toLowerCase()}%`;
  try {
    const result = await pool.query(
      `
      SELECT
        place_id::text AS id,
        place_name AS name,
        category,
        COALESCE(address, '') AS address,
        latitude,
        longitude,
        is_accessible,
        COALESCE(description, '') AS description,
        (
          6371000 * acos(
            LEAST(1.0, GREATEST(-1.0,
              cos(radians($2)) * cos(radians(latitude)) *
              cos(radians(longitude) - radians($3)) +
              sin(radians($2)) * sin(radians(latitude))
            ))
          )
        ) AS distance_m
      FROM places
      WHERE
        LOWER(place_name) LIKE $1
        OR LOWER(category) LIKE $1
        OR LOWER(COALESCE(address, '')) LIKE $1
        OR LOWER(COALESCE(description, '')) LIKE $1
      ORDER BY distance_m ASC
      LIMIT $4
      `,
      [q, lat, lon, limit]
    );

    return result.rows
      .map((row) => {
        const distance = Math.round(Number(row.distance_m) || 0);
        if (distance > radiusMeters * 1.5) return null;
        return {
          id: `akay_${row.id}`,
          name: row.name,
          category: normalizeCategory(row.category, query),
          address: row.address,
          latitude: Number(row.latitude),
          longitude: Number(row.longitude),
          distance,
          walkingTime: walkingTimeLabel(distance),
          distanceLabel: distanceLabel(distance),
          source: "AKAY",
          isAccessible: Boolean(row.is_accessible),
          importance: row.is_accessible ? 0.35 : 0.2,
          description: row.description,
        };
      })
      .filter(Boolean);
  } catch (err) {
    console.warn("PostgreSQL place search failed:", err.message);
    return [];
  }
}

function dedupeKey(place) {
  return `${place.name.toLowerCase().trim()}_${place.latitude.toFixed(4)}_${place.longitude.toFixed(4)}`;
}

function rankScore(place, query) {
  const q = query.trim().toLowerCase();
  const name = place.name.toLowerCase();
  let score = place.distance;

  // Exact / prefix name match → pull forward
  if (name === q) score -= 800;
  else if (name.startsWith(q)) score -= 400;
  else if (name.includes(q)) score -= 200;

  // Category match
  if ((place.category || "").toLowerCase().includes(q)) score -= 150;

  // Accessibility priority
  if (place.isAccessible) score -= 350;

  // Prefer AKAY curated destinations when close
  if (place.source === "AKAY") score -= 120;

  // OSM popularity (importance 0–1)
  score -= (place.importance || 0) * 200;

  return score;
}

function mergeAndRank(osm, akay, query) {
  const seen = new Set();
  const merged = [];

  // Prefer AKAY first when inserting so duplicates keep curated entry
  for (const place of [...akay, ...osm]) {
    const key = dedupeKey(place);
    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(place);
  }

  merged.sort((a, b) => rankScore(a, query) - rankScore(b, query));
  return merged;
}

/**
 * Full destination search pipeline.
 */
async function searchDestinations({
  query,
  latitude,
  longitude,
  radius = 5000,
  wider = false,
}) {
  const lat = Number(latitude);
  const lon = Number(longitude);
  const radiusMeters = wider ? Number(radius) * 3 : Number(radius) || 5000;

  if (!query || Number.isNaN(lat) || Number.isNaN(lon)) {
    const err = new Error("query, latitude, and longitude are required");
    err.status = 400;
    throw err;
  }

  const [osm, akay] = await Promise.all([
    searchNominatim(query, lat, lon, radiusMeters),
    searchPostgres(query, lat, lon, radiusMeters),
  ]);

  let results = mergeAndRank(osm, akay, query);

  // If OSM empty, PostgreSQL already included; if both empty and not wider, caller can retry.
  if (results.length === 0 && !wider) {
    const widerOsm = await searchNominatim(query, lat, lon, radiusMeters * 3, 16);
    const widerAkay = await searchPostgres(query, lat, lon, radiusMeters * 3, 24);
    results = mergeAndRank(widerOsm, widerAkay, query);
  }

  return results.slice(0, 20).map((p) => ({
    id: p.id,
    name: p.name,
    category: p.category,
    address: p.address,
    latitude: p.latitude,
    longitude: p.longitude,
    distance: p.distance,
    walkingTime: p.walkingTime,
    source: p.source,
    isAccessible: Boolean(p.isAccessible),
    distanceLabel: p.distanceLabel || distanceLabel(p.distance),
  }));
}

module.exports = {
  searchDestinations,
  CATEGORY_QUERIES,
  walkingTimeLabel,
  distanceLabel,
};
