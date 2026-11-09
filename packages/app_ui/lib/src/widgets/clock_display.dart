import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// {@template clock_display}
/// The big time with its period and date beside it.
///
/// Takes the text already formatted, so the locale stays the app's concern.
/// {@endtemplate}
class ClockDisplay extends StatelessWidget {
  /// {@macro clock_display}
  const ClockDisplay({
    required this.time,
    required this.period,
    required this.date,
    super.key,
  });

  /// For example `4:30`.
  final String time;

  /// For example `PM`.
  final String period;

  /// For example `Sat, Oct 3`.
  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 14,
      children: [
        Text(
          time,
          style: AppTypography.displayMedium,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              period,
              style: AppTypography.titleSmall,
            ),
            Text(
              date,
              style: AppTypography.labelMedium.copyWith(color: AppColors.ink2),
            ),
          ],
        ),
      ],
    );
  }
}
