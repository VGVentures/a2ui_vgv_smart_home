import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

const _lockup = BrandLockup(
  semanticLabel: 'Very Good Ventures, A2UI Smart Home',
);

void main() {
  group(BrandLockup, () {
    testWidgets('draws the lockup at its native 305 x 57', (tester) async {
      await tester.pumpComponent(_lockup);

      expect(tester.getSize(find.byType(SvgPicture)), const Size(305, 57));
    });

    testWidgets('keeps the colours the lockup is drawn in', (tester) async {
      await tester.pumpComponent(_lockup);

      expect(
        tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
        isNull,
      );
    });

    testWidgets('reads as the brand to assistive tech', (tester) async {
      await tester.pumpComponent(_lockup);

      expect(
        find.bySemanticsLabel('Very Good Ventures, A2UI Smart Home'),
        findsOneWidget,
      );
    });

    testWidgets('points at the lockup the package bundles', (tester) async {
      await tester.pumpComponent(_lockup);

      final loader =
          tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
              as SvgAssetLoader;
      final svg = await rootBundle.loadString(
        'packages/${loader.packageName}/${loader.assetName}',
      );
      // The full lockup, not the unicorn on its own.
      expect(svg, startsWith('<svg width="305" height="57"'));
    });
  });
}
