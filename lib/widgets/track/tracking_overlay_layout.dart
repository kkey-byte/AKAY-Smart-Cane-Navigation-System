import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';

/// Screen-local presentation only; changing panels does not end a trip.
enum TrackingPanel { none, directions, details }

/// Gives the header, toolbar and one panel separate, bounded phone space.
class TrackingOverlayLayout extends StatelessWidget {
  const TrackingOverlayLayout({
    super.key,
    required this.header,
    required this.panel,
    required this.onPanelChanged,
    this.directions,
    this.details,
    this.leadingControl,
    this.reservedBottomHeight = 0,
  });
  final Widget header;
  final TrackingPanel panel;
  final ValueChanged<TrackingPanel> onPanelChanged;
  final Widget? directions, details, leadingControl;
  final double reservedBottomHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final hasToolbar = directions != null || details != null;
      final active = switch (panel) {
        TrackingPanel.directions => directions,
        TrackingPanel.details => details,
        TrackingPanel.none => null,
      };
      final reserve = active != null
          ? (constraints.maxHeight * .35).clamp(0.0, 180.0)
          : reservedBottomHeight;
      final headerHeight =
          (constraints.maxHeight - (hasToolbar ? 56 : 0) - reserve).clamp(
            0.0,
            constraints.maxHeight,
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            key: const ValueKey('tracking-overlay-header'),
            constraints: BoxConstraints(maxHeight: headerHeight),
            child: SingleChildScrollView(primary: false, child: header),
          ),
          if (hasToolbar)
            Padding(
              key: const ValueKey('tracking-overlay-toolbar'),
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (leadingControl != null) ...[
                    leadingControl!,
                    const SizedBox(width: 8),
                  ],
                  if (directions != null) ...[
                    _toggle(
                      context,
                      TrackingPanel.directions,
                      Icons.alt_route_rounded,
                      'Turn-by-Turn',
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (details != null)
                    _toggle(
                      context,
                      TrackingPanel.details,
                      Icons.info_outline_rounded,
                      'navigation details',
                    ),
                ],
              ),
            ),
          if (hasToolbar) ...[
            const SizedBox(height: 8),
            Expanded(
              child: ClipRect(
                key: const ValueKey('tracking-panel-area'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (directions != null)
                      Offstage(
                        offstage: panel != TrackingPanel.directions,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SingleChildScrollView(
                            primary: false,
                            child: directions,
                          ),
                        ),
                      ),
                    if (details != null)
                      Offstage(
                        offstage: panel != TrackingPanel.details,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: details,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _toggle(
    BuildContext context,
    TrackingPanel target,
    IconData icon,
    String label,
  ) {
    final selected = panel == target;
    final g = context.gabay;
    return Semantics(
      toggled: selected,
      child: IconButton(
        tooltip: '${selected ? 'Hide' : 'Show'} $label',
        onPressed: () => onPanelChanged(selected ? TrackingPanel.none : target),
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          maximumSize: const Size(48, 48),
          padding: const EdgeInsets.all(12),
          foregroundColor: selected ? Colors.white : g.accent,
          backgroundColor: selected ? GabayColors.primaryBlue : g.surface,
          side: BorderSide(color: g.border.withValues(alpha: .65)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
