import 'package:flutter/material.dart';

import '../../models/route_timeline_entry.dart';
import '../../theme/gabay_theme.dart';

class RouteTimelinePanel extends StatelessWidget {
  const RouteTimelinePanel({
    super.key,
    required this.entries,
  });

  final List<RouteTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Walking route points will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: g.textSecondary, height: 1.4),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Status',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: g.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(entries.length, (index) {
          final entry = entries[index];
          final isLast = index == entries.length - 1;

          return _TimelineRow(
            entry: entry,
            isFirst: index == 0,
            isLast: isLast,
            showLineBelow: !isLast,
          );
        }),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.showLineBelow,
  });

  final RouteTimelineEntry entry;
  final bool isFirst;
  final bool isLast;
  final bool showLineBelow;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final title = entry.isArrived
        ? entry.address.replaceAll(' (Arrived)', '')
        : entry.address;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.isArrived ? g.success : g.accent,
                    border: Border.all(color: g.surface, width: 2),
                  ),
                ),
                if (showLineBelow)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: g.accent.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLineBelow ? 18 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: g.textPrimary,
                        height: 1.35,
                      ),
                      children: [
                        TextSpan(text: title),
                        if (entry.isArrived)
                          TextSpan(
                            text: ' (Arrived)',
                            style: TextStyle(
                              color: g.success,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.formattedTime,
                    style: TextStyle(
                      fontSize: 13,
                      color: g.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
