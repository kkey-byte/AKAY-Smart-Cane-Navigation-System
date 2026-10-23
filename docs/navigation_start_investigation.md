# Navigation startup investigation - 2026-10-21

## Verified flow and failure

Search requests go from `DestinationSearchService.search` to `/api/search`, which merges the configured map geocoder with PostgreSQL `places`. Results become `SearchDestination`, then `MapPlace`. In Track, both a result row and its Navigate icon invoke `TrackPageState._selectDestinationPlace`. The separate route planner invokes `_onSuggestionSelected` (including recent destinations).

A map tap/long press invokes `TrackPageState._onMapPinDestination`, then `MapPlaceService.placeFromCoordinates`. Reverse-geocoding failure already preserves the pin coordinates and uses a coordinate label. Confirming the pin invokes the same `_selectDestinationPlace` used by search results. No provider place ID is required by `buildRoutePlan` or the route API; the coordinates are sufficient.

Routing uses a real current GPS fix and sends `longitude,latitude;longitude,latitude` to `/api/routing/walk` (or the explicitly configured HTTPS foot engine). A validated route becomes `_activeRoute`, is rendered by `GabayTrackMap`, and activates the existing navigation panels and session logic. Selecting a result or pin already starts routing; this screen uses a Navigate icon rather than a separate button captioned Start Navigation. The spinner temporarily replaces the search/retry icon while a request is pending.

**Runtime failure reproduced:** before this change, a route request through the running local backend using public-landmark coordinates returned HTTP 503, `Walking directions unavailable. Try again.` Both provider hostnames resolve; direct provider probes in the preceding investigation reported connection timeouts. There is no evidence that place IDs caused this failure. Provider connectivity remains a blocker; the current work does not replace the provider or fabricate geometry.

## Confirmed code defects fixed

| File/function | Previous condition | Change |
| --- | --- | --- |
| `lib/services/map_place_service.dart`: `fetchWalkingRoute`, `buildRoutePlan` | HTTP development API addresses other than localhost/127.0.0.1 were rejected before any request, including the configured emulator/LAN backend. HTTP errors, provider unavailability, and no-route responses were collapsed into null/generic failure. | Honor the configured development backend address; retain HTTPS requirements for release and direct engines. Display safe, specific errors for invalid configuration, connection failure, timeout, rejected coordinates, no route, busy service, and unavailable provider. Retain geometry and measurement validation. |
| `lib/models/search_destination.dart`: `fromJson` | Numeric-string coordinates threw; missing coordinates became zero. | Parse numeric/string coordinates and reject missing, non-finite or out-of-range values. |
| `lib/models/route_plan.dart`: `MapPlace.hasValidCoordinates` | `LatLng` could normalize an out-of-range stored destination before it was checked. | Validate raw MapPlace coordinates before constructing the routing destination. No place-ID requirement added. |
| `lib/services/destination_search_service.dart`: `_RecentSentDestination.fromJson` | Local recent destinations accepted non-finite/out-of-range coordinates. | Reject invalid recent coordinates. |
| `lib/pages/screens/track_page.dart`: `_selectDestinationPlace`, `_submitDestinationSearch`, `_onMapPinDestination`, query/clear handlers | Older requests could start the wrong destination after edits/selection changes; duplicate starts were possible. A successful GPS refresh still returned without routing. Camera animation failure could prevent pin routing. Substring matching could reuse a stale pin. | Invalidate superseded requests, deduplicate active identical starts, reset pending state in finally, continue after a successful GPS refresh, retain failed destination for retry, match destination text exactly, and keep camera failures independent of route startup. |
| `lib/pages/screens/route_planner_page.dart`: `_onSuggestionSelected`, `_useRecentDestination`, recent list | Similar stale/duplicate request and GPS-refresh problems. Preference-write failure could block returning a valid route. Recent tiles triggered a Flutter debug Material assertion. | Guard request generations and reset loading; continue after GPS recovery; history persistence cannot block routing; add the required transparent Material ancestor without altering layout. Optional service injection enables regression tests. |
| `backend_patch/routes/routing.js` | Numeric-coordinate regex rejected legitimate exponent notation produced by Dart, such as 1e-7. | Accept decimal/exponent numbers while continuing to reject missing, malformed, non-finite and out-of-range coordinates. Existing rate limit and finally cleanup retained. |
| `backend_patch/services/searchService.js`: `searchPostgres` | Null database coordinates/distance could be converted to zero and returned as valid. | Preserve numeric-string coordinates; reject incomplete or invalid rows. Search queries, providers, nearby-radius behavior, ranking and merge behavior are unchanged. |

The source defects above are verified from implementation and regression tests. They are additional failure conditions, not claims that every user experienced each one. The reproduced live failure was HTTP 503.

## Verification

- 24 focused Flutter tests passed: `navigation_destination_test.dart`, `navigation_start_widget_test.dart`, `api_audit_test.dart`, `device_location_test.dart`. They cover all four requested destination types at the shared routing boundary, pin reverse-geocoding fallback, correct coordinate order/geometry, numeric-string database data, invalid data, HTTP 422/429/503 and network retry, stale selection, duplicate starts, denied location, permission recovery, and failed history writes. Routing/GPS in these tests is mocked; this is not a real outdoor trip or manual map UI test.
- 32 backend regression tests passed, including routing validation/retry and database-source parsing. The broader suite initially could not connect because the isolated PostgreSQL cluster was stopped; it passed after starting that test cluster on port 55439. Its schemas/data are synthetic and separate from the application database.
- Read-only application database verification: 8 stored places; 0 missing/out-of-range coordinates. The actual search SQL returned a stored destination with its coordinates preserved. External calls were stubbed during this read-only check; no names or coordinates were printed.
- `flutter analyze`: no errors or warnings; 3 existing informational notices in onboarding, blob painter, and page-route code.
- Backend source changes applied with backups and the verified local backend restarted. Restarted `/api/routing/walk` returns HTTP 400 for invalid input.
- No application database migration or write, provider replacement, routing-preference change, or authentication/pairing/device/tracking change was performed.

## Remaining limits

Live walking routes and provider search results cannot be claimed working while outbound provider connectivity fails. Chrome/device UI and real location-permission interaction were not manually exercised. No hardware behavior or outdoor route suitability was verified. A successful web compile establishes browser compilation, not provider reachability. Hot restart the running Flutter application to load the source changes before retrying.

Final build verification: `flutter build web --debug --no-pub --no-wasm-dry-run` succeeded with the final route-loading text included. An earlier normal web build also succeeded and reported existing flutter_tts WebAssembly dry-run compatibility notices; the JavaScript/Chrome build is successful. The five navigation widget tests were rerun after the final loading-text/origin-assertion changes and passed. Final analysis still reports only the three existing informational notices.
