import 'recorded_reports.dart';
import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';
import '../shared/floating_bottom_nav_shell.dart';
import '../track/breadcrumb_feature_card.dart';

class ReportsBody extends StatelessWidget {
  const ReportsBody({
    super.key,
    this.subtitle = "Your walking history & insights",
    this.tripsToday,
    this.tripsThisWeek,
    this.totalDistance,
    this.avgWalkTime,
  });
  final String subtitle;
  final String? tripsToday, tripsThisWeek, totalDistance, avgWalkTime;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.only(bottom: GabayNavMetrics.contentClearance),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF104694), Color(0xFF0A326B)],
            ),
          ),
          child: const Text(
            'Reports',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BreadcrumbFeatureCard(caregiver: false),
              const SizedBox(height: 12),
              const RecordedReports(caregiver: false),
              const SizedBox(height: 12),
              Text(
                'Recorded walking history',
                style: TextStyle(
                  color: context.gabay.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
