import 'package:home_backend/data/mock_database.dart';
import 'package:home_timeline/home_timeline.dart';

/// {@template oven_service}
/// The mocked oven programme: when it preheats and when the roast goes in.
/// {@endtemplate}
///
/// It only writes the schedule. What the oven is doing at a given time, and its
/// temperature, follow from the schedule and the clock; see `ScenarioEngine`.
class OvenService {
  /// {@macro oven_service}
  ///
  /// Creates an oven service over the mock database.
  OvenService(this._database);

  static final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  final MockDatabase _database;

  Map<String, dynamic> get _traits {
    final oven = _database.deviceOrNull('oven');
    if (oven == null) throw const MockDataNotFound('There is no oven.');
    return oven['traits'] as Map<String, dynamic>;
  }

  /// Sets when the oven preheats and when the roast goes in, as `HH:mm`. A
  /// value left `null` stays as it is.
  ///
  /// The oven keeps the preheat time it had in `previousPreheatStart`, so a
  /// screen can say what changed. Throws [MockDataNotFound] for a time that is
  /// not `HH:mm`.
  Map<String, Object?> schedule({String? preheatStart, String? roastIn}) {
    for (final time in [preheatStart, roastIn]) {
      if (time != null && !_hhmm.hasMatch(time)) {
        throw MockDataNotFound('"$time" is not a time. Use HH:mm, 24 hour.');
      }
    }
    final control = _traits['TemperatureControl'] as Map<String, dynamic>;
    final cook = _traits['CookSchedule'] as Map<String, dynamic>;
    final was = control['scheduledStart'] as String?;
    if (preheatStart != null && preheatStart != was) {
      cook['previousPreheatStart'] = was;
      control['scheduledStart'] = preheatStart;
    }
    if (roastIn != null) cook['roastInAt'] = roastIn;
    return {
      'service': 'oven',
      'action': 'schedule',
      'preheatStart': control['scheduledStart'],
      'previousPreheatStart': cook['previousPreheatStart'],
      'roastInAt': cook['roastInAt'],
      'confirmed': true,
    };
  }

  /// Moves the whole programme by [by].
  Map<String, Object?> shift(Duration by) {
    final control = _traits['TemperatureControl'] as Map<String, dynamic>;
    final cook = _traits['CookSchedule'] as Map<String, dynamic>;
    final day = _database.clock.now;
    String? moved(Object? time) =>
        time == null ? null : hhmm(atHhmm(day, time as String).add(by));
    return schedule(
      preheatStart: moved(control['scheduledStart']),
      roastIn: moved(cook['roastInAt']),
    );
  }
}
