---
name: add-api-call
description: Add or modify AKAY HTTP API integrations using Flutter services and models with response parsing and UI error handling. Use for backend requests rather than Firebase streams or GPS ownership.
---

# Add an AKAY API call

Inspect lib/config/api_config.dart and the nearest existing service. lib/services/profile_service.dart demonstrates requests, timeouts, status handling, parsing, and session-cache updates. Establish the endpoint, method, identity requirements, and response shape from backend code or documentation. Ask for missing contract information rather than inventing endpoints.

Use package:http and the configured API base URL. Keep network requests in lib/services/ and structured data parsing in lib/models/. Follow existing error conventions, handle unsuccessful status codes and malformed responses, and set a bounded timeout. Avoid automatic retries of writes unless repeat requests are safe under the API contract.

Read lib/services/app_session_service.dart before updating caches or attaching identity. Preserve backend user IDs and Firebase UIDs as distinct values. Never hard-code credentials or log tokens, patient details, or location payloads. Follow the existing authentication contract rather than inventing headers.

Show loading, success or empty results, and useful errors in the caller. Guard UI updates after disposal. For navigation endpoints, inspect lib/services/navigation_persistence_service.dart and preserve device and session identifiers.

Format changed Dart files and run flutter analyze when available. Use mocked HTTP tests for changed parsing and failure handling. Report endpoint assumptions, files changed, validation performed, and backend behavior that remains unverified.
