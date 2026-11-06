import 'package:flutter/material.dart';
import 'caregiver_reports_body.dart';

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
  Widget build(BuildContext context) =>
      const CaregiverReportsBody(caregiver: false);
}
