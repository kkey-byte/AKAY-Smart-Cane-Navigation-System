import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

/// Tab page title block shared by Track, Reports, and other main tabs.
class GabayPageHeader extends StatelessWidget {
  const GabayPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GabayTheme.greetingLarge(context)),
        const SizedBox(height: 6),
        Text(subtitle, style: GabayTheme.greetingSub(context)),
      ],
    );
  }
}
