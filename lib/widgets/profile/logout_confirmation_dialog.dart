import '../../theme/gabay_typography.dart';
import '../shared/gabay_accent_icon.dart';
import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

Future<void> showLogoutConfirmationDialog(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  var confirmed = false;
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => LogoutConfirmationDialog(
      onConfirm: () {
        if (confirmed) return;
        confirmed = true;
        Navigator.pop(dialogContext);
        onConfirm();
      },
    ),
  );
}

class LogoutConfirmationDialog extends StatelessWidget {
  const LogoutConfirmationDialog({super.key, required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Semantics(
        namesRoute: true,
        label: 'Logout confirmation',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: GabayTheme.cardDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GabayAccentIcon(Icons.logout_rounded, size: 44, color: g.danger),
              const SizedBox(height: 16),
              Text(
                'Logout Account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: GabayTypography.subheading,
                  fontWeight: GabayTypography.medium,
                  color: g.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _DialogPillButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                      gradient: LinearGradient(colors: [g.surface, g.surface]),
                      textColor: g.heading,
                      semanticLabel: 'Cancel logout',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogPillButton(
                      label: 'Logout',
                      onTap: onConfirm,
                      gradient: GabayTheme.actionGradient,
                      textColor: Colors.white,
                      semanticLabel: 'Confirm logout',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogPillButton extends StatelessWidget {
  const _DialogPillButton({
    required this.label,
    required this.onTap,
    required this.gradient,
    required this.textColor,
    required this.semanticLabel,
  });

  final String label;
  final VoidCallback onTap;
  final Gradient gradient;
  final Color textColor;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
              boxShadow: [
                BoxShadow(
                  color: context.gabay.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: GabayTypography.cardTitle,
                  fontWeight: GabayTypography.medium,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
