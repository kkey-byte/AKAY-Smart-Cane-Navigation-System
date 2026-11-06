import '../../theme/gabay_typography.dart';
import '../../theme/gabay_visual_tokens.dart';
import '../shared/gabay_accent_icon.dart';
import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';
import '../gabay_logo.dart';

/// Shared visual shell only: account state and submissions stay in each page.
class GabayAuthScaffold extends StatelessWidget {
  const GabayAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });
  final String title, subtitle;
  final Widget child;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: g.scaffoldBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? [g.scaffoldBackground, g.surface, g.scaffoldBackground]
                      : GabayVisualTokens.pageGradient.colors,
                ),
              ),
            ),
          ),
          Positioned(
            top: -125,
            left: -125,
            child: _AuthOrb(size: 280, color: g.accent),
          ),
          Positioned(
            bottom: -140,
            right: -125,
            child: _AuthOrb(size: 300, color: g.accent),
          ),
          Positioned(
            top: 250,
            right: -100,
            child: _AuthOrb(size: 160, color: g.accent),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: onBack == null
                              ? const SizedBox(height: 36)
                              : IconButton(
                                  tooltip: 'Back',
                                  onPressed: onBack,
                                  icon: const GabayAccentIcon(
                                    Icons.arrow_back_rounded,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Semantics(
                            label: 'AKAY logo',
                            image: true,
                            child: SizedBox(
                              width: 148,
                              height: 148,
                              child: const Center(child: GabayLogo(size: 142)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: GabayTheme.bodyMedium(context),
                        ),
                        const SizedBox(height: 28),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthOrb extends StatelessWidget {
  const _AuthOrb({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.gabay.surface, color.withValues(alpha: .23)],
        ),
        border: Border.all(
          color: context.gabay.surface.withValues(alpha: .7),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .12),
            blurRadius: 26,
            offset: const Offset(10, 16),
          ),
        ],
      ),
    ),
  );
}

class GabayAuthField extends StatelessWidget {
  const GabayAuthField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    required this.validator,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool enabled, obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: _authRaisedDecoration(context, radius: 22),
    child: TextFormField(
      controller: controller,
      validator: validator,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        color: context.gabay.textPrimary,
        fontSize: GabayTypography.body,
      ),
      decoration: InputDecoration(
        labelText: label,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: context.gabay.surface.withValues(alpha: .8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: context.gabay.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: context.gabay.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: context.gabay.danger, width: 1.5),
        ),
        prefixIcon: Icon(icon, size: 21, color: context.gabay.accent),
        suffixIcon: suffixIcon,
      ),
    ),
  );
}

BoxDecoration _authRaisedDecoration(
  BuildContext context, {
  double radius = 22,
}) {
  final g = context.gabay;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [g.surfaceElevated, g.surface]
          : const [Color(0xFFF0F5FF), Color(0xFFDEE8FA)],
    ),
    border: Border.all(
      color: dark ? g.border : Colors.white.withValues(alpha: .9),
      width: 1.3,
    ),
    boxShadow: [
      GabayVisualTokens.shadowFor(dark),
      BoxShadow(
        color: dark
            ? Colors.white.withValues(alpha: .04)
            : Colors.white.withValues(alpha: .92),
        blurRadius: 18,
        offset: const Offset(-7, -7),
      ),
    ],
  );
}

class GabayAuthSurface extends StatelessWidget {
  const GabayAuthSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      DecoratedBox(decoration: _authRaisedDecoration(context), child: child);
}

/// Authentication-only raised action surface, retaining native press feedback.
class GabayAuthPrimaryButton extends StatelessWidget {
  const GabayAuthPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onPressed,
    style:
        ElevatedButton.styleFrom(
          minimumSize: const Size(48, 54),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ).copyWith(
          backgroundBuilder: (context, states, child) {
            final disabled = states.contains(WidgetState.disabled);
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: disabled ? Theme.of(context).disabledColor : null,
                gradient: disabled
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF298CEC),
                          Color(0xFF2563EB),
                          Color(0xFF223FC4),
                        ],
                      ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: disabled ? .15 : .6),
                ),
                boxShadow: disabled
                    ? null
                    : [
                        GabayVisualTokens.actionShadow(context.gabay.accent),
                        BoxShadow(
                          color: context.gabay.surface.withValues(alpha: .9),
                          blurRadius: 10,
                          offset: const Offset(-3, -3),
                        ),
                      ],
              ),
              child: child,
            );
          },
        ),
    child: child,
  );
}
