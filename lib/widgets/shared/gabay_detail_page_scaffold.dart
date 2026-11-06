import '../../theme/gabay_typography.dart';
import 'gabay_page_background.dart';
import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import 'gabay_page_header.dart';

class GabayDetailPageScaffold extends StatelessWidget {
  const GabayDetailPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.blueHeader = false,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final bool blueHeader;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: GabayPageBackground(
      child: GabayScrollingPage(
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GabayPageHeader(title: title),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(subtitle!, style: GabayTheme.bodyMedium(context)),
              ),
          ],
        ),
        body: body,
      ),
    ),
  );
}

class GabayContentCard extends StatelessWidget {
  const GabayContentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: GabayTheme.cardDecoration(context),
      child: child,
    );
  }
}

class GabaySectionLabel extends StatelessWidget {
  const GabaySectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(label, style: GabayTheme.sectionTitle(context)),
    );
  }
}

class GabayLegalSection extends StatelessWidget {
  const GabayLegalSection({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: GabayTypography.cardBody,
              fontWeight: GabayTypography.medium,
              color: g.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: GabayTypography.body,
              color: g.textSecondary,
              height: 1.55,
              fontWeight: GabayTypography.regular,
            ),
          ),
        ],
      ),
    );
  }
}
