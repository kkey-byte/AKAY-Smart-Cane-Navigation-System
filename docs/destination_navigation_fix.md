Destination navigation fix (2026-10-21)

Verified causes: searchService.js returned no external places without NOMINATIM_BASE_URL; MapPlaceService.fetchWalkingRoute returned null without OSRM_FOOT_BASE_URL; RoutePlannerPage._useRecentDestination only filled text. TrackPage also expanded the wider radius twice.

Search now uses Photon when no private Nominatim provider is configured. PHOTON_BASE_URL overrides the community endpoint. Walking routes use /api/routing/walk by default; OSRM_FOOT_BASE_URL on the backend overrides the FOSSGIS foot engine. An explicit Flutter HTTPS OSRM_FOOT_BASE_URL remains supported. Saved/recent destination selection builds a route from its stored coordinates. Failed routing never becomes a straight-line route.

Search and route requests disclose the entered query and/or origin/destination coordinates to the selected provider. No account identifiers or tokens are sent upstream. Community services have capacity limits and no availability guarantee; configure managed/self-hosted services for deployment. FOSSGIS route requests are logged by that provider. One process allows at most one upstream route request per 1.1 seconds, with bounded request time; multi-instance deployment requires a shared rate limiter. Existing search cache expires after 60 seconds. No continuous route requests or search-as-you-type are introduced.

Provider documentation:
https://github.com/komoot/photon
https://routing.openstreetmap.de/about.html

Live public-landmark probes from this environment timed out connecting to both providers. Mocked tests establish request/response handling, not Internet availability or physical navigation. GPS permission, a live location, provider reachability and backend availability remain required. No GPS source or database migration changed.
