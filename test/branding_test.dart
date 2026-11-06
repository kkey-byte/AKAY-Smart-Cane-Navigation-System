import 'dart:ui' as ui;

import 'package:app_mobile/pages/shared/about_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/gabay_logo.dart';
import 'package:app_mobile/widgets/akay_logo_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Bundled AKAY logo has a transparent background', () async {
    final asset = await rootBundle.load('assets/branding/akay_logo.png');
    expect(akayLogoBytes, orderedEquals(asset.buffer.asUint8List()));
    final codec = await ui.instantiateImageCodec(asset.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final pixels = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(pixels, isNotNull);
    for (final offset in [
      0,
      (frame.image.width - 1) * 4,
      (frame.image.height - 1) * frame.image.width * 4,
      (frame.image.height * frame.image.width - 1) * 4,
    ]) {
      expect(pixels!.getUint8(offset + 3), 0);
    }
    frame.image.dispose();
    codec.dispose();
  });

  testWidgets('About shows AKAY and the supplied logo asset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: GabayTheme.lightTheme, home: const AboutPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('AKAY'), findsOneWidget);
    expect(find.text('GABAY'), findsNothing);
    expect(find.byType(GabayLogo), findsOneWidget);
    final logo = tester.widget<Image>(
      find.descendant(of: find.byType(GabayLogo), matching: find.byType(Image)),
    );
    expect((logo.image as MemoryImage).bytes, akayLogoBytes);
    expect(tester.takeException(), isNull);
  });
}
