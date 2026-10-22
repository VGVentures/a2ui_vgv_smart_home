import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/catalog/genui_catalog.dart';
import 'package:home_frontend/src/catalog/widget_builders.dart';

Future<SurfaceController> _pump(
  WidgetTester tester,
  Map<String, Object?> properties,
  String type,
) async {
  const surfaceId = 'surface';
  final controller = SurfaceController(
    catalogs: [
      buildCatalog(catalog: homeCatalog, widgetBuilders: widgetBuilders),
    ],
  );
  addTearDown(controller.dispose);
  controller
    ..handleMessage(
      UpdateComponents(
        surfaceId: surfaceId,
        components: [Component(id: 'root', type: type, properties: properties)],
      ),
    )
    ..handleMessage(
      const CreateSurface(surfaceId: surfaceId, catalogId: genUiCatalogId),
    );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Surface(surfaceContext: controller.contextFor(surfaceId)),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  group('home widget builders', () {
    testWidgets('lay out inside a Row without unbounded width errors', (
      tester,
    ) async {
      const surfaceId = 'row_surface';
      final controller = SurfaceController(
        catalogs: [
          buildCatalog(
            catalog: homeCatalog,
            widgetBuilders: widgetBuilders,
          ),
        ],
      );
      addTearDown(controller.dispose);
      controller
        ..handleMessage(
          const UpdateComponents(
            surfaceId: surfaceId,
            components: [
              Component(
                id: 'root',
                type: 'Row',
                properties: {
                  'children': ['plan', 'alert'],
                },
              ),
              Component(
                id: 'plan',
                type: 'PlanTimeline',
                properties: {
                  'entries': [
                    {'time': '18:00', 'title': 'Preheat oven'},
                    {'time': '19:00', 'title': 'Guests arrive'},
                  ],
                },
              ),
              Component(
                id: 'alert',
                type: 'HeadsUpCard',
                properties: {
                  'title': 'Heads up',
                  'message': 'Dinner moved',
                  'variant': 'urgent',
                },
              ),
            ],
          ),
        )
        ..handleMessage(
          const CreateSurface(surfaceId: surfaceId, catalogId: genUiCatalogId),
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Surface(surfaceContext: controller.contextFor(surfaceId)),
          ),
        ),
      );

      expect(find.byType(PlanTimeline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('catalog icon enum matches the app_ui icon names', () {
      final properties =
          const DeviceCardComponentDefinition().schema.value['properties']!
              as Map;
      final icon = properties['icon']! as Map;

      expect(icon['enum'], AppIcons.names);
    });

    test('cover every home component in the catalog', () {
      for (final name in homeCatalog.components.keys) {
        expect(widgetBuilders, contains(name));
      }
    });

    testWidgets('PlanTimeline renders its entries', (tester) async {
      await _pump(tester, {
        'title': 'Tonight',
        'entries': [
          {'time': '6:00 PM', 'title': 'Preheat', 'icon': 'oven'},
          {'time': '7:00 PM', 'title': 'Guests', 'previousTime': '6:00'},
          {'time': '8:00 PM', 'title': 'Dinner', 'detail': 'For six'},
        ],
      }, 'PlanTimeline');

      expect(find.text('Tonight'), findsOneWidget);
      expect(find.text('Preheat'), findsOneWidget);
      expect(find.text('For six'), findsOneWidget);
    });
  });
}
