# AKAY Project Knowledge

## Project
AKAY: A Smart Cane Navigation System with Caregiver Monitoring Using LiDAR Sensor.

Members: Batulanon, Mariel Joyce; Cadiao, Regine Kris; Curato, Glaisa Mae.

Repository: https://github.com/kkey-byte/AKAY-Smart-Cane-Navigation-System

## Purpose and implementation scope
This repository contains the Flutter application for navigator and caregiver workflows. The capstone combines smart-cane navigation and caregiver monitoring. The project title includes LiDAR hardware; the mobile source and this documentation alone do not verify hardware integration or obstacle detection.

## Features represented in the mobile source
- Registration, login, role routing, and onboarding.
- Navigator and caregiver dashboards.
- Destination search, map display, route planning, and GPS navigation sessions.
- Caregiver live-location monitoring.
- Profile and patient information, reports, and text-to-speech support.

## Technologies
Dart and Flutter; Firebase Authentication, Firestore, and Realtime Database; HTTP API services; Google Maps and flutter_map; geolocator and geocoding; shared_preferences; flutter_tts.
See pubspec.yaml for the installed dependency constraints.

## Source map
- lib/pages/: screens grouped by caregiver, visually_impaired, onboarding, and shared workflows.
- lib/widgets/: reusable components, including tracking and dashboard widgets.
- lib/services/: authentication, profiles, GPS, navigation persistence, and API integration.
- lib/models/: data structures and API parsing.
- lib/theme/: Gabay theme and map styling.
- lib/config/: API and map configuration. Do not copy credentials into documentation.
- test/: Flutter tests.

## Development guidelines
Inspect existing code before modifying a workflow. Preserve Gabay identifiers used by the application. Reuse theme values and shared widgets; support readable text, semantic labels, and navigator accessibility. Keep API requests in services and data parsing in models. Preserve role and session behavior across authentication, navigation, and monitoring. Handle loading, errors, and disposed widgets when performing asynchronous operations. Never expose tokens, credentials, or personal location data in screenshots.

For Dart code changes, format the changed files, run flutter analyze, and run relevant tests. Document any device, backend, or hardware verification that remains unavailable.

## Seminar skills
- .agents/skills/create-component/SKILL.md: create reusable AKAY Flutter UI components.
- .agents/skills/add-api-call/SKILL.md: add HTTP API calls using AKAY services and models.
- .agents/skills/vercel-react-best-practices/SKILL.md: externally provided Vercel React guidance. Installed for the provider requirement; use only for relevant React/Next.js work, not Flutter implementation.

Existing AKAY skills remain available for accessible screens, authentication/onboarding, navigation/tracking, and profiles/health.
