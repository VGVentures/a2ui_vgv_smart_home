import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_frontend/src/catalog/genui_catalog.dart';

MessageProcessor<ComponentImplementation> _processor() {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [
      buildCatalog(catalog: homeCatalog, widgetBuilders: widgetBuilders),
    ],
    defaultVersion: A2uiProtocolVersion.v1_0,
  );
  addTearDown(processor.model.dispose);
  return processor;
}

Map<String, Object?> _create([String id = 's']) => {
  'version': '1.0',
  'createSurface': {'surfaceId': id, 'catalogId': genUiCatalogId},
};

Map<String, Object?> _root(String name) => {
  'version': '1.0',
  'updateComponents': {
    'surfaceId': 's',
    'components': [
      {
        'id': 'root',
        'component': 'Column',
        'children': ['card'],
      },
      {
        'id': 'card',
        'component': 'DeviceCard',
        'deviceId': 'oven',
        'name': name,
        'status': 'Off',
      },
    ],
  },
};

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: 600, height: 400, child: child),
  ),
);

void main() {
  group(SurfaceView, () {
    testWidgets('shows the placeholder until the surface has a root', (
      tester,
    ) async {
      final processor = _processor()..processMessages([_create()]);
      final surface = processor.model.getSurface('s')!;

      await tester.pumpWidget(
        _app(
          SurfaceView(
            surface: surface,
            placeholder: const Text('loading'),
          ),
        ),
      );
      expect(find.text('loading'), findsOneWidget);

      processor.processMessages([_root('Oven')]);
      await tester.pump();

      expect(find.text('loading'), findsNothing);
      expect(find.text('Oven'), findsOneWidget);
    });

    testWidgets('draws nothing without a placeholder until there is a root', (
      tester,
    ) async {
      final processor = _processor()..processMessages([_create()]);

      await tester.pumpWidget(
        _app(SurfaceView(surface: processor.model.getSurface('s')!)),
      );

      expect(find.byType(A2uiSurface), findsNothing);
    });

    testWidgets('draws a surface that already has a root at once', (
      tester,
    ) async {
      final processor = _processor()
        ..processMessages([_create(), _root('Oven')]);

      await tester.pumpWidget(
        _app(
          SurfaceView(
            surface: processor.model.getSurface('s')!,
            placeholder: const Text('loading'),
          ),
        ),
      );

      expect(find.text('loading'), findsNothing);
      expect(find.text('Oven'), findsOneWidget);
    });

    testWidgets('ignores a component that is not the root', (tester) async {
      final processor = _processor()..processMessages([_create()]);

      await tester.pumpWidget(
        _app(
          SurfaceView(
            surface: processor.model.getSurface('s')!,
            placeholder: const Text('loading'),
          ),
        ),
      );
      processor.processMessages([
        {
          'version': '1.0',
          'updateComponents': {
            'surfaceId': 's',
            'components': [
              {
                'id': 'card',
                'component': 'DeviceCard',
                'deviceId': 'oven',
                'name': 'Oven',
                'status': 'Off',
              },
            ],
          },
        },
      ]);
      await tester.pump();

      expect(find.text('loading'), findsOneWidget);
    });

    testWidgets('follows a new surface', (tester) async {
      final processor = _processor()
        ..processMessages([
          _create(),
          _root('Oven'),
          _create('t'),
        ]);
      final first = processor.model.getSurface('s')!;
      final second = processor.model.getSurface('t')!;

      await tester.pumpWidget(
        _app(SurfaceView(surface: first, placeholder: const Text('loading'))),
      );
      expect(find.text('Oven'), findsOneWidget);

      await tester.pumpWidget(
        _app(SurfaceView(surface: second, placeholder: const Text('loading'))),
      );

      expect(find.text('Oven'), findsNothing);
      expect(find.text('loading'), findsOneWidget);
    });
  });
}
