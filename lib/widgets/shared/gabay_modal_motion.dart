import 'package:flutter/material.dart';

/// Shared modal timing respects the device's reduced-motion preference.
AnimationStyle gabayModalAnimation(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? AnimationStyle.noAnimation
    : const AnimationStyle(
        duration: Duration(milliseconds: 260),
        reverseDuration: Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
