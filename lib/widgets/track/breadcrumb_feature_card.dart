import 'package:flutter/material.dart';
import '../../pages/shared/breadcrumb_history_page.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import '../shared/gabay_page_route.dart';

void openBreadcrumbHistory(BuildContext context, {required bool caregiver}) {
  context.pushGabayPage(BreadcrumbHistoryPage(caregiver: caregiver));
}

/// Additive entry point that fits the existing report cards and map overlays.
class BreadcrumbFeatureCard extends StatelessWidget {
  const BreadcrumbFeatureCard({
    super.key,
    required this.caregiver,
    this.compact = false,
  });
  final bool caregiver;
  final bool compact;

  @override
  Widget build(BuildContext context) => GabayCard(
    padding: EdgeInsets.all(compact ? 12 : 16),
    semanticLabel: 'Open breadcrumb tracks and sharing',
    onTap: () => openBreadcrumbHistory(context, caregiver: caregiver),
    child: Row(
      children: [
        Icon(Icons.route_rounded, color: context.gabay.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Breadcrumb tracks',
                style: GabayTheme.bodyLarge(
                  context,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              Text(
                compact
                    ? 'Track history & patient sharing'
                    : caregiver
                    ? 'Monitor your patient’s route and view saved tracks.'
                    : 'Your daily path records automatically. View tracks, pause recording, and manage caregiver sharing.',
                style: GabayTheme.bodyMedium(context).copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: context.gabay.textSecondary),
      ],
    ),
  );
}
