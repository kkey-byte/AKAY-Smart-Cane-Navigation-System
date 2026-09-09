import 'package:flutter/material.dart';

import '../screens/track_page.dart';

/// Navigator Track tab.
///
/// Uses the shared [TrackPage] navigation UI. In navigator mode the top panel
/// is a destination search field (not raw coordinates / "Walking" text).
class VisuallyImpairedTrackPage extends StatelessWidget {
  const VisuallyImpairedTrackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TrackPage(role: TrackPageRole.navigator);
  }
}
