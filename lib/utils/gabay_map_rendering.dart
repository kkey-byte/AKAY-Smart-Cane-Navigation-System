import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Glowing route lines and map markers for the track map.
class GabayMapRendering {
  GabayMapRendering._();

  static const routeAccent = Color(0xFF0A84FF);
  static const destinationColor = Color(0xFFFF3B30);

  static Future<GabayMapMarkerIcons> loadMarkerIcons() async {
    return GabayMapMarkerIcons(
      routeStart: await _createGlowDot(
        coreColor: routeAccent,
        glowColor: routeAccent,
      ),
      routeProgress: await _createNavigationArrow(
        coreColor: routeAccent,
        glowColor: routeAccent,
      ),
      destination: await _createGlowDot(
        coreColor: destinationColor,
        glowColor: destinationColor,
        hollowCenter: true,
      ),
      navigator: await _createGlowDot(
        coreColor: const Color(0xFF34C759),
        glowColor: const Color(0xFF34C759),
        size: 42,
      ),
      caregiver: await _createGlowDot(
        coreColor: const Color(0xFF8E8E93),
        glowColor: const Color(0xFF8E8E93),
        size: 40,
      ),
    );
  }

  static Set<Polyline> glowingRoute({
    required List<LatLng> points,
    Color color = routeAccent,
  }) {
    if (points.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route_glow_outer'),
        points: points,
        color: color.withValues(alpha: 0.18),
        width: 20,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ),
      Polyline(
        polylineId: const PolylineId('route_glow_mid'),
        points: points,
        color: color.withValues(alpha: 0.42),
        width: 12,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 2,
      ),
      Polyline(
        polylineId: const PolylineId('route_core'),
        points: points,
        color: color,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 3,
      ),
    };
  }

  static Future<BitmapDescriptor> _createGlowDot({
    required Color coreColor,
    required Color glowColor,
    double size = 48,
    bool hollowCenter = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final outerGlow = Paint()
      ..color = glowColor.withValues(alpha: 0.22)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    canvas.drawCircle(center, size * 0.34, outerGlow);

    final innerGlow = Paint()
      ..color = glowColor.withValues(alpha: 0.38)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    canvas.drawCircle(center, size * 0.24, innerGlow);

    canvas.drawCircle(
      center,
      size * 0.16,
      Paint()..color = coreColor,
    );

    if (hollowCenter) {
      canvas.drawCircle(
        center,
        size * 0.07,
        Paint()..color = Colors.white,
      );
    }

    return _bitmapFromCanvas(recorder, size);
  }

  static Future<BitmapDescriptor> _createNavigationArrow({
    required Color coreColor,
    required Color glowColor,
    double size = 52,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final outerGlow = Paint()
      ..color = glowColor.withValues(alpha: 0.24)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    canvas.drawCircle(center, size * 0.34, outerGlow);

    canvas.drawCircle(
      center,
      size * 0.18,
      Paint()..color = coreColor,
    );

    final arrow = Path()
      ..moveTo(center.dx, center.dy - size * 0.09)
      ..lineTo(center.dx + size * 0.08, center.dy + size * 0.05)
      ..lineTo(center.dx - size * 0.08, center.dy + size * 0.05)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);

    return _bitmapFromCanvas(recorder, size);
  }

  static Future<BitmapDescriptor> _bitmapFromCanvas(
    ui.PictureRecorder recorder,
    double size,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.ceil(), size.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }
}

class GabayMapMarkerIcons {
  const GabayMapMarkerIcons({
    required this.routeStart,
    required this.routeProgress,
    required this.destination,
    required this.navigator,
    required this.caregiver,
  });

  final BitmapDescriptor routeStart;
  final BitmapDescriptor routeProgress;
  final BitmapDescriptor destination;
  final BitmapDescriptor navigator;
  final BitmapDescriptor caregiver;
}
