import 'package:equatable/equatable.dart';
import 'package:home_api_client/home_api_client.dart';

/// {@template scenario_reading}
/// Where the demo's scenario stands: the time on the backend's clock and the
/// span it can run over.
/// {@endtemplate}
class ScenarioReading extends Equatable {
  /// {@macro scenario_reading}
  const ScenarioReading({
    required this.now,
    required this.start,
    required this.end,
  });

  /// {@macro scenario_reading}
  ///
  /// Reads the reading from the JSON the backend sent.
  factory ScenarioReading.fromJson(Map<String, dynamic> json) =>
      ScenarioReading(
        now: parseWallTime(json['now'] as String),
        start: parseWallTime(json['start'] as String),
        end: parseWallTime(json['end'] as String),
      );

  /// The scenario time.
  final DateTime now;

  /// Where the scenario starts, and where a reset returns to.
  final DateTime start;

  /// The last moment the scenario can show.
  final DateTime end;

  @override
  List<Object?> get props => [now, start, end];
}

/// Reads a naive local time such as `2026-10-10T16:30:00` as a wall time.
///
/// It is held as UTC so that arithmetic on it never meets the daylight saving
/// change of whoever's machine this runs on. Only its fields mean anything.
DateTime parseWallTime(String iso) =>
    DateTime.parse(iso.endsWith('Z') ? iso : '${iso}Z');

/// Formats a wall time for the backend, to the second and with no zone.
String formatWallTime(DateTime time) =>
    time.toUtc().toIso8601String().substring(0, 19);

/// {@template scenario_repository}
/// The backend's scenario: a clock that only moves when told to, and a reset.
///
/// {@macro repository_seam}
/// {@endtemplate}
abstract interface class ScenarioRepository {
  /// Moves the backend's clock to [time] and brings everything that follows
  /// from the time up to date. The backend holds the clock within the scenario,
  /// so the reading says where it ended up.
  Future<ScenarioReading> moveTo(DateTime time);

  /// Restores the backend's data and clock to the first state.
  Future<ScenarioReading> reset();
}

/// {@template scenario_request_failed}
/// The backend did not answer a scenario request with a 200.
/// {@endtemplate}
class ScenarioRequestFailed implements Exception {
  /// {@macro scenario_request_failed}
  const ScenarioRequestFailed(this.message);

  /// What went wrong, with the status the backend answered.
  final String message;

  @override
  String toString() => 'ScenarioRequestFailed: $message';
}

/// {@template http_scenario_repository}
/// Talks to the backend's clock and reset in this visitor's own world, over
/// `client`.
/// {@endtemplate}
class HttpScenarioRepository implements ScenarioRepository {
  /// {@macro http_scenario_repository}
  HttpScenarioRepository({required this._client});

  final HomeApiClient _client;

  @override
  Future<ScenarioReading> moveTo(DateTime time) =>
      _read(() => _client.moveClock(formatWallTime(time)));

  @override
  Future<ScenarioReading> reset() => _read(_client.reset);

  Future<ScenarioReading> _read(
    Future<Map<String, dynamic>> Function() call,
  ) async {
    try {
      return ScenarioReading.fromJson(await call());
    } on HomeApiException catch (e) {
      throw ScenarioRequestFailed('Status ${e.statusCode}.');
    }
  }
}
