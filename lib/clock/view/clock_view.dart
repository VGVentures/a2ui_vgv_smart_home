import 'package:a2ui_vgv_smart_home/timeline/cubit/timeline_cubit.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// {@template clock_view}
/// The scenario's time and date, in the locale of the app. Needs a
/// [TimelineCubit] above it.
/// {@endtemplate}
class ClockView extends StatelessWidget {
  /// {@macro clock_view}
  const ClockView({super.key});

  @override
  Widget build(BuildContext context) {
    final time = context.select<TimelineCubit, DateTime>(
      (cubit) => cubit.state.now,
    );
    final locale = Localizations.localeOf(context).toString();
    String format(String pattern) => DateFormat(pattern, locale).format(time);
    return ClockDisplay(
      time: format('h:mm'),
      period: format('a'),
      date: format('E, MMM d'),
    );
  }
}
