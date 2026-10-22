import 'package:home_backend/validation/catalog_component_validator.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

class _Component extends GenUiComponent {
  const _Component(this.name);
  @override
  final String name;
  @override
  Schema get schema => S.object(properties: const {});
}

GenUiComponentCatalog _catalog({
  String id = 'test/v1',
  List<String> names = const ['Column', 'Text'],
}) => GenUiComponentCatalog(
  id: id,
  components: [for (final name in names) _Component(name)],
);

String _fenced(String json) => '```json\n$json\n```';

void main() {
  group('CatalogComponentValidator', () {
    test('returns null for an empty response', () {
      final validator = CatalogComponentValidator(_catalog());
      expect(validator.validate(''), isNull);
    });

    test('returns null when no fenced json blocks are present', () {
      final validator = CatalogComponentValidator(_catalog());
      expect(validator.validate('plain prose with no fences'), isNull);
    });

    test('returns null for createSurface blocks (no component references)', () {
      final validator = CatalogComponentValidator(_catalog());
      final response = _fenced('''
{
  "version": "v0.9",
  "createSurface": {
    "surfaceId": "main",
    "catalogId": "test/v1",
    "sendDataModel": true
  }
}
''');
      expect(validator.validate(response), isNull);
    });

    test('returns null when every component name is in the catalog', () {
      final validator = CatalogComponentValidator(_catalog());
      final response = _fenced('''
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "main",
    "components": [
      {"id": "root", "component": "Column", "children": ["a"]},
      {"id": "a", "component": "Text", "text": "hi"}
    ]
  }
}
''');
      expect(validator.validate(response), isNull);
    });

    test('reports unknown components with catalog id in the message', () {
      final validator = CatalogComponentValidator(
        _catalog(id: 'example/catalogs/test/v1'),
      );
      final response = _fenced('''
{
  "updateComponents": {
    "surfaceId": "main",
    "components": [
      {"id": "root", "component": "FooBar"}
    ]
  }
}
''');
      final errors = validator.validate(response);
      const expected =
          'Component `FooBar` is not in the catalog with ID '
          '`example/catalogs/test/v1`.';
      expect(errors, [expected]);
    });

    test('dedupes repeated unknown names to one error line', () {
      final validator = CatalogComponentValidator(_catalog());
      final response = _fenced('''
{
  "updateComponents": {
    "surfaceId": "main",
    "components": [
      {"id": "a", "component": "Ghost"},
      {"id": "b", "component": "Ghost"},
      {"id": "c", "component": "Ghost"}
    ]
  }
}
''');
      final errors = validator.validate(response);
      expect(errors, hasLength(1));
      expect(errors!.single, contains('`Ghost`'));
    });

    test('reports multiple unknown names in first-seen order', () {
      final validator = CatalogComponentValidator(_catalog());
      final response = _fenced('''
{
  "updateComponents": {
    "surfaceId": "main",
    "components": [
      {"id": "a", "component": "Foo"},
      {"id": "b", "component": "Bar"},
      {"id": "c", "component": "Foo"}
    ]
  }
}
''');
      final errors = validator.validate(response);
      expect(errors, hasLength(2));
      expect(errors![0], contains('`Foo`'));
      expect(errors[1], contains('`Bar`'));
    });

    test('ignores malformed JSON blocks without false positives', () {
      final validator = CatalogComponentValidator(_catalog());
      final response =
          '${_fenced('not { valid json')}\n'
          '${_fenced('{"updateComponents": {"components": '
          '[{"component": "Column"}]}}')}';
      expect(validator.validate(response), isNull);
    });

    test('ignores components without a string `component` field', () {
      final validator = CatalogComponentValidator(_catalog());
      final response = _fenced('''
{
  "updateComponents": {
    "components": [
      {"id": "a"},
      {"id": "b", "component": 42},
      {"id": "c", "component": "Column"}
    ]
  }
}
''');
      expect(validator.validate(response), isNull);
    });

    test('walks every fenced block in the response', () {
      final validator = CatalogComponentValidator(_catalog());
      final block1 = _fenced(
        '{"updateComponents": {"components": [{"component": "Bogus1"}]}}',
      );
      final block2 = _fenced(
        '{"updateComponents": {"components": [{"component": "Bogus2"}]}}',
      );
      final response = '$block1\nsome prose\n$block2';
      final errors = validator.validate(response);
      expect(errors, hasLength(2));
      expect(errors![0], contains('`Bogus1`'));
      expect(errors[1], contains('`Bogus2`'));
    });
  });
}
