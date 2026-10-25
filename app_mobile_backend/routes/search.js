const express = require("express");
const { searchDestinations } = require("../services/searchService");

const router = express.Router();
const requests = new Map();
router.use((req,res,next)=> {
  const now=Date.now(),key=req.ip;
  let entry=requests.get(key);
  if (!entry || now-entry.start >= 60000) {
    if (requests.size >= 1000) requests.delete(requests.keys().next().value);
    requests.set(key,entry={start:now,count:0});
  }
  if (++entry.count > 30) return res.status(429).json({message:'Search limit reached. Try again shortly.'});
  res.set('Cache-Control','no-store');
  return next();
});

/**
 * GET /api/search?query=hospital&latitude=7.308&longitude=125.684&radius=5000
 * Optional: wider=1 to expand search radius.
 */
router.get("/", async (req, res) => {
  try {
    const { query, latitude, longitude, radius, wider } = req.query;

    const results = await searchDestinations({
      query,
      latitude,
      longitude,
      radius: radius ? Number(radius) : 5000,
      wider: wider === "1" || wider === "true",
    });

    res.json(results);
  } catch (err) {
    const status = err.status || 500;
    res.status(status).json({
      message: status === 400 ? "Valid query, coordinates, and radius are required." : "Search unavailable.",
      results: [],
    });
  }
});

module.exports = router;
