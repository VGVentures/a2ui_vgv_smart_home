import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_icons.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_tone.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:app_ui/src/theme/icon_from_words.dart';
import 'package:app_ui/src/widgets/app_card.dart';
import 'package:app_ui/src/widgets/status_tag.dart';
import 'package:flutter/material.dart';

/// {@template plan_density}
/// How much room a [PlanTimeline] has.
/// {@endtemplate}
enum PlanDensity {
  /// Icon bubbles, a date line and up to four rows. A fifth entry draws the
  /// rows tighter, see [PlanTimeline].
  detailed(maxEntries: 4),

  /// Times and titles only, up to three rows.
  compact(maxEntries: 3);

  /// {@macro plan_density}
  const PlanDensity({required this.maxEntries});

  /// The most rows shown.
  final int maxEntries;

  /// The density the catalog calls [name]; unknown names read as [detailed].
  static PlanDensity byName(String? name) =>
      name == 'compact' ? compact : detailed;
}

/// {@template plan_entry_status}
/// What happened to an entry when the plan changed.
/// {@endtemplate}
enum PlanEntryStatus {
  /// The entry kept its time.
  unchanged,

  /// The entry moved to another time.
  moved,

  /// The entry was added by the change.
  isNew;

  /// The status the catalog calls [name], or null.
  static PlanEntryStatus? byName(String? name) => switch (name) {
    'unchanged' => unchanged,
    'moved' => moved,
    'new' => isNew,
    _ => null,
  };
}

/// {@template plan_entry}
/// One event on a [PlanTimeline].
/// {@endtemplate}
class PlanEntry {
  /// {@macro plan_entry}
  const PlanEntry({
    required this.time,
    required this.title,
    this.detail,
    this.icon,
    this.previousTime,
    this.changedBy,
    this.status,
  });

  /// Display time, e.g. "6:00 PM".
  final String time;

  /// The event name, for example `Guests arrive`.
  final String title;

  /// A line under the [title], for example the room.
  final String? detail;

  /// An icon name from [AppIcons]. Detailed density only.
  final String? icon;

  /// The time before the plan changed, shown as "was 6:00".
  final String? previousTime;

  /// Who moved the entry.
  final String? changedBy;

  /// What happened to the entry when the plan changed, or null when it did not.
  final PlanEntryStatus? status;
}

/// {@template plan_timeline}
/// An ordered list of events for the day.
///
/// A cell tall enough for the icon bubbles draws the stacked layout whatever
/// the [density] says, and an entry with no icon gets one from its title. A
/// shorter cell draws the compact rows. Either way the header stays on top and
/// the rows spread over all the height left, so the card has no empty bottom.
/// {@endtemplate}
class PlanTimeline extends StatelessWidget {
  /// {@macro plan_timeline}
  const PlanTimeline({
    required this.entries,
    this.title,
    this.subtitle,
    this.density = PlanDensity.detailed,
    this.tag,
    super.key,
  });

  /// The card heading.
  final String? title;

  /// The date line. Stacked layout only.
  final String? subtitle;

  /// What an unbounded cell draws. A bounded cell picks by its height.
  final PlanDensity density;

  /// Says the plan changed.
  final StatusTag? tag;

  /// The events of the day, in order.
  final List<PlanEntry> entries;

  /// The height from which the stacked layout, with its icon bubbles, fits
  /// three rows.
  static const double _stackedMinHeight = 424;

  static const double _verticalPadding = 2 * AppSpacing.cardPaddingCompact;

  /// The gap between the header and the first row, at least.
  static const double _stackedHeaderGap = AppSpacing.s4;
  static const double _compactHeaderGap = 14;

  static const double _stackedRow = 90;
  static const double _stackedRowGap = AppSpacing.s4;
  static const double _compactRow = 44;
  static const double _compactRowGap = AppSpacing.s2;

  static const double _titleHeight = 29;
  static const double _subtitleHeight = 20;

  /// How many rows of [row] with [gap] fit under [header] in [height].
  static int _rowsThatFit(
    double height, {
    required double header,
    required double headerGap,
    required double row,
    required double gap,
  }) {
    final room = height - _verticalPadding - header - headerGap;
    return ((room + gap) / (row + gap)).floor();
  }

  double _headerHeight({required bool stacked}) {
    if (title == null && tag == null && !(stacked && subtitle != null)) {
      return 0;
    }
    final titles =
        (title == null ? 0.0 : _titleHeight) +
        (stacked && subtitle != null ? _subtitleHeight : 0.0);
    return titles > AppSpacing.chipHeight || tag == null
        ? titles
        : AppSpacing.chipHeight;
  }

  @override
  Widget build(BuildContext context) {
    // Inside a horizontal parent (e.g. a model-generated Row without weights)
    // the width is unbounded and the Expanded children would fail to lay out.
    return LayoutBuilder(
      builder: (context, constraints) {
        final card = _card(constraints);
        return constraints.hasBoundedWidth
            ? card
            : SizedBox(width: _unboundedWidth, child: card);
      },
    );
  }

  Widget _card(BoxConstraints constraints) {
    final bounded = constraints.hasBoundedHeight;
    final height = bounded ? constraints.maxHeight : double.infinity;
    final stacked = bounded
        ? height >= _stackedMinHeight
        : density == PlanDensity.detailed;
    final header = _headerHeight(stacked: stacked);
    final headerGap = header == 0
        ? 0.0
        : stacked
        ? _stackedHeaderGap
        : _compactHeaderGap;
    final limit = stacked ? PlanDensity.detailed : PlanDensity.compact;
    final fit = bounded
        ? _rowsThatFit(
            height,
            header: header,
            headerGap: headerGap,
            row: stacked ? _stackedRow : _compactRow,
            gap: stacked ? _stackedRowGap : _compactRowGap,
          ).clamp(1, limit.maxEntries)
        : limit.maxEntries;
    final shown = entries.take(fit).toList();
    final changed = entries.any((entry) => entry.changedBy != null);
    final rows = [
      for (final entry in shown)
        if (stacked)
          _StackedRow(entry: entry)
        else
          _CompactRow(entry: entry, timeWidth: changed ? 104 : 100),
    ];
    final rowGap = stacked ? _stackedRowGap : _compactRowGap;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (header > 0) ...[
            _Header(
              title: title,
              subtitle: stacked ? subtitle : null,
              tag: tag,
            ),
            SizedBox(height: headerGap),
          ],
          if (bounded)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: rows,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: rowGap),
              rows[i],
            ],
        ],
      ),
    );
  }
}

const double _unboundedWidth = 360;

/// The plan timeline's header: its title, subtitle and tag.
class _Header extends StatelessWidget {
  const _Header({this.title, this.subtitle, this.tag});

  final String? title;
  final String? subtitle;
  final StatusTag? tag;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final subtitle = this.subtitle;
    final tag = this.tag;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall,
                ),
              if (subtitle != null) Text(subtitle, style: AppTypography.label),
            ],
          ),
        ),
        if (tag != null) ...[const SizedBox(width: AppSpacing.s3), tag],
      ],
    );
  }
}

/// The second line of a row: what changed, or the detail.
class _Sub extends StatelessWidget {
  const _Sub({required this.entry});

  final PlanEntry entry;

  @override
  Widget build(BuildContext context) {
    final previous = entry.previousTime;
    final changedBy = entry.changedBy;
    final detail = entry.detail;
    if (previous != null || changedBy != null) {
      final text = [
        if (previous != null) 'was $previous',
        ?changedBy,
      ].join(' · ');
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // Who moved it reads in the climate ink, a bare move in the lighting.
        style: AppTypography.bodyMedium.copyWith(
          color: changedBy == null ? AppTone.lighting.ink : AppTone.climate.ink,
        ),
      );
    }
    final text = entry.status == PlanEntryStatus.unchanged
        ? 'Unchanged'
        : detail;
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.label,
    );
  }
}

/// A time with a small trailing `AM` or `PM` on its baseline.
class _Time extends StatelessWidget {
  const _Time({required this.time, required this.style, required this.gap});

  final String time;
  final TextStyle style;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final match = RegExp(
      r'^(.*?)\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(time.trim());
    if (match == null) {
      return Text(time, maxLines: 1, style: style);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(match.group(1)!, maxLines: 1, style: style),
        SizedBox(width: gap),
        Text(
          match.group(2)!.toUpperCase(),
          style: AppTypography.labelMedium.copyWith(color: AppColors.ink2),
        ),
      ],
    );
  }
}

/// The tone an icon belongs to, which tints its bubble.
AppTone _tone(String icon) => switch (icon) {
  'oven' ||
  'flame' ||
  'light' ||
  'blinds' ||
  'scene' ||
  'restaurant' ||
  'wine' => AppTone.lighting,
  'cake' || 'car' || 'charger' || 'meter' || 'savings' => AppTone.energy,
  'thermostat' || 'snowflake' || 'guests' => AppTone.climate,
  'lock' || 'garage' || 'doorbell' => AppTone.security,
  'rain' => AppTone.weather,
  _ => AppTone.neutral,
};

/// A row of the stacked layout: an icon bubble, the time, the title and the
/// second line.
class _StackedRow extends StatelessWidget {
  const _StackedRow({required this.entry});

  final PlanEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon =
        entry.icon ?? iconFromWords('${entry.title} ${entry.detail ?? ''}');
    final tone = _tone(icon);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppSpacing.iconBubble,
          height: AppSpacing.iconBubble,
          decoration: BoxDecoration(
            color: tone.wash ?? AppColors.fillWarm,
            shape: BoxShape.circle,
          ),
          child: Icon(AppIcons.byName(icon), size: 26, color: tone.ink),
        ),
        const SizedBox(width: AppSpacing.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Time(
                time: entry.time,
                style: AppTypography.headlineMedium,
                gap: 6,
              ),
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body,
              ),
              _Sub(entry: entry),
            ],
          ),
        ),
      ],
    );
  }
}

/// A row of the compact layout: the time beside the title and second line.
class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.entry, required this.timeWidth});

  final PlanEntry entry;
  final double timeWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: timeWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _Time(
              time: entry.time,
              style: AppTypography.ui(
                size: 32,
                lineHeight: 43,
                weight: FontWeight.w300,
                letterSpacing: -0.96,
              ),
              gap: AppSpacing.s1,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body,
              ),
              _Sub(entry: entry),
            ],
          ),
        ),
      ],
    );
  }
}
