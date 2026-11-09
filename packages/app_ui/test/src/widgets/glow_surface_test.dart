import 'package:app_ui/src/widgets/glow_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(GlowSurface, () {
    testWidgets('places a glow from the left or from the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 260,
              child: GlowSurface(
                glows: [
                  Glow(left: -80, top: -120, size: 260, color: Colors.white),
                  Glow.fromRight(
                    right: -60,
                    top: 60,
                    size: 360,
                    color: Colors.orange,
                  ),
                ],
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      final positions = tester
          .widgetList<Positioned>(find.byType(Positioned))
          .toList();
      expect(positions[0].left, -80 - 260 / 4);
      expect(positions[0].right, isNull);
      expect(positions[1].right, -60 - 360 / 4);
      expect(positions[1].left, isNull);
    });

    testWidgets('keeps the content inside the border', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 260,
              child: GlowSurface(
                border: BorderSide(color: Colors.red, width: 2),
                child: SizedBox.expand(key: Key('content')),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const Key('content'))).width, 400 - 68);
    });
  });
}
