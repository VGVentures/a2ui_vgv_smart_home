import 'dart:typed_data';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, KitchenLight light) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: KitchenBackdrop(light: light),
      ),
    );

void main() {
  group(KitchenLight, () {
    test('has a photograph of the kitchen for each part of the day', () {
      expect(KitchenLight.values.map((light) => light.name), [
        'morning',
        'day',
        'sunset',
        'evening',
      ]);
      expect(
        KitchenLight.day.image,
        const AssetImage('assets/images/kitchen_day.jpg', package: 'app_ui'),
      );
    });

    testWidgets('preload fills the image cache with every kitchen', (
      tester,
    ) async {
      await tester.runAsync(KitchenLight.preload);

      for (final light in KitchenLight.values) {
        final key = await light.image.obtainKey(ImageConfiguration.empty);
        expect(PaintingBinding.instance.imageCache.containsKey(key), isTrue);
      }
    });
  });

  testWidgets('a kitchen that fails to load does not hold the preload back', (
    tester,
  ) async {
    final broken = MemoryImage(Uint8List.fromList([1, 2, 3]));

    await tester.runAsync(() => KitchenLight.load(broken));
  });

  group(KitchenBackdrop, () {
    testWidgets('shows the kitchen in its light, filling the space', (
      tester,
    ) async {
      await _pump(tester, KitchenLight.sunset);

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, KitchenLight.sunset.image);
      expect(image.fit, BoxFit.cover);
    });

    testWidgets('fades to a new light over the old one', (tester) async {
      await _pump(tester, KitchenLight.morning);
      await _pump(tester, KitchenLight.evening);
      await tester.pump(KitchenBackdrop.fade ~/ 2);

      expect(find.byType(Image), findsNWidgets(2));

      await tester.pump(KitchenBackdrop.fade);

      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        KitchenLight.evening.image,
      );
    });
  });
}
