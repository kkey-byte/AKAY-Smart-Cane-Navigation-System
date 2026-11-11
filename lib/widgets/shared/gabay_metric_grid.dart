import 'package:flutter/material.dart';

/// Equal statistic tiles sized by viewport and text scale, never by content.
class GabayMetricGrid extends StatelessWidget {
  const GabayMetricGrid({super.key, required this.children});
  final List<Widget> children;
  static double tileHeight(BuildContext context) =>
      168 +
      (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(
            0,
            double.infinity,
          ) *
          4;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final two = constraints.maxWidth >= 240;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: two
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
              height: tileHeight(context),
              child: child,
            ),
        ],
      );
    },
  );
}
