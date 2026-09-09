import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

Future<void> showLogoutConfirmationDialog(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => LogoutConfirmationDialog(
      onConfirm: () {
        Navigator.pop(dialogContext);
        onConfirm();
      },
    ),
  );
}

class LogoutConfirmationDialog extends StatelessWidget {
  const LogoutConfirmationDialog({
    super.key,
    required this.onConfirm,
  });

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Semantics(
        namesRoute: true,
        label: 'Logout confirmation',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? g.surfaceElevated : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: g.border.withValues(alpha: isDark ? 0.55 : 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: g.shadow,
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 44,
                color: g.danger,
              ),
              const SizedBox(height: 16),
              Text(
                'Logout Account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
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
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                g.chipBackground,
                                g.surface,
                              ]
                            : [
                                const Color(0xFFE5E7EB),
                                const Color(0xFFF3F4F6),
                              ],
                      ),
                      textColor: g.textPrimary,
                      semanticLabel: 'Cancel logout',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogPillButton(
                      label: 'Logout',
                      onTap: onConfirm,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          g.accent.withValues(alpha: 0.92),
                          isDark ? const Color(0xFF2563EB) : const Color(0xFF0A84FF),
                        ],
                      ),
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
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(999),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
