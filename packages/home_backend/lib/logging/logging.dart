import 'dart:io';

import 'package:logging/logging.dart';

bool _configured = false;

/// Configures application-wide logging.
///
/// Sets the root [Level] and, on the first call, attaches a single listener
/// that writes each record as a plain-text line. `SEVERE` and above go to
/// [stderr], everything else to [stdout]. Safe to call more than once: only
/// the first call attaches the listener, later calls just update the level.
void setupLogging({Level level = Level.INFO}) {
  Logger.root.level = level;
  if (_configured) return;
  _configured = true;
  Logger.root.onRecord.listen((record) {
    final line = formatLogRecord(record);
    if (record.level >= Level.SEVERE) {
      stderr.writeln(line);
    } else {
      stdout.writeln(line);
    }
  });
}

/// Formats a [LogRecord] as a single plain-text line:
/// `LEVEL timestamp [loggerName] message`, with the error and stack trace
/// appended on their own lines when present.
String formatLogRecord(LogRecord record) {
  final buffer = StringBuffer()
    ..write(record.level.name)
    ..write(' ')
    ..write(record.time.toIso8601String())
    ..write(' [')
    ..write(record.loggerName)
    ..write('] ')
    ..write(record.message);
  if (record.error != null) {
    buffer
      ..write('\n')
      ..write(record.error);
  }
  if (record.stackTrace != null) {
    buffer
      ..write('\n')
      ..write(record.stackTrace);
  }
  return buffer.toString();
}
