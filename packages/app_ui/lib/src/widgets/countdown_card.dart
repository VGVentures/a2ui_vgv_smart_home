import 'dart:async';

import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_tone.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:app_ui/src/widgets/app_card.dart';
import 'package:app_ui/src/widgets/now_scope.dart';
import 'package:app_ui/src/widgets/status_tag.dart';
import 'package:flutter/material.dart';

/// The countdown text from [now] to [startsAt]: "2h 30m", "45m", "Now" or
/// "Started".
///
/// Pure: the same two instants always give the same text. Minutes are counted
/// between the minutes the instants fall in, so the text agrees with a clock
/// that shows hours and minutes. Within the last minute it reads
/// [nowLabel]; after [startsAt] it reads [startedLabel].
String formatCountdown(
  DateTime startsAt,
  DateTime now, {
  String nowLabel = 'Now',
  String startedLabel = 'Started',
}) {
  final remaining = startsAt.difference(now);
  final start = startsAt.toLocal();
  if (remaining.isNegative) return startedLabel;
  if (remaining < const Duration(minutes: 1)) return nowLabel;
  final minutes = _minute(start).difference(_minute(now.toLocal())).inMinutes;
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return hours > 0 ? '${hours}h ${rest}m' : '${rest}m';
}

DateTime _minute(DateTime time) =>
    DateTime(time.year, time.month, time.day, time.hour, time.minute);

/// {@template countdown_card}
/// One upcoming event with a big countdown, e.g. "Guests in 2h 30m".
///
/// The agent sends only [startsAt]; this widget owns the math and re-renders
/// itself once per minute, aligned to the minute boundary.
/// {@endtemplate}
class CountdownCard extends StatefulWidget {
  /// {@macro countdown_card}
  const CountdownCard({
    required this.startsAt,
    this.tag,
    this.eyebrow,
    this.subtitle,
    this.tone = AppTone.lighting,
    this.now,
    this.nowLabel = 'Now',
    this.startedLabel = 'Started',
    super.key,
  });

  /// When the event starts.
  final DateTime startsAt;

  /// The chip above the countdown.
  final StatusTag? tag;

  /// The line above the countdown, e.g. "Guests in".
  final String? eyebrow;

  /// The footer, e.g. "Dinner at 7:00 PM · Dining Room".
  final String? subtitle;

  /// The card color.
  final AppTone tone;

  /// The time source. Defaults to the nearest [NowScope], then the device
  /// clock.
  final DateTime Function()? now;

  /// The countdown text within the last minute.
  final String nowLabel;

  /// The countdown text once the event has started.
  final String startedLabel;

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

/// Ticks the countdown from the card's clock.
class _CountdownCardState extends State<CountdownCard> {
  Timer? _timer;
  late DateTime Function() _now;

  DateTime Function() _resolveNow() =>
      widget.now ?? NowScope.maybeOf(context) ?? DateTime.now;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _now = _resolveNow();
    _schedule();
  }

  @override
  void didUpdateWidget(CountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _now = _resolveNow();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    final now = _now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(nextMinute.difference(now), _tick);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    _schedule();
  }

  /// The tag drawn in the ink of the card's tone (brown on a lighting card),
  /// unless it names an ink of its own.
  StatusTag _toned(StatusTag tag) => StatusTag(
    label: tag.label,
    kind: tag.kind,
    icon: tag.icon,
    dot: tag.dot,
    tint: tag.tint ?? widget.tone.wash,
    ink: tag.ink == AppColors.ink ? widget.tone.ink : tag.ink,
  );

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;
    final countdown = formatCountdown(
      widget.startsAt,
      _now(),
      nowLabel: widget.nowLabel,
      startedLabel: widget.startedLabel,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedWidth;
        final width = bounded
            ? constraints.maxWidth - 2 * AppSpacing.cardPadding
            : _unboundedWidth - 2 * AppSpacing.cardPadding;
        final text = _text(countdown, width);
        final card = AppCard(
          outlined: true,
          tone: widget.tone,
          child: constraints.hasBoundedHeight
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ?(tag == null ? null : _toned(tag)),
                    // The text is the last thing to give: in a cell too short
                    // for it, it scales down rather than overflows.
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: tag == null ? 0 : AppSpacing.cardContentGap,
                        ),
                        child: Align(
                          alignment: tag == null
                              ? Alignment.centerLeft
                              : Alignment.bottomLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomLeft,
                            child: text,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tag != null) ...[
                      _toned(tag),
                      const SizedBox(height: AppSpacing.s4),
                    ],
                    text,
                  ],
                ),
        );
        // Inside a horizontal parent the width is unbounded.
        return bounded ? card : SizedBox(width: _unboundedWidth, child: card);
      },
    );
  }

  /// The eyebrow, the countdown and the footer, [width] wide.
  Widget _text(String countdown, double width) {
    final eyebrow = widget.eyebrow;
    final subtitle = widget.subtitle;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.s1,
        children: [
          if (eyebrow != null)
            Text(
              eyebrow,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleSmall.copyWith(color: AppColors.ink2),
            ),
          Semantics(
            liveRegion: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                countdown,
                maxLines: 1,
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.ink),
            ),
        ],
      ),
    );
  }
}

const double _unboundedWidth = 446;
