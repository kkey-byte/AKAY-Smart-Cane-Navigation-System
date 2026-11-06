import 'recorded_reports.dart';
import '../shared/gabay_page_header.dart';
import 'package:flutter/material.dart';

import '../shared/floating_bottom_nav_shell.dart';

class CaregiverReportsBody extends StatelessWidget {
  const CaregiverReportsBody({super.key, this.caregiver = true});
  final bool caregiver;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.only(bottom: GabayNavMetrics.contentClearance),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GabayPageHeader(title: 'Reports', showBack: false),
        Padding(
          padding: const EdgeInsets.all(20),
          child: RecordedReports(caregiver: caregiver),
        ),
      ],
    ),
  );
}
