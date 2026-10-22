import 'package:a2ui_vgv_smart_home/clock/view/clock_view.dart';
import 'package:a2ui_vgv_smart_home/timeline/cubit/timeline_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_scenario_repository.dart';

void main() {
  group(ClockView, () {
    testWidgets('shows the scenario time, period and date', (tester) async {
      final cubit = TimelineCubit(
        repository: FakeScenarioRepository(),
        live: FakeLiveRepository(),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cubit, child: const ClockView()),
        ),
      );

      expect(find.text('7:30'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('Sat, Oct 10'), findsOneWidget);
    });

    testWidgets('follows the time as it moves', (tester) async {
      final cubit = TimelineCubit(
        repository: FakeScenarioRepository(),
        live: FakeLiveRepository(),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(value: cubit, child: const ClockView()),
        ),
      );

      cubit.emit(cubit.state.copyWith(now: DateTime.utc(2026, 10, 10, 17, 45)));
      await tester.pump();

      expect(find.text('5:45'), findsOneWidget);
    });
  });
}
