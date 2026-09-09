import 'package:flutter/material.dart';

import '../../widgets/dashboard_widgets/reports_body.dart';

class VisuallyImpairedReportsPage extends StatelessWidget {
  const VisuallyImpairedReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const SafeArea(
        child: ReportsBody(
          subtitle: 'Your walking history & insights',
        ),
      ),
    );
  }
}
