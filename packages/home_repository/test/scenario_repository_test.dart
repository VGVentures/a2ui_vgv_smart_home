import 'dart:convert';

import 'package:home_api_client/home_api_client.dart';
import 'package:home_repository/src/scenario_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _reading = {
  'now': '2026-10-10T16:45:00',
  'start': '2026-10-10T16:30:00',
  'end': '2026-10-10T23:59:00',
  'timeZone': 'America/Chicago',
};

void main() {
  group('wall time', () {
    test('reads a naive time as UTC wall time and writes it back', () {
      final time = parseWallTime('2026-10-10T16:30:00');

      expect(time, DateTime.utc(2026, 10, 10, 16, 30));
      expect(formatWallTime(time), '2026-10-10T16:30:00');
      expect(parseWallTime('2026-10-10T16:30:00Z'), time);
    });
  });

  group(ScenarioReading, () {
    test('reads the clock the backend answers', () {
      final reading = ScenarioReading.fromJson(_reading);

      expect(reading.now, DateTime.utc(2026, 10, 10, 16, 45));
      expect(reading.start, DateTime.utc(2026, 10, 10, 16, 30));
      expect(reading.end, DateTime.utc(2026, 10, 10, 23, 59));
    });

    test('compares by value', () {
      expect(
        ScenarioReading.fromJson(_reading),
        ScenarioReading.fromJson(_reading),
      );
    });
  });

  group('HttpScenarioRepository', () {
    HttpScenarioRepository build(http.Client client) => HttpScenarioRepository(
      client: HomeApiClient(
        sessionId: 'visitor-0123456789abcdef',
        baseUri: Uri.parse('http://localhost:8080'),
        httpClient: client,
      ),
    );

    test('moves the clock and reads the answer', () async {
      late http.Request seen;
      final repository = build(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode(_reading), 200);
        }),
      );

      final reading = await repository.moveTo(
        DateTime.utc(2026, 10, 10, 16, 45),
      );

      expect(jsonDecode(seen.body), {'to': '2026-10-10T16:45:00'});
      expect(reading.now, DateTime.utc(2026, 10, 10, 16, 45));
    });

    test('resets and reads the answer', () async {
      late http.Request seen;
      final repository = build(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode(_reading), 200);
        }),
      );

      final reading = await repository.reset();

      expect(seen.url.path, '/reset');
      expect(reading.start, DateTime.utc(2026, 10, 10, 16, 30));
    });

    test('fails on a status other than 200', () {
      final repository = build(
        MockClient((_) async => http.Response('nope', 400)),
      );

      expect(
        () => repository.moveTo(DateTime.utc(2026, 10, 10, 17)),
        throwsA(
          isA<ScenarioRequestFailed>().having(
            (e) => e.toString(),
            'message',
            'ScenarioRequestFailed: Status 400.',
          ),
        ),
      );
    });
  });
}
