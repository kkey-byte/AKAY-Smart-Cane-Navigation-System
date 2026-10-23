import 'package:flutter/material.dart';

import '../../widgets/dashboard_widgets/caregiver_reports_body.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const SafeArea(child: CaregiverReportsBody()),
    );
  }
}
