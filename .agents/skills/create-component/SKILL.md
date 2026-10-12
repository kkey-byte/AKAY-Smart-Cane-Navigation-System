---
name: create-component
description: Create reusable AKAY Flutter widgets using existing Gabay themes and shared components. Use for cards, controls, headers, and panels rather than complete screens.
---

# Create an AKAY component

Inspect the calling screen and similar components under lib/widgets/ before adding a widget. Read lib/theme/gabay_theme.dart for existing styles and colors. Preserve Gabay identifiers already used by the app.

Place the widget in the relevant lib/widgets/ subfolder with a snake_case Dart filename. Expose content and actions through constructor parameters and callbacks. Keep HTTP operations and session ownership in services or the parent screen rather than triggering requests in build().

Support readable text scaling, semantic labels for icon-only controls, and status information beyond color. Use theme values for light and dark modes. Inspect lib/services/gabay_tts_service.dart when speech is involved and avoid repeated speech from widget builds.

Guard asynchronous UI updates after disposal and clean up owned listeners. Preserve navigator and caregiver routing when integrating the component.

Format changed Dart files and run flutter analyze when available. For behavior changes, run focused widget tests of the affected interaction. Report the widget path, where it is used, and checks performed.
