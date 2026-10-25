/**
 * AKAY destination search: Nominatim (OSM) + PostgreSQL places,
 * merged, de-duplicated, distance-ranked, accessibility-aware.
 */

const pool = require("../database/db");

const NOMINATIM_BASE = process.env.NOMINATIM_BASE_URL || '';
const PHOTON_BASE = process.env.PHOTON_BASE_URL || 'https://photon.komoot.io';
const cache = new Map();
let inFlight = null;
let lastRequestAt = 0;
const USER_AGENT = "AKAY-GABAY/1.0 (accessibility-navigation-app)";

// Category-only queries use provider tags, not a literal name like "nearby malls".
const CATEGORY_SEARCHES = {
  hospital: {tags:['amenity:hospital'],aliases:['hospital','hospitals']},
  clinic: {tags:['amenity:clinic'],aliases:['clinic','clinics']},
  restaurant: {tags:['amenity:restaurant'],aliases:['restaurant','restaurants']},
  cafe: {tags:['amenity:cafe'],aliases:['cafe','cafes','coffee shop','coffee shops']},
  supermarket: {tags:['shop:supermarket','shop:convenience'],aliases:['supermarket','supermarkets','grocery','groceries','grocery store','grocery stores']},
  bakery: {tags:['shop:bakery'],aliases:['bakery','bakeries']},
  library: {tags:['amenity:library'],aliases:['library','libraries']},
  school: {tags:['amenity:school'],aliases:['school','schools']},
  atm: {tags:['amenity:atm'],aliases:['atm','atms']},
  bank: {tags:['amenity:bank'],aliases:['bank','banks']},
  police: {tags:['amenity:police'],aliases:['police','police station','police stations']},
  'fire station': {tags:['amenity:fire_station'],aliases:['fire station','fire stations']},
  church: {tags:['amenity:place_of_worship'],aliases:['church','churches','place of worship','places of worship']},
  mall: {tags:['shop:mall'],aliases:['mall','malls','shopping mall','shopping malls','shopping center','shopping centers','shopping centre','shopping centres','shopping_centre','shopping_center']},
  market: {tags:['amenity:marketplace'],aliases:['market','markets','marketplace','marketplaces']},
  'bus terminal': {tags:['amenity:bus_station'],aliases:['bus terminal','bus terminals','bus station','bus stations']},
  hotel: {tags:['tourism:hotel'],aliases:['hotel','hotels']},
  park: {tags:['leisure:park'],aliases:['park','parks']},
  pharmacy: {tags:['amenity:pharmacy'],aliases:['pharmacy','pharmacies','drugstore','drugstores']},
  'government office': {tags:['office:government'],aliases:['government office','government offices','government']},
  'tourist spot': {tags:['tourism:attraction'],aliases:['tourist spot','tourist spots','tourist attraction','tourist attractions','attraction','attractions']},
  university: {tags:['amenity:university'],aliases:['university','universities','college','colleges']},
  'gas station': {tags:['amenity:fuel'],aliases:['gas station','gas stations','petrol station','petrol stations','fuel']},
  'barangay hall': {tags:['amenity:townhall'],aliases:['barangay hall','barangay halls','town hall','town halls','townhall']},
};
const CATEGORY_QUERIES = Object.fromEntries(Object.keys(CATEGORY_SEARCHES).map(key=>[key,key]));

function resolveSearchIntent(query) {
  // Strip request wording only at the edges; never replace a category word
  // inside a named destination (for example, "SM Mall of Asia").
  const text = query.trim().replace(/\s+/g,' ')
    .replace(/^(?:please\s+)?(?:find|show(?:\s+me)?|search(?:\s+for)?)\s+/i,'')
    .replace(/^(?:nearby|nearest)\s+/i,'')
    .replace(/\s+(?:near\s+me|around\s+me|nearby)$/i,'').trim();
  const categoryText = text.toLowerCase().replace(/^the\s+/,'');
  for (const [key,category] of Object.entries(CATEGORY_SEARCHES)) {
    if (category.aliases.includes(categoryText)) return {text:key,category,key};
  }
  return {text:text || query.trim(),category:null,key:null};
}

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
  const key = resolveSearchIntent(String(raw || '').replace(/_/g,' ')).key || resolveSearchIntent(query || '').key;
  if (key) return key.split(' ').map(word=>word.charAt(0).toUpperCase()+word.slice(1)).join(' ');
  if (raw && String(raw).trim()) {
    const s = String(raw).replace(/_/g, " ");
    return s.charAt(0).toUpperCase() + s.slice(1);
  }
  return "Place";
}

async function searchNominatim(query, lat, lon, radiusMeters, limit = 12) {
  if (!NOMINATIM_BASE.startsWith('https://') && !PHOTON_BASE.startsWith('https://')) throw new Error('Geocoder not configured.');
  const key = JSON.stringify([resolveSearchIntent(query).text,lat,lon,radiusMeters,limit]);
  const cached = cache.get(key);
  if (cached && Date.now()-cached.time < 60000) return cached.rows;
  // Bound the queue and total provider traffic for this single server process.
  if (inFlight) throw Object.assign(new Error('Search busy.'), {status:429});
  let finish;
  inFlight = new Promise(resolve => { finish = resolve; });
  try {
    await new Promise(resolve => setTimeout(resolve,Math.max(0,1100-(Date.now()-lastRequestAt))));
    lastRequestAt = Date.now();
    const rows = await requestNominatim(query,lat,lon,radiusMeters,limit);
    if (cache.size >= 100) cache.delete(cache.keys().next().value);
    cache.set(key,{time:Date.now(),rows});
    return rows;
  } finally { finish(); inFlight=null; }
}

async function requestNominatim(query, lat, lon, radiusMeters, limit = 12) {
  const intent = resolveSearchIntent(query);
  const latitudeDelta = radiusMeters * 1.5 / 111000;
  const longitudeDelta = Math.min(180,latitudeDelta / Math.max(0.01,Math.cos(lat*Math.PI/180)));
  const left = Math.max(-180,lon-longitudeDelta), right = Math.min(180,lon+longitudeDelta);
  const top = Math.min(90,lat+latitudeDelta), bottom = Math.max(-90,lat-latitudeDelta);
  const photon = !NOMINATIM_BASE;
  const path = photon ? (intent.category ? 'reverse' : 'api/') : 'search';
  const uri = new URL(`${(photon ? PHOTON_BASE : NOMINATIM_BASE).replace(/\/+$/, '')}/${path}`);
  uri.searchParams.set('limit',String(limit));
  if (photon) {
    uri.searchParams.set('lat',String(lat));
    uri.searchParams.set('lon',String(lon));
    if (intent.category) {
      uri.searchParams.set('radius',String(radiusMeters*1.35/1000));
      for (const tag of intent.category.tags) uri.searchParams.append('osm_tag',tag);
    } else {
      uri.searchParams.set('q',intent.text);
      uri.searchParams.set('bbox',`${left},${bottom},${right},${top}`);
      uri.searchParams.set('location_bias_scale','0');
    }
  } else {
    uri.searchParams.set('q',intent.text);
    uri.searchParams.set('format','json');
    uri.searchParams.set('addressdetails','1');
    uri.searchParams.set('extratags','1');
    uri.searchParams.set('viewbox',`${left},${top},${right},${bottom}`);
    uri.searchParams.set('bounded','1');
  }

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
    if (!res.ok) throw new Error('Geocoder unavailable.');
    let data = await res.json();
    if (photon) {
      if (!Array.isArray(data.features)) throw new Error('Invalid geocoder response.');
      data = data.features.filter(f => f.geometry?.type === 'Point' && Array.isArray(f.geometry.coordinates)).map(f => {
        const p = f.properties || {};
        return {lat:f.geometry.coordinates[1],lon:f.geometry.coordinates[0],
          place_id:`${p.osm_type}_${p.osm_id}`,name:p.name,
          display_name:[p.name,p.street,p.city,p.state,p.country].filter(Boolean).join(', '),type:p.osm_value};
      });
    }
    if (!Array.isArray(data)) throw new Error('Invalid geocoder response.');

    return data
      .map((item) => {
        const latitude = parseFloat(item.lat);
        const longitude = parseFloat(item.lon);
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude)>90 || Math.abs(longitude)>180) return null;

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
        const accessible = item.extratags?.wheelchair === 'yes';

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
    throw new Error('Geocoder unavailable.');
  } finally {
    clearTimeout(timer);
  }
}

async function searchPostgres(query, lat, lon, radiusMeters, limit = 20) {
  const intent = resolveSearchIntent(query);
  const terms = intent.category ? intent.category.aliases : [intent.text.toLowerCase()];
  const q = terms.map(term=>`%${term.replace(/[\\%_]/g, '\\$&')}%`);
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
        LOWER(place_name) LIKE ANY($1::text[])
        OR LOWER(category) LIKE ANY($1::text[])
        OR LOWER(COALESCE(address, '')) LIKE ANY($1::text[])
        OR LOWER(COALESCE(description, '')) LIKE ANY($1::text[])
      ORDER BY distance_m ASC
      LIMIT $4
      `,
      [q, lat, lon, limit]
    );

    return result.rows
      .map((row) => {
        // PostgreSQL numeric columns may arrive as strings; missing values are not zero.
        const latitude = row.latitude == null || String(row.latitude).trim() === '' ? NaN : Number(row.latitude);
        const longitude = row.longitude == null || String(row.longitude).trim() === '' ? NaN : Number(row.longitude);
        const distance = row.distance_m == null ? NaN : Math.round(Number(row.distance_m));
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
            Math.abs(latitude)>90 || Math.abs(longitude)>180 ||
            !Number.isFinite(distance) || distance < 0 || distance > radiusMeters * 1.5) return null;
        return {
          id: `akay_${row.id}`,
          name: row.name,
          category: normalizeCategory(row.category, query),
          address: row.address,
          latitude,
          longitude,
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
    throw new Error('Place database unavailable.');
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

  if (typeof query !== 'string' || !query.trim() || query.length > 200 ||
      typeof latitude !== 'string' && typeof latitude !== 'number' ||
      typeof longitude !== 'string' && typeof longitude !== 'number' ||
      !Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat)>90 || Math.abs(lon)>180 ||
      !Number.isFinite(radiusMeters) || radiusMeters < 1 || radiusMeters > 50000) {
    const err = new Error("query, latitude, and longitude are required");
    err.status = 400;
    throw err;
  }

  const sources = await Promise.allSettled([
    searchNominatim(query, lat, lon, radiusMeters),
    searchPostgres(query, lat, lon, radiusMeters),
  ]);
  const [osm, akay] = sources.map(result => result.status === 'fulfilled' ? result.value : []);
  if (sources.some(result => result.status === 'rejected') && !osm.length && !akay.length) {
    throw Object.assign(new Error('Search unavailable.'),{status:503});
  }
  const results = mergeAndRank(osm, akay, resolveSearchIntent(query).text);


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
  resolveSearchIntent,
  walkingTimeLabel,
  distanceLabel,
};
