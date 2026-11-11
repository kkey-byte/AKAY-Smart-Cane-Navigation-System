import 'package:app_mobile/widgets/shared/gabay_modal_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared modal timing respects reduced motion', (tester) async {
    for (final reduced in [false, true]) {
      late AnimationStyle style;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Builder(
              builder: (context) {
                style = gabayModalAnimation(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(
        style.duration,
        reduced ? Duration.zero : const Duration(milliseconds: 260),
      );
      expect(
        style.reverseDuration,
        reduced ? Duration.zero : const Duration(milliseconds: 200),
      );
    }
  });
}
