import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_frontend/src/catalog/genui_catalog.dart';
import 'package:home_frontend/src/catalog/widget_builders.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

Widget _stubBuilder(CatalogItemContext _) => const SizedBox.shrink();

/// A component missing from [implicitlyFlexibleComponents].
class _UnknownComponentDefinition extends GenUiComponent {
  const _UnknownComponentDefinition();

  @override
  String get name => 'Unknown';

  @override
  Schema get schema => S.object(properties: {});
}

void main() {
  group('buildCatalog', () {
    test('zips the shared catalog with the matching widget builders', () {
      final catalog = buildCatalog(
        catalog: homeCatalog,
        widgetBuilders: widgetBuilders,
      );

      expect(
        catalog.items.map((item) => item.name).toList(),
        homeCatalog.components.keys.toList(),
      );
    });

    test('forwards the shared catalog id', () {
      final catalog = buildCatalog(
        catalog: homeCatalog,
        widgetBuilders: widgetBuilders,
      );

      expect(catalog.catalogId, homeCatalog.id);
    });

    test('includes the basic catalog rules in the system prompt', () {
      final catalog = buildCatalog(
        catalog: homeCatalog,
        widgetBuilders: widgetBuilders,
      );

      expect(
        catalog.systemPromptFragments,
        contains(BasicCatalogItems.basicCatalogRules),
      );
    });

    test(
      'lists the available components in a catalog restriction fragment',
      () {
        final catalog = buildCatalog(
          catalog: homeCatalog,
          widgetBuilders: widgetBuilders,
        );

        expect(
          catalog.systemPromptFragments,
          contains(
            allOf(
              contains('`Column`'),
              contains('`Row`'),
              contains('`PlanTimeline`'),
              contains('`ChangeSummary`'),
            ),
          ),
        );
      },
    );

    test('omits the system prompt fragment when the default is empty', () {
      final catalog = buildCatalog(
        catalog: homeCatalog,
        widgetBuilders: widgetBuilders,
      );

      expect(catalog.systemPromptFragments, isNot(contains('')));
    });

    test('appends the system prompt when provided', () {
      const customPrompt = 'Describe a memorable train station.';

      final catalog = buildCatalog(
        catalog: homeCatalog,
        widgetBuilders: widgetBuilders,
        systemPrompt: customPrompt,
      );

      expect(catalog.systemPromptFragments, contains(customPrompt));
    });

    test('uses the components passed by the caller', () {
      // Brick consumers swap the shared catalog for a custom one. The built
      // catalog must ship the components it was given and mention them in
      // the restriction fragment so the LLM only references available
      // components.
      final customCatalog = GenUiComponentCatalog(
        id: 'custom',
        components: const [DeviceCardComponentDefinition()],
      );

      final catalog = buildCatalog(
        catalog: customCatalog,
        widgetBuilders: const {'DeviceCard': _stubBuilder},
      );

      expect(catalog.items.map((i) => i.name), ['DeviceCard']);
      expect(
        catalog.systemPromptFragments,
        contains(
          allOf(contains('`DeviceCard`'), isNot(contains('`Column`'))),
        ),
      );
    });

    test('carries isImplicitlyFlexible onto every item', () {
      final catalog = buildCatalog(
        catalog: homeCatalog,
        widgetBuilders: widgetBuilders,
      );

      expect({
        for (final item in catalog.items)
          if (item.isImplicitlyFlexible) item.name,
      }, implicitlyFlexibleComponents);
    });

    test('matches the flags on BasicCatalogItems', () {
      // The builders delegate to `BasicCatalogItems`, so drifting from its
      // flags re-introduces the unbounded-width failure.
      final basic = {
        for (final item in BasicCatalogItems.asCatalog().items)
          item.name: item.isImplicitlyFlexible,
      };
      final shared = widgetBuilders.keys.where(basic.containsKey);

      expect(shared, isNotEmpty);
      for (final name in shared) {
        expect(
          implicitlyFlexibleComponents.contains(name),
          basic[name],
          reason: '$name disagrees with BasicCatalogItems.$name',
        );
      }
    });

    test('leaves isImplicitlyFlexible false for an unflagged component', () {
      final customCatalog = GenUiComponentCatalog(
        id: 'custom',
        components: const [_UnknownComponentDefinition()],
      );

      final catalog = buildCatalog(
        catalog: customCatalog,
        widgetBuilders: const {'Unknown': _stubBuilder},
      );

      expect(catalog.items.single.isImplicitlyFlexible, isFalse);
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
    testWidgets('renders a width-filling card inside a Row', (tester) async {
      // The crash repro: a card that fills its width must get a bounded share
      // of the row, or the surface never paints.
      const surfaceId = 'surface';
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
                  'children': ['oven'],
                },
              ),
              Component(
                id: 'oven',
                type: 'DeviceCard',
                properties: {
                  'deviceId': 'oven',
                  'name': 'Oven',
                  'status': 'Preheats at 6:00 PM',
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

      expect(tester.takeException(), isNull);
      expect(find.text('Oven'), findsOneWidget);
    });
  });
}
