import 'recorded_reports.dart';
import 'package:flutter/material.dart';
import '../shared/gabay_page_header.dart';
import '../shared/floating_bottom_nav_shell.dart';
import '../track/breadcrumb_feature_card.dart';

class CaregiverReportsBody extends StatelessWidget {
  const CaregiverReportsBody({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(20, 16, 20, GabayNavMetrics.contentClearance),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GabayPageHeader(
          title: 'Reports',
          subtitle: 'Recorded walking history',
        ),
        const SizedBox(height: 22),
        const BreadcrumbFeatureCard(caregiver: true),
        const SizedBox(height: 22),
        const RecordedReports(caregiver: true),
      ],
    ),
  );
}
