import 'package:home_timeline/home_timeline.dart';
import 'package:test/test.dart';

FeedRule _rule(Map<String, Object?> overrides) {
  final rules = FeedRules.fromJson({
    'recentMinutes': 30,
    'nextMinutes': 120,
    'rules': [
      {
        'source': 'thing',
        'at': 'when',
        'kind': 'demo',
        'summary': 'Hello {name}',
        ...overrides,
      },
    ],
  });
  return rules.rules.single;
}

void main() {
  final facts = <String, Object?>{
    'when': DateTime.utc(2026, 10, 10, 17, 40),
    'name': 'Ana',
    'id': 'abc',
    'flag': true,
  };

  group('FeedRules', () {
    test('reads the windows and every rule of the bundled file', () {
      final rules = FeedRules.bundled();

      expect(rules.recentWindow, const Duration(minutes: 30));
      expect(rules.nextWindow, const Duration(minutes: 120));
      expect(rules.rules, isNotEmpty);
    });
  });

  group('FeedRule', () {
    test('fills the summary, joining one given in parts', () {
      expect(_rule({}).moment(facts)!['summary'], 'Hello Ana');
      expect(
        _rule({
          'summary': ['at ', '{when}'],
        }).moment(facts)!['summary'],
        'at 5:40 PM',
      );
    });

    test('needs a summary', () {
      expect(
        () => FeedRules.fromJson({
          'recentMinutes': 1,
          'nextMinutes': 1,
          'rules': [
            {'source': 's', 'at': 'a', 'kind': 'k'},
          ],
        }),
        throwsArgumentError,
      );
    });

    test('is about the household unless it names a subject', () {
      expect(_rule({}).moment(facts)!['subject'], 'household');
      expect(_rule({'subject': '{id}'}).moment(facts)!['subject'], 'abc');
    });

    test('gives no moment when its time fact is absent', () {
      expect(_rule({'at': 'missing'}).moment(facts), isNull);
    });

    test('applies only while its condition holds', () {
      expect(_rule({'when': 'flag'}).moment(facts), isNotNull);
      expect(_rule({'when': '!flag'}).moment(facts), isNull);
      expect(_rule({'when': 'unset'}).moment(facts), isNull);
      expect(_rule({'when': '!unset'}).moment(facts), isNotNull);
    });

    test('leaves an id null when its fact is absent', () {
      final moment = _rule({'stepId': '{nothing}', 'tripId': '{id}'}).moment(
        facts,
      )!;

      expect(moment['stepId'], isNull);
      expect(moment['tripId'], 'abc');
    });

    test('carries its flags and the itinerary fact', () {
      final moment =
          _rule({
            'urgent': true,
            'pastOnly': true,
            'alwaysNext': true,
            'by': '{name}',
            'itinerary': 'stops',
          }).moment({
            ...facts,
            'stops': [1],
          })!;

      expect(moment['urgent'], isTrue);
      expect(moment['pastOnly'], isTrue);
      expect(moment['alwaysNext'], isTrue);
      expect(moment['by'], 'Ana');
      expect(moment['itinerary'], [1]);
    });
  });
}
