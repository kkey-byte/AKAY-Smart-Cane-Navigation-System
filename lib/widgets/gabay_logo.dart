import 'package:flutter/material.dart';

import 'akay_logo_data.dart';

/// Shared brand mark, using the supplied artwork without tinting.
class GabayLogo extends StatelessWidget {
  const GabayLogo({
    super.key,
    this.size = 100,
    this.color = const Color(0xFF008DE0),
  });

  final double size;
  // Retained for existing callers. The artwork keeps its original colors.
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'AKAY logo',
    child: Image.memory(
      akayLogoBytes,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}
