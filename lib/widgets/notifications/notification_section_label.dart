import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class NotificationSectionLabel extends StatelessWidget {
  const NotificationSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        label,
        style: GabayTheme.labelSmall(context).copyWith(
          letterSpacing: 1.1,
          fontSize: 12,
        ),
      ),
    );
  }
}
