import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// {@template day_phase}
/// A stretch of the demo's Saturday that the timeline jumps between.
///
/// Each phase has a moment the timeline goes to when it is chosen ([hour] and
/// [minute], where the design's scenes for it happen) and the icon the design
/// gives it. The night is left out for now.
/// {@endtemplate}
enum DayPhase {
  /// Early in the day, before the kitchen gets its full light.
  morning(hour: 7, minute: 30, icon: Symbols.wb_twilight_rounded),

  /// The bright middle of the day.
  day(hour: 16, minute: 30, icon: Symbols.light_mode_rounded),

  /// The late afternoon, as the light turns warm.
  sunset(hour: 17, minute: 40, icon: Symbols.routine_rounded),

  /// After dark, with the kitchen lit from inside.
  evening(hour: 20, minute: 40, icon: Symbols.nights_stay_rounded);

  /// {@macro day_phase}
  const DayPhase({
    required this.hour,
    required this.minute,
    required this.icon,
  });

  /// The hour of the moment the timeline goes to for this phase.
  final int hour;

  /// The minute of the moment the timeline goes to for this phase.
  final int minute;

  /// The icon the design gives this phase.
  final IconData icon;

  /// The light of the kitchen behind the panel in this phase.
  KitchenLight get light => switch (this) {
    morning => KitchenLight.morning,
    day => KitchenLight.day,
    sunset => KitchenLight.sunset,
    evening => KitchenLight.evening,
  };

  /// The minutes into the day at which the day, the sunset and the evening
  /// start being the phase the time is in.
  static const int _dayStartsAt = 11 * 60;
  static const int _sunsetStartsAt = 17 * 60 + 30;
  static const int _eveningStartsAt = 20 * 60;

  /// The phase [time] falls in. A time after the evening is still the evening.
  static DayPhase at(DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    if (minutes >= _eveningStartsAt) return evening;
    if (minutes >= _sunsetStartsAt) return sunset;
    if (minutes >= _dayStartsAt) return day;
    return morning;
  }

  /// The moment this phase goes to, on the same day as [date].
  DateTime on(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day, hour, minute);
}
