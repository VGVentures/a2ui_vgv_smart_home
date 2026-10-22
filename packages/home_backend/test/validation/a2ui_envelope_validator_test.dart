import 'package:home_backend/validation/a2ui_envelope_validator.dart';
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

GenUiComponentCatalog _catalog({String id = 'test/v1'}) =>
    GenUiComponentCatalog(
      id: id,
      components: const [_Component('Column'), _Component('Text')],
    );

A2uiEnvelopeValidator _validator({String id = 'test/v1'}) =>
    A2uiEnvelopeValidator(_catalog(id: id));

String _fenced(String json) => '```json\n$json\n```';

void main() {
  group('A2uiEnvelopeValidator', () {
    test('fails a plain-text response with no fenced json', () {
      final errors = _validator().validate(
        'The current UTC time is 2026-07-02T12:03:51.290099Z.',
      );
      expect(errors, isNotNull);
      expect(errors, hasLength(1));
    });

    test('fails an empty response', () {
      expect(_validator().validate(''), isNotNull);
    });

    test('fails when a fenced block carries no A2UI message key', () {
      final response = _fenced('{"utc_time": "2026-07-02T12:03:51Z"}');
      expect(_validator().validate(response), isNotNull);
    });

    test('fails when a fenced block is not valid json', () {
      final response = _fenced('not: valid: json');
      expect(_validator().validate(response), isNotNull);
    });

    test('passes a valid createSurface targeting the catalog', () {
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
      expect(_validator().validate(response), isNull);
    });

    test('passes a valid updateComponents message', () {
      final response = _fenced('''
{
  "version": "v0.9",
  "updateComponents": {"surfaceId": "main", "components": []}
}
''');
      expect(_validator().validate(response), isNull);
    });

    test('passes when A2UI is present alongside surrounding prose', () {
      final block = _fenced('''
{
  "version": "v0.9",
  "createSurface": {"surfaceId": "s", "catalogId": "test/v1"}
}
''');
      expect(_validator().validate('Here is the time:\n$block'), isNull);
    });

    test('fails createSurface that targets the wrong catalog', () {
      final response = _fenced('''
{
  "version": "v0.9",
  "createSurface": {"surfaceId": "s", "catalogId": "other/v1"}
}
''');
      final errors = _validator().validate(response);
      expect(errors, isNotNull);
      expect(errors!.single, contains('`test/v1`'));
    });

    test('fails createSurface missing catalogId', () {
      final response = _fenced('''
{
  "version": "v0.9",
  "createSurface": {"surfaceId": "s"}
}
''');
      final errors = _validator().validate(response);
      expect(errors, isNotNull);
      expect(errors!.any((e) => e.contains('catalogId')), isTrue);
    });

    test('fails updateComponents missing surfaceId', () {
      final response = _fenced('''
{
  "version": "v0.9",
  "updateComponents": {"components": []}
}
''');
      final errors = _validator().validate(response);
      expect(errors, isNotNull);
      expect(errors!.single, contains('surfaceId'));
    });

    test('fails updateComponents whose components is not an array', () {
      final response = _fenced('''
{
  "version": "v0.9",
  "updateComponents": {"surfaceId": "main", "components": "nope"}
}
''');
      final errors = _validator().validate(response);
      expect(errors, isNotNull);
      expect(errors!.single, contains('array'));
    });

    test('fails a block holding more than one message', () {
      final response = _fenced('''
{
  "version": "v0.9",
  "createSurface": {"surfaceId": "s", "catalogId": "test/v1"},
  "updateComponents": {"surfaceId": "s", "components": []}
}
''');
      final errors = _validator().validate(response);
      expect(errors, isNotNull);
      expect(errors!.single, contains('exactly one'));
    });

    test('fails a message missing version', () {
      final response = _fenced('''
{
  "createSurface": {"surfaceId": "s", "catalogId": "test/v1"}
}
''');
      final errors = _validator().validate(response);
      expect(errors, isNotNull);
      expect(errors!.any((e) => e.contains('version')), isTrue);
    });

    test('fails a message with a version below v0.9', () {
      final response = _fenced('''
{
  "version": "v0.8",
  "createSurface": {"surfaceId": "s", "catalogId": "test/v1"}
}
''');
      final errors = _validator().validate(response);
      expect(errors, isNotNull);
      expect(errors!.any((e) => e.contains('version')), isTrue);
    });

    test('passes a message with a higher minor version (v0.10)', () {
      final response = _fenced('''
{
  "version": "v0.10",
  "createSurface": {"surfaceId": "s", "catalogId": "test/v1"}
}
''');
      expect(_validator().validate(response), isNull);
    });

    test('passes a message with a higher major version (v1.0)', () {
      final response = _fenced('''
{
  "version": "v1.0",
  "createSurface": {"surfaceId": "s", "catalogId": "test/v1"}
}
''');
      expect(_validator().validate(response), isNull);
    });

    test('fails when a valid message is joined by a malformed sibling', () {
      final good = _fenced('''
{
  "version": "v0.9",
  "createSurface": {"surfaceId": "s", "catalogId": "test/v1"}
}
''');
      final bad = _fenced('''
{
  "version": "v0.9",
  "updateComponents": {"surfaceId": "s"}
}
''');
      final errors = _validator().validate('$good\n$bad');
      expect(errors, isNotNull);
      expect(errors!.single, contains('components'));
    });
  });
}
