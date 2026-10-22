import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group(A2uiSchemas, () {
    group('dataBindingSchema', () {
      test('requires path and emits the data-model description', () {
        final json = A2uiSchemas.dataBindingSchema().value;

        expect(json['type'], 'object');
        expect(json['required'], ['path']);
        final pathProp = (json['properties']! as Map)['path']! as Map;
        expect(pathProp['type'], 'string');
        expect(
          pathProp['description'],
          'A relative or absolute path in the data model.',
        );
      });
    });

    group('functionCall', () {
      test('requires call and allows arbitrary args', () {
        final json = A2uiSchemas.functionCall().value;

        expect(json['required'], ['call']);
        final args = (json['properties']! as Map)['args']! as Map;
        expect(args['type'], 'object');
        expect(args['additionalProperties'], isTrue);
      });
    });

    group('componentReference', () {
      test('defaults to a component ID description', () {
        final json = A2uiSchemas.componentReference().value;

        expect(json['type'], 'string');
        expect(json['description'], 'The ID of a component.');
      });

      test('honours an explicit description override', () {
        final json = A2uiSchemas.componentReference(
          description: 'child id',
        ).value;

        expect(json['description'], 'child id');
      });
    });

    group('stringReference', () {
      test('emits a oneOf of literal, binding, and function call', () {
        final json = A2uiSchemas.stringReference().value;
        final oneOf = json['oneOf']! as List<Object?>;

        expect(oneOf, hasLength(3));
        expect((oneOf[0]! as Map)['type'], 'string');
        final binding = (oneOf[1]! as Map)['properties']! as Map;
        expect(binding.containsKey('path'), isTrue);
        final function = (oneOf[2]! as Map)['properties']! as Map;
        expect(function.containsKey('call'), isTrue);
      });

      test('propagates enum values onto the literal branch', () {
        final json = A2uiSchemas.stringReference(
          enumValues: ['a', 'b'],
        ).value;
        final literal = (json['oneOf']! as List<Object?>).first! as Map;

        expect(literal['enum'], ['a', 'b']);
      });
    });

    group('numberReference', () {
      test('literal branch is a number', () {
        final json = A2uiSchemas.numberReference().value;
        final literal = (json['oneOf']! as List<Object?>).first! as Map;

        expect(literal['type'], 'number');
      });
    });

    group('booleanReference', () {
      test('literal branch is a boolean', () {
        final json = A2uiSchemas.booleanReference().value;
        final literal = (json['oneOf']! as List<Object?>).first! as Map;

        expect(literal['type'], 'boolean');
      });
    });

    group('componentArrayReference', () {
      test('combines an id list and a data-bound template', () {
        final json = A2uiSchemas.componentArrayReference().value;
        final oneOf = json['oneOf']! as List<Object?>;

        expect(oneOf, hasLength(2));
        final idList = oneOf.first! as Map;
        expect(idList['type'], 'array');
        expect((idList['items']! as Map)['type'], 'string');

        final template = oneOf.last! as Map;
        expect(template['required'], ['componentId', 'path']);
      });
    });

    group('stringArrayReference', () {
      test('literal branch is an array of strings', () {
        final json = A2uiSchemas.stringArrayReference().value;
        final literal = (json['oneOf']! as List<Object?>).first! as Map;

        expect(literal['type'], 'array');
        expect((literal['items']! as Map)['type'], 'string');
      });
    });

    group('validationCheck', () {
      test('requires message and condition', () {
        final json = A2uiSchemas.validationCheck().value;

        expect(json['required'], ['message', 'condition']);
      });
    });

    group('checkable', () {
      test('is an array of validation checks', () {
        final json = A2uiSchemas.checkable().value;

        expect(json['type'], 'array');
        final item = json['items']! as Map;
        expect(item['required'], ['message', 'condition']);
      });
    });

    group('action', () {
      test('is a oneOf of an event and a function call', () {
        final json = A2uiSchemas.action().value;
        final oneOf = json['oneOf']! as List<Object?>;

        expect(oneOf, hasLength(2));
        final eventBranch = oneOf.first! as Map;
        expect(eventBranch['required'], ['event']);
        final functionBranch = oneOf.last! as Map;
        expect(functionBranch['required'], ['functionCall']);
      });
    });

    group('listOrReference', () {
      test('literal branch is a list of the supplied item schema', () {
        final json = A2uiSchemas.listOrReference(
          items: A2uiSchemas.componentReference(),
        ).value;
        final literal = (json['oneOf']! as List<Object?>).first! as Map;

        expect(literal['type'], 'array');
        expect((literal['items']! as Map)['type'], 'string');
      });
    });

    group('propertyReference', () {
      test('emits a oneOf of any, binding, and function call', () {
        final json = A2uiSchemas.propertyReference().value;
        final oneOf = json['oneOf']! as List<Object?>;

        expect(oneOf, hasLength(3));
        final binding = (oneOf[1]! as Map)['properties']! as Map;
        expect(binding.containsKey('path'), isTrue);
        final function = (oneOf[2]! as Map)['properties']! as Map;
        expect(function.containsKey('call'), isTrue);
      });
    });

    group('clientFunctions', () {
      test('lists all 14 known A2UI client functions', () {
        final json = A2uiSchemas.clientFunctions().value;
        final items = json['items']! as Map;
        final oneOf = items['oneOf']! as List<Object?>;

        final callNames = <String>{};
        for (final item in oneOf) {
          final properties = (item! as Map)['properties']! as Map;
          final call = properties['call']! as Map;
          callNames.add(call['const']! as String);
        }

        expect(callNames, {
          'required',
          'regex',
          'length',
          'numeric',
          'email',
          'formatString',
          'formatNumber',
          'formatCurrency',
          'formatDate',
          'pluralize',
          'openUrl',
          'and',
          'or',
          'not',
        });
      });
    });
  });
}
