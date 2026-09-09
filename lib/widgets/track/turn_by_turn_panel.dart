import 'package:flutter/material.dart';

import '../../models/route_plan.dart';
import '../../theme/gabay_theme.dart';

class TurnStep {
  const TurnStep({
    required this.instruction,
    this.detail = '',
    this.isNext = false,
    this.maneuverType = 'turn',
    this.modifier = '',
  });

  final String instruction;
  final String detail;
  final bool isNext;
  final String maneuverType;
  final String modifier;

  factory TurnStep.fromRouteInstruction(RouteTurnInstruction step) {
    return TurnStep(
      instruction: step.instruction,
      detail: step.detail,
      isNext: step.isNext,
      maneuverType: step.maneuverType,
      modifier: step.modifier,
    );
  }
}

class TurnByTurnPanel extends StatelessWidget {
  const TurnByTurnPanel({
    super.key,
    required this.steps,
    this.onClose,
  });

  final List<TurnStep> steps;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: g.surface,
      elevation: 4,
      shadowColor: g.shadow,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Turn-by-Turn',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: g.textPrimary,
                  ),
                ),
                const Spacer(),
                if (onClose != null)
                  Material(
                    color: g.chipBackground,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: onClose,
                      icon: Icon(Icons.close_rounded, color: g.textSecondary),
                      tooltip: 'Hide directions',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (steps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Directions will appear once a route is active.',
                  style: GabayTheme.bodyMedium(context),
                ),
              )
            else
              TurnByTurnList(steps: steps),
          ],
        ),
      ),
    );
  }
}

class TurnByTurnList extends StatelessWidget {
  const TurnByTurnList({super.key, required this.steps});

  final List<TurnStep> steps;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Divider(height: 1, color: g.border.withValues(alpha: 0.5)),
          _StepRow(step: steps[i]),
        ],
      ],
    );
  }
}

class OpenTurnByTurnButton extends StatelessWidget {
  const OpenTurnByTurnButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: g.surface,
      elevation: 4,
      shadowColor: g.shadow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: g.accent.withValues(alpha: 0.35)),
          ),
          child: Icon(
            Icons.alt_route_rounded,
            color: g.accent,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final TurnStep step;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: step.isNext ? g.accentTint : g.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconForManeuver(step.maneuverType, step.modifier),
              color: step.isNext ? g.accent : g.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: GabayTheme.bodyLarge(context).copyWith(
                    fontSize: 14,
                    color: step.isNext ? g.textPrimary : g.textSecondary,
                  ),
                ),
                if (step.detail.isNotEmpty)
                  Text(step.detail, style: GabayTheme.bodyMedium(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForManeuver(String type, String modifier) {
  final mod = modifier.toLowerCase();
  switch (type) {
    case 'depart':
      return Icons.play_arrow_rounded;
    case 'arrive':
      return Icons.flag_rounded;
    case 'roundabout':
    case 'rotary':
      return Icons.roundabout_right_rounded;
    case 'merge':
      return Icons.merge_rounded;
    case 'fork':
      if (mod.contains('left')) return Icons.fork_left_rounded;
      if (mod.contains('right')) return Icons.fork_right_rounded;
      return Icons.alt_route_rounded;
    case 'end of road':
    case 'turn':
      if (mod.contains('sharp left')) return Icons.turn_sharp_left_rounded;
      if (mod.contains('sharp right')) return Icons.turn_sharp_right_rounded;
      if (mod.contains('slight left')) return Icons.turn_slight_left_rounded;
      if (mod.contains('slight right')) return Icons.turn_slight_right_rounded;
      if (mod.contains('uturn') || mod.contains('u-turn')) {
        return Icons.u_turn_left_rounded;
      }
      if (mod.contains('left')) return Icons.turn_left_rounded;
      if (mod.contains('right')) return Icons.turn_right_rounded;
      return Icons.straight_rounded;
    case 'continue':
    case 'new name':
      if (mod.contains('left')) return Icons.turn_slight_left_rounded;
      if (mod.contains('right')) return Icons.turn_slight_right_rounded;
      return Icons.straight_rounded;
    default:
      if (mod.contains('left')) return Icons.turn_left_rounded;
      if (mod.contains('right')) return Icons.turn_right_rounded;
      return Icons.directions_walk_rounded;
  }
}

/// Maps routing-engine instructions into Turn-by-Turn UI rows.
List<TurnStep> turnStepsFromRoute(RoutePlanResult? route) {
  if (route == null || route.turnInstructions.isEmpty) {
    return const [];
  }
  return route.turnInstructions
      .map(TurnStep.fromRouteInstruction)
      .toList(growable: false);
}
