import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';

class LinkedNavigatorPhoto extends StatelessWidget {
  const LinkedNavigatorPhoto({super.key, this.picture});
  final String? picture;
  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final fallback = ColoredBox(
      color: g.accentTint,
      child: Center(child: Icon(Icons.person_outline_rounded, color: g.accent)),
    );
    Widget photo = fallback;
    try {
      if (picture?.startsWith('data:image/') == true) {
        photo = Image.memory(
          base64Decode(picture!.split(',').last),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      } else if (Uri.tryParse(picture ?? '')?.scheme == 'https') {
        photo = Image.network(
          picture!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    } catch (_) {
      photo = fallback;
    }
    return ClipOval(child: SizedBox.square(dimension: 48, child: photo));
  }
}
