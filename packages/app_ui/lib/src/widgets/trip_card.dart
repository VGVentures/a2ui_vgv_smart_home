import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_icons.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:app_ui/src/theme/icon_from_words.dart';
import 'package:app_ui/src/widgets/card_icon_bubble.dart';
import 'package:app_ui/src/widgets/glow_surface.dart';
import 'package:app_ui/src/widgets/status_tag.dart';
import 'package:flutter/material.dart';

/// {@template trip_stop_emphasis}
/// How a [TripStop] reads.
/// {@endtemplate}
enum TripStopEmphasis {
  /// A plain stop.
  none,

  /// A stop with slack, drawn in green.
  good;

  /// The emphasis the catalog calls [name]; unknown names read as [none].
  static TripStopEmphasis byName(String? name) => name == 'good' ? good : none;
}

/// {@template trip_footer_tone}
/// How the footer line of a [TripCard] reads.
/// {@endtemplate}
enum TripFooterTone {
  /// The usual grey line.
  normal,

  /// A traffic warning, in warm brown.
  warning;

  /// The tone the catalog calls [name]; unknown names read as [normal].
  static TripFooterTone byName(String? name) =>
      name == 'warning' ? warning : normal;
}

/// {@template trip_footer}
/// The line under the hero time of a [TripCard].
/// {@endtemplate}
class TripFooter {
  /// {@macro trip_footer}
  const TripFooter({
    required this.text,
    this.icon = 'car',
    this.tone = TripFooterTone.normal,
  });

  /// The footer text, for example `Leave by 5:15 to beat traffic`.
  final String text;

  /// {@macro app_icon_name}
  final String icon;

  /// How the footer line reads.
  final TripFooterTone tone;
}

/// {@template trip_progress}
/// How far along an en route [TripCard] is: a track with an icon on it.
/// {@endtemplate}
class TripProgress {
  /// {@macro trip_progress}
  const TripProgress({required this.percent, this.icon = 'trip'});

  /// 0 to 100, held within that range when drawn.
  final int percent;

  /// {@macro app_icon_name}
  final String icon;
}

/// {@template trip_stop}
/// One stop on a [TripCard].
/// {@endtemplate}
class TripStop {
  /// {@macro trip_stop}
  const TripStop({
    required this.title,
    required this.time,
    this.subtitle,
    this.icon,
    this.emphasis = TripStopEmphasis.none,
  });

  /// The stop name, for example `Bakery`.
  final String title;

  /// The display time of the stop, for example `5:30 PM`.
  final String time;

  /// A line under the [title], for example the address.
  final String? subtitle;

  /// {@macro app_icon_name}
  final String? icon;

  /// How the stop reads.
  final TripStopEmphasis emphasis;
}

/// {@template trip_card}
/// Where to be and when to leave: a hero leave-by time and the stops.
///
/// The hero, its footer and the stops spread over the card's height, so no
/// space is left empty at the bottom.
/// {@endtemplate}
class TripCard extends StatelessWidget {
  /// {@macro trip_card}
  const TripCard({
    required this.leaveBy,
    this.label = 'Leave by',
    this.previousLeaveBy,
    this.footer,
    this.progress,
    this.tag,
    this.tagKind = StatusTagKind.info,
    this.tagIcon,
    this.stops = const [],
    super.key,
  });

  /// The text above the hero time.
  final String label;

  /// The hero time to leave by, for example `5:15 PM`.
  final String leaveBy;

  /// The time before the change. Draws the highlight and the `was` line, which
  /// an en route card leaves out.
  final String? previousLeaveBy;

  /// The line under the hero time.
  final TripFooter? footer;

  /// When set, the card is en route: a track with a marker at the progress.
  final TripProgress? progress;

  /// {@macro card_tag_text}
  final String? tag;

  /// How the corner tag reads.
  final StatusTagKind tagKind;

  /// An icon name from `AppIcons` for the corner tag; defaults from
  /// [tagKind].
  final String? tagIcon;

  /// Up to three stops are shown, fewer in a narrow cell and when en route.
  final List<TripStop> stops;

  /// Below this width the stops no longer fit next to the hero, so the card
  /// shows the hero alone.
  static const double _heroOnlyWidth = 480;

  /// Below this width only two stops fit.
  static const double _threeStopsWidth = 600;

  /// `custom/energy/energy-outline`, the border of a card that just changed.
  static const Color _updatedOutline = Color(0x59025002);

  /// The corner pill: a dot for a change, the icon when the agent names one.
  Widget _tagPill(String label) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      border: Border.all(color: AppColors.line),
    ),
    child: StatusTag(
      label: label,
      kind: tagKind,
      icon: tagIcon,
      tint: AppColors.surfaceRaised,
      dot: tagKind == StatusTagKind.updated && tagIcon == null
          ? AppColors.ink
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tag = this.tag;
    final progress = this.progress;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : double.infinity;
        final bounded = constraints.hasBoundedHeight;
        // The track takes the room of a stop: an en route card shows where it
        // is going, and where it left when there is room.
        final shownStops = width < _heroOnlyWidth
            ? 0
            : progress != null
            ? (width < _threeStopsWidth ? 1 : 2)
            : (width < _threeStopsWidth ? 2 : 3);
        final shown = progress != null && shownStops < stops.length
            ? stops.sublist(stops.length - shownStops)
            : stops.take(shownStops).toList();
        // A card with a tag carries the label in a header, as the design's
        // updated card does, and draws the stops smaller to leave it room.
        final compact = tag != null;
        final hero = _Hero(
          label: compact ? null : label,
          leaveBy: leaveBy,
          previous: progress == null ? previousLeaveBy : null,
          footer: footer,
          bounded: bounded,
        );
        final body = shownStops == 0
            ? hero
            : Row(
                crossAxisAlignment: bounded
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 240, child: hero),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    flex: 298,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: bounded
                          ? MainAxisSize.max
                          : MainAxisSize.min,
                      children: [
                        for (final stop in shown)
                          Padding(
                            padding: EdgeInsets.only(
                              top: bounded ? 0 : AppSpacing.s3,
                            ),
                            child: _Stop(stop, compact: compact),
                          ),
                      ],
                    ),
                  ),
                ],
              );
        final children = [
          if (compact) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.ink2,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: _tagPill(tag),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
          if (bounded) Expanded(child: body) else body,
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.s3),
            _RouteTrack(progress),
          ],
        ];
        return GlowSurface(
          border: BorderSide(
            color: tagKind == StatusTagKind.updated && compact
                ? _updatedOutline
                : AppColors.line,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: children,
          ),
        );
      },
    );
  }
}

/// The en route track: the part behind the marker is filled.
class _RouteTrack extends StatelessWidget {
  const _RouteTrack(this.progress);

  final TripProgress progress;

  static const double _marker = 28;
  static const double _bar = 6;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.percent.clamp(0, 100) / 100;
    return SizedBox(
      height: _marker,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = constraints.maxWidth - _marker;
          final left = travel * fraction;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: _bar,
                decoration: BoxDecoration(
                  color: AppColors.fillWarm,
                  borderRadius: BorderRadius.circular(_bar),
                ),
              ),
              Container(
                width: left + _marker / 2,
                height: _bar,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(_bar),
                ),
              ),
              Positioned(
                left: left,
                child: CardIconBubble(
                  size: _marker,
                  icon: AppIcons.byName(progress.icon),
                  background: AppColors.ink,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The big top part of the trip card: the label and when to leave by.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.label,
    required this.leaveBy,
    required this.previous,
    required this.footer,
    required this.bounded,
  });

  final String? label;
  final String leaveBy;
  final String? previous;
  final TripFooter? footer;
  final bool bounded;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final previous = this.previous;
    final footer = this.footer;
    final (digits, suffix) = splitMeridiem(leaveBy);
    final highlighted = previous != null;
    final time = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (highlighted)
              Positioned.fill(
                left: -10,
                right: -10,
                top: -2,
                bottom: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.brandYellow100.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            Text(
              digits,
              maxLines: 1,
              style: AppTypography.displayLarge.copyWith(
                height: highlighted ? 84 / 88 : null,
              ),
            ),
          ],
        ),
        if (suffix.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.s2),
          Text(suffix, style: AppTypography.titleSmall),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // The time scales down when the cell leaves it less room than it
        // needs, so the footer under it is never pushed out of the card.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null)
                  Text(
                    label,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.ink2,
                    ),
                  ),
                time,
                if (previous != null)
                  Text('was $previous', style: AppTypography.label),
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.only(top: bounded ? 0 : AppSpacing.s3),
            child: _FooterLine(footer),
          ),
      ],
    );
  }
}

/// The trip card's footer line, in the warning color when it warns.
class _FooterLine extends StatelessWidget {
  const _FooterLine(this.footer);

  final TripFooter footer;

  @override
  Widget build(BuildContext context) {
    final warning = footer.tone == TripFooterTone.warning;
    final color = warning ? AppColors.brandOrange300 : AppColors.ink;
    return Row(
      crossAxisAlignment: warning
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(AppIcons.byName(footer.icon), size: 22, color: color),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Text(
            footer.text,
            style:
                (warning ? AppTypography.labelMedium : AppTypography.bodyMedium)
                    .copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// A time with its `AM`/`PM` suffix drawn small.
class _StopTime extends StatelessWidget {
  const _StopTime(this.time);

  final String time;

  @override
  Widget build(BuildContext context) {
    final (digits, suffix) = splitMeridiem(time);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          digits,
          maxLines: 1,
          style: AppTypography.titleMedium.copyWith(height: 35 / 26),
        ),
        if (suffix.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.s1),
          Text(
            suffix,
            style: AppTypography.labelMedium.copyWith(color: AppColors.ink2),
          ),
        ],
      ],
    );
  }
}

/// One stop of a trip, drawn small under a header.
class _Stop extends StatelessWidget {
  const _Stop(this.stop, {required this.compact});

  final TripStop stop;

  /// Whether the stop is drawn small, under a header.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final subtitle = stop.subtitle;
    final icon = stop.icon ?? iconFromWords('${stop.title} ${subtitle ?? ''}');
    final good = stop.emphasis == TripStopEmphasis.good;
    final bubble = compact ? 40.0 : 52.0;
    return Row(
      children: [
        ...[
          Container(
            width: bubble,
            height: bubble,
            decoration: BoxDecoration(
              color: good ? AppColors.successSoft : AppColors.fillWarm,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.byName(icon),
              size: compact ? 22 : 28,
              color: good ? AppColors.success : AppColors.ink,
            ),
          ),
          SizedBox(width: compact ? AppSpacing.s3 : 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body,
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        _StopTime(stop.time),
      ],
    );
  }
}
