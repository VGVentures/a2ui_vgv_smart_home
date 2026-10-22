import 'dart:math';

import 'package:home_api_client/home_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('newSessionId', () {
    test('is 32 characters the backend accepts', () {
      expect(newSessionId(), matches(RegExp(r'^[A-Za-z0-9_-]{32}$')));
    });

    test('differs between visitors', () {
      final ids = {for (var i = 0; i < 50; i++) newSessionId()};

      expect(ids, hasLength(50));
    });

    test('follows the random source it is given', () {
      expect(newSessionId(Random(1)), newSessionId(Random(1)));
      expect(newSessionId(Random(1)), isNot(newSessionId(Random(2))));
    });
  });
}
