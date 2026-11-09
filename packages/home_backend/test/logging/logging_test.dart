import 'package:home_backend/logging/logging.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('formatLogRecord', () {
    test('includes the level, logger name, and message', () {
      final line = formatLogRecord(
        LogRecord(Level.INFO, 'server started', 'requests'),
      );
      expect(line, contains('INFO'));
      expect(line, contains('[requests]'));
      expect(line, contains('server started'));
    });

    test('appends the error and stack trace when present', () {
      final line = formatLogRecord(
        LogRecord(
          Level.SEVERE,
          'boom',
          'routes.generate',
          Exception('bad'),
          StackTrace.fromString('frame-0'),
        ),
      );
      expect(line, contains('boom'));
      expect(line, contains('Exception: bad'));
      expect(line, contains('frame-0'));
    });
  });

  group('setupLogging', () {
    test('sets the root level and can be called repeatedly', () {
      setupLogging(level: Level.WARNING);
      expect(Logger.root.level, Level.WARNING);

      setupLogging();
      expect(Logger.root.level, Level.INFO);
    });
  });
}
