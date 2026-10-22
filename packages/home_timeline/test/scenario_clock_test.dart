import 'package:home_timeline/home_timeline.dart';
import 'package:test/test.dart';

void main() {
  group('wall time', () {
    test('parses and formats a naive local time', () {
      final time = parseWall('2026-10-10T16:30:00');

      expect(time, DateTime.utc(2026, 10, 10, 16, 30));
      expect(wallIso(time), '2026-10-10T16:30:00');
      expect(parseWall('2026-10-10T16:30:00Z'), time);
    });

    test('formats HH:mm and reads it back onto a day', () {
      final time = DateTime.utc(2026, 10, 10, 7, 5);

      expect(hhmm(time), '07:05');
      expect(
        atHhmm(DateTime.utc(2026, 10, 12, 3), '18:30'),
        DateTime.utc(2026, 10, 12, 18, 30),
      );
    });

    test('formats for people', () {
      expect(clock12(DateTime.utc(2026, 10, 10, 17, 40)), '5:40 PM');
      expect(clock12(DateTime.utc(2026, 10, 10, 0, 5)), '12:05 AM');
      expect(clock12(DateTime.utc(2026, 10, 10, 12)), '12:00 PM');
      expect(clock12(DateTime.utc(2026, 10, 10, 9, 3)), '9:03 AM');
    });
  });

  group('ScenarioClock', () {
    late ScenarioClock clock;

    setUp(() => clock = ScenarioClock(DateTime.utc(2026, 10, 10, 16, 30)));

    test('starts at its start and ends at the end of that day', () {
      expect(clock.now, clock.start);
      expect(clock.nowIso, '2026-10-10T16:30:00');
      expect(clock.end, DateTime.utc(2026, 10, 10, 23, 59));
    });

    test('answers in UTC using the household offset', () {
      expect(clock.nowUtc, DateTime.utc(2026, 10, 10, 21, 30));
    });

    test('moves to a time and by a duration', () {
      clock.moveTo(DateTime.utc(2026, 10, 10, 18));
      expect(clock.nowIso, '2026-10-10T18:00:00');

      clock.moveBy(const Duration(minutes: -15));
      expect(clock.nowIso, '2026-10-10T17:45:00');
    });

    test('stays between the start and the end', () {
      expect(
        clock.moveTo(DateTime.utc(2026, 10, 10, 9)),
        DateTime.utc(2026, 10, 10, 16, 30),
      );
      expect(
        clock.moveTo(DateTime.utc(2026, 10, 11, 9)),
        DateTime.utc(2026, 10, 10, 23, 59),
      );
    });

    test('resets to the start', () {
      clock
        ..moveBy(const Duration(hours: 2))
        ..reset();

      expect(clock.now, clock.start);
    });

    test('takes its own end', () {
      final short = ScenarioClock(
        DateTime.utc(2026, 10, 10, 16),
        end: DateTime.utc(2026, 10, 10, 17),
      );

      expect(short.moveBy(const Duration(hours: 3)), short.end);
    });
  });
}
