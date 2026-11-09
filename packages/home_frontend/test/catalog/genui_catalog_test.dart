import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_frontend/src/catalog/genui_catalog.dart';

Widget _stubBuilder(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => const SizedBox.shrink();

void main() {
  group('buildCatalog', () {
    test('zips the shared catalog with the matching widget builders', () {
      final catalog = buildCatalog(
        catalog: homeCatalog,
        widgetBuilders: widgetBuilders,
      );

      expect(
        catalog.components.keys.toList(),
        homeCatalog.components.keys.toList(),
      );
    });

    test('carries each component schema onto its implementation', () {
      final catalog = buildCatalog(
        catalog: homeCatalog,
        widgetBuilders: widgetBuilders,
      );

      for (final component in homeCatalog.components.values) {
        expect(
          catalog.components[component.name]!.schema.value,
          component.schema.value,
        );
      }
    });

    test('forwards the shared catalog id and speaks A2UI 1.0', () {
      final catalog = buildCatalog(
        catalog: homeCatalog,
        widgetBuilders: widgetBuilders,
      );

      expect(catalog.id, homeCatalog.id);
      expect(catalog.protocolVersion, A2uiProtocolVersion.v1_0);
    });

    test('uses the components passed by the caller', () {
      final customCatalog = GenUiComponentCatalog(
        id: 'custom',
        protocolVersion: A2uiProtocolVersion.v1_0,
        components: const [DeviceCardComponentDefinition()],
      );

      final catalog = buildCatalog(
        catalog: customCatalog,
        widgetBuilders: const {'DeviceCard': _stubBuilder},
      );

      expect(catalog.components.keys, ['DeviceCard']);
    });

    test('throws when no widget builder is registered for a component', () {
      // A missing builder for a declared component is a configuration bug.
      // The error must surface eagerly (at construction) so the stack
      // points at the call site instead of a downstream render failure.
      expect(
        () => buildCatalog(
          catalog: homeCatalog,
          widgetBuilders: const {},
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No widget builder registered'),
          ),
        ),
      );
    });
  });

  group('a catalog built by buildCatalog', () {
    testWidgets('renders a createSurface the schema accepts', (tester) async {
      // The messages go through the renderer's own validation, so this also
      // checks that what the schemas ask the model for is what they accept.
      final processor = MessageProcessor<ComponentImplementation>(
        catalogs: [
          buildCatalog(
            catalog: homeCatalog,
            widgetBuilders: widgetBuilders,
          ),
        ],
        defaultVersion: A2uiProtocolVersion.v1_0,
      );
      addTearDown(processor.model.dispose);

      processor.processMessages([
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': 'surface',
            'catalogId': genUiCatalogId,
            'components': [
              {
                'id': 'root',
                'component': 'Column',
                'children': ['row', 'chips'],
              },
              {
                'id': 'row',
                'component': 'Row',
                'children': ['oven'],
              },
              {
                'id': 'oven',
                'component': 'DeviceCard',
                'deviceId': 'oven',
                'name': 'Oven',
                'weight': 4,
                'status': {'@path': '/oven/status'},
              },
              {
                'id': 'chips',
                'component': 'ActionChips',
                'chips': [
                  {
                    'label': 'Brew',
                    'action': {
                      'command': {'deviceId': 'oven', 'command': 'start'},
                    },
                  },
                ],
              },
            ],
            'dataModel': {
              'oven': {'status': 'Preheats at 6:00 PM'},
            },
          },
        },
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 1104,
              height: 632,
              child: SurfaceView(
                surface: processor.model.getSurface('surface')!,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Oven'), findsOneWidget);
      expect(find.text('Preheats at 6:00 PM'), findsOneWidget);
    });
  });
}
