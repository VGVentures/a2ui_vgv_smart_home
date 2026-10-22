import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

class _FakeComponent extends GenUiComponent {
  const _FakeComponent();

  @override
  String get name => 'Fake';

  @override
  Schema get schema => S.object(
    description: 'fake',
    properties: {'label': S.string()},
    required: ['label'],
  );
}

class _BadComponent extends GenUiComponent {
  const _BadComponent();

  @override
  String get name => 'Bad';

  @override
  Schema get schema => S.object(
    description: 'declares its own component key',
    properties: {
      'component': S.string(),
      'label': S.string(),
    },
    required: ['label'],
  );
}

void main() {
  group('renderA2uiMessageSchema', () {
    test('emits valid indented JSON', () {
      final rendered = renderA2uiMessageSchema(homeCatalog);

      // Parses without error.
      final decoded = jsonDecode(rendered) as Map<String, Object?>;
      expect(decoded['title'], 'A2UI Message Schema');
      expect(decoded['description'], isA<String>());
      expect(decoded['oneOf'], isA<List<Object?>>());
    });

    test('compact renders the same schema without indentation', () {
      final indented = renderA2uiMessageSchema(homeCatalog);
      final compact = renderA2uiMessageSchema(homeCatalog, compact: true);

      expect(jsonDecode(compact), jsonDecode(indented));
      expect(compact, isNot(contains('\n')));
      expect(compact.length, lessThan(indented.length ~/ 2));
    });

    test('lean keeps the two taught messages and drops description texts', () {
      final lean = renderLeanA2uiMessageSchema(homeCatalog);
      final decoded = jsonDecode(lean) as Map<String, Object?>;
      final oneOf = (decoded['oneOf']! as List).cast<Map<String, Object?>>();

      expect(oneOf.map(_messageTypeOf), ['createSurface', 'updateComponents']);
      expect(lean, isNot(contains('"description":"')));
      expect(
        lean.length,
        lessThan(renderA2uiMessageSchema(homeCatalog, compact: true).length),
      );
      for (final name in homeCatalog.components.keys) {
        expect(lean, contains('"$name"'));
      }
    });

    test(
      'oneOf includes all four A2UI message types in declaration order',
      () {
        final rendered = renderA2uiMessageSchema(homeCatalog);
        final decoded = jsonDecode(rendered) as Map<String, Object?>;
        final oneOf = (decoded['oneOf']! as List).cast<Map<String, Object?>>();

        expect(oneOf, hasLength(4));
        expect(_messageTypeOf(oneOf[0]), 'createSurface');
        expect(_messageTypeOf(oneOf[1]), 'updateComponents');
        expect(_messageTypeOf(oneOf[2]), 'updateDataModel');
        expect(_messageTypeOf(oneOf[3]), 'deleteSurface');
      },
    );

    test('createSurface.catalogId carries a `const` of the catalog id', () {
      // The LLM is locked to this exact catalog — no other id is valid.
      final catalog = Catalog<GenUiComponent>(
        id: 'example/catalogs/test/v1',
        components: const [_FakeComponent()],
      );

      final rendered = renderA2uiMessageSchema(catalog);
      final decoded = jsonDecode(rendered) as Map<String, Object?>;
      final createSurface = _branchForMessage(decoded, 'createSurface');
      final catalogId =
          (createSurface['properties']! as Map<String, Object?>)['catalogId']!
              as Map<String, Object?>;

      expect(catalogId['type'], 'string');
      expect(catalogId['const'], 'example/catalogs/test/v1');
    });

    test(
      'updateComponents.components.items.oneOf has one augmented entry '
      'per catalog component, in catalog order',
      () {
        // Each component gets the `component` discriminator enum injected and
        // its name added to `required`, mirroring `package:genui`'s
        // CatalogItem.dataSchema augmentation.
        final rendered = renderA2uiMessageSchema(homeCatalog);
        final decoded = jsonDecode(rendered) as Map<String, Object?>;
        final updateComponents = _branchForMessage(decoded, 'updateComponents');
        final componentsProp =
            (updateComponents['properties']!
                    as Map<String, Object?>)['components']!
                as Map<String, Object?>;
        final items = componentsProp['items']! as Map<String, Object?>;
        final oneOf = (items['oneOf']! as List).cast<Map<String, Object?>>();

        final names = oneOf.map(_componentDiscriminator).toList();
        expect(names, homeCatalog.components.keys.toList());

        for (final entry in oneOf) {
          final required = (entry['required']! as List).cast<String>();
          expect(required.first, 'component');
        }
      },
    );

    test('renders DeviceCard.status as its A2uiSchemas oneOf branches', () {
      // A regression in A2uiSchemas.stringReference() would change the branch
      // shapes and silently alter what the LLM is told to emit.
      final rendered = renderA2uiMessageSchema(homeCatalog);
      final decoded = jsonDecode(rendered) as Map<String, Object?>;
      final updateComponents = _branchForMessage(decoded, 'updateComponents');
      final componentsProp =
          (updateComponents['properties']!
                  as Map<String, Object?>)['components']!
              as Map<String, Object?>;
      final items = componentsProp['items']! as Map<String, Object?>;
      final oneOf = (items['oneOf']! as List).cast<Map<String, Object?>>();

      final device = oneOf.firstWhere(
        (entry) => _componentDiscriminator(entry) == 'DeviceCard',
      );
      final status =
          (device['properties']! as Map<String, Object?>)['status']!
              as Map<String, Object?>;
      expect(status['oneOf']! as List, hasLength(3));
    });

    test('gives every component a weight of 1 to 12 columns', () {
      // A model follows the schema it is given, so the weight a `Row` reads
      // as the columns a card spans has to be in it, even in the lean one.
      for (final render in [
        renderA2uiMessageSchema(homeCatalog),
        renderLeanA2uiMessageSchema(homeCatalog),
      ]) {
        final decoded = jsonDecode(render) as Map<String, Object?>;
        final update = _branchForMessage(decoded, 'updateComponents');
        final items =
            ((update['properties']! as Map<String, Object?>)['components']!
                    as Map<String, Object?>)['items']!
                as Map<String, Object?>;
        for (final entry
            in (items['oneOf']! as List).cast<Map<String, Object?>>()) {
          final weight =
              (entry['properties']! as Map<String, Object?>)['weight']!
                  as Map<String, Object?>;
          expect(weight['type'], 'integer', reason: '${entry['properties']}');
          expect(weight['minimum'], 1);
          expect(weight['maximum'], 12);
          expect(entry['required'], isNot(contains('weight')));
        }
      }
    });

    test(
      'writes the protocol version of the one constant in every message',
      () {
        final decoded =
            jsonDecode(renderA2uiMessageSchema(homeCatalog))
                as Map<String, Object?>;
        final branches = (decoded['oneOf']! as List)
            .cast<Map<String, Object?>>();

        expect(branches, hasLength(4));
        for (final branch in branches) {
          final version =
              (branch['properties']! as Map<String, Object?>)['version']!
                  as Map<String, Object?>;
          expect(version['const'], a2uiVersion);
        }
      },
    );

    test('is deterministic across calls', () {
      // The rendered output lands in the API server's prompt; any source of
      // nondeterminism would surface as a prompt diff.
      final first = renderA2uiMessageSchema(homeCatalog);
      final second = renderA2uiMessageSchema(homeCatalog);

      expect(first, second);
    });

    test('throws when a component schema already declares a "component" '
        'property', () {
      // Mirroring the augmentation in `package:genui`'s CatalogItem, the
      // renderer injects the `component` discriminator itself. A schema
      // that also declared it would silently get a contradictory shape;
      // surface the bug at server bootstrap instead.
      final catalog = Catalog<GenUiComponent>(
        id: 'test',
        components: const [_BadComponent()],
      );

      expect(
        () => renderA2uiMessageSchema(catalog),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('"component" property'),
          ),
        ),
      );
    });
  });
}

String _messageTypeOf(Map<String, Object?> branch) {
  final properties = branch['properties']! as Map<String, Object?>;
  // The branch has a `version` key plus exactly one message-type key.
  return properties.keys.firstWhere((key) => key != 'version');
}

Map<String, Object?> _branchForMessage(
  Map<String, Object?> schema,
  String messageType,
) {
  final oneOf = (schema['oneOf']! as List).cast<Map<String, Object?>>();
  final branch = oneOf.firstWhere(
    (b) => _messageTypeOf(b) == messageType,
  );
  return (branch['properties']! as Map<String, Object?>)[messageType]!
      as Map<String, Object?>;
}

String _componentDiscriminator(Map<String, Object?> componentSchema) {
  final properties = componentSchema['properties']! as Map<String, Object?>;
  final component = properties['component']! as Map<String, Object?>;
  return (component['enum']! as List).cast<String>().single;
}
