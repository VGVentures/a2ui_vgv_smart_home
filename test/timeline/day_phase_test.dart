import 'package:a2ui_vgv_smart_home/timeline/day_phase.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(DayPhase, () {
    DateTime at(int hour, [int minute = 0]) =>
        DateTime.utc(2026, 10, 10, hour, minute);

    test('has the four parts of the day, and no night', () {
      expect(DayPhase.values, [
        DayPhase.morning,
        DayPhase.day,
        DayPhase.sunset,
        DayPhase.evening,
      ]);
    });

    test('has a kitchen in its own light', () {
      expect(DayPhase.values.map((phase) => phase.light), [
        KitchenLight.morning,
        KitchenLight.day,
        KitchenLight.sunset,
        KitchenLight.evening,
      ]);
    });

    test('goes to the moment the design shows it at', () {
      final date = at(3, 15);

      expect(DayPhase.morning.on(date), at(7, 30));
      expect(DayPhase.day.on(date), at(16, 30));
      expect(DayPhase.sunset.on(date), at(17, 40));
      expect(DayPhase.evening.on(date), at(20, 40));
    });

    test('knows the phase of the moment it goes to', () {
      for (final phase in DayPhase.values) {
        expect(DayPhase.at(phase.on(at(0))), phase);
      }
    });

    test('changes phase on the hour or the half hour it starts', () {
      expect(DayPhase.at(at(0)), DayPhase.morning);
      expect(DayPhase.at(at(10, 59)), DayPhase.morning);
      expect(DayPhase.at(at(11)), DayPhase.day);
      expect(DayPhase.at(at(17, 29)), DayPhase.day);
      expect(DayPhase.at(at(17, 30)), DayPhase.sunset);
      expect(DayPhase.at(at(19, 59)), DayPhase.sunset);
      expect(DayPhase.at(at(20)), DayPhase.evening);
    });

    test('keeps the evening until the day is over', () {
      expect(DayPhase.at(at(23, 59)), DayPhase.evening);
    });
  });
}
