import '../../theme/gabay_visual_tokens.dart';
import 'package:flutter/material.dart';

/// A restrained blue/pastel treatment for non-tracking presentation icons.
/// Existing white, disabled, and semantic status colors remain authoritative.
class GabayAccentIcon extends StatelessWidget {
  const GabayAccentIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
  });
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;

  static Color accent(IconData? icon) {
    if (const [
      Icons.person,
      Icons.person_outline,
      Icons.person_rounded,
      Icons.person_outline_rounded,
      Icons.people_outline,
      Icons.group_outlined,
      Icons.location_on_outlined,
      Icons.water_drop_outlined,
      Icons.bloodtype_outlined,
      Icons.favorite_outline,
      Icons.health_and_safety_outlined,
    ].contains(icon)) {
      return GabayVisualTokens.lavender;
    }
    if (const [
      Icons.flag_outlined,
      Icons.home_outlined,
      Icons.apartment,
      Icons.local_hospital_outlined,
    ].contains(icon)) {
      return GabayVisualTokens.peach;
    }
    return GabayVisualTokens.blue;
  }

  @override
  Widget build(BuildContext context) {
    final inherited = IconTheme.of(context);
    final original = color ?? inherited.color;
    final keepColor =
        original != null &&
        ((original.r > .85 && original.g > .85 && original.b > .85) ||
            (original.r > .50 && original.r > original.g * 1.35) ||
            (original.g > .40 &&
                original.g > original.r * 1.35 &&
                original.g > original.b * 1.15) ||
            original == Theme.of(context).disabledColor);
    final control = const [
      Icons.arrow_back,
      Icons.arrow_back_rounded,
      Icons.arrow_back_ios_new_rounded,
      Icons.chevron_right_rounded,
      Icons.chevron_right,
      Icons.keyboard_arrow_down_rounded,
      Icons.keyboard_arrow_down,
      Icons.expand_more,
      Icons.expand_less,
      Icons.close,
      Icons.close_rounded,
      Icons.more_vert,
      Icons.more_horiz,
      Icons.visibility,
      Icons.visibility_off,
      Icons.visibility_outlined,
      Icons.visibility_off_outlined,
      Icons.check,
      Icons.check_rounded,
      Icons.edit,
      Icons.edit_outlined,
      Icons.edit_rounded,
    ].contains(icon);
    final tint = accent(icon);
    final extent = size ?? inherited.size ?? 24;
    if (keepColor || control || icon == null) {
      return Icon(
        icon,
        size: size,
        color: keepColor ? color : tint,
        semanticLabel: semanticLabel,
        textDirection: textDirection,
      );
    }
    return SizedBox.square(
      dimension: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(tint, Colors.white, .28)!, tint],
          ),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: .14),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: extent * .72,
            color: Colors.white,
            semanticLabel: semanticLabel,
            textDirection: textDirection,
          ),
        ),
      ),
    );
  }
}
