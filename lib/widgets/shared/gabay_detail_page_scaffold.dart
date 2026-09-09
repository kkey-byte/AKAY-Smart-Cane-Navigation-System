import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class GabayDetailPageScaffold extends StatelessWidget {
  const GabayDetailPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: g.heading,
                        size: 20,
                      ),
                    ),
                  ),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: g.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: g.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.gabay.textSecondary,
        ),
      ),
    );
  }
}

class GabayLegalSection extends StatelessWidget {
  const GabayLegalSection({
    super.key,
    required this.title,
    required this.body,
  });

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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: g.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: g.textSecondary,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
