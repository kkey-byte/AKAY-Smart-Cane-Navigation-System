const express = require("express");
const { searchDestinations } = require("../services/searchService");

const router = express.Router();

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
    console.error("GET /api/search:", err.message);
    res.status(status).json({
      message: err.message || "Search failed",
      results: [],
    });
  }
});

module.exports = router;
