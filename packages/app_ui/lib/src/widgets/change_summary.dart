import 'dart:ui' show ImageFilter;

import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_icons.dart';
import 'package:app_ui/src/theme/app_shadows.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_tone.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// {@template change_tile_data}
/// One tile of a [ChangeSummary]: what changed and its new value.
/// {@endtemplate}
class ChangeTileData {
  /// {@macro change_tile_data}
  const ChangeTileData({
    required this.label,
    required this.value,
    this.icon,
    this.previous,
    this.note,
  });

  /// "Oven preheat".
  final String label;

  /// The new value: "7:00 PM".
  final String value;

  /// {@macro app_icon_name}
  final String? icon;

  /// The old value line: "was 6:00 PM".
  final String? previous;

  /// A small line used when there is no [previous]: "Sent 5:41 PM".
  final String? note;
}

/// {@template change_summary}
/// Confirms what the agent changed after a request.
/// {@endtemplate}
class ChangeSummary extends StatelessWidget {
  /// {@macro change_summary}
  const ChangeSummary({
    required this.title,
    required this.changes,
    this.eyebrow,
    this.tone = AppTone.lighting,
    super.key,
  });

  /// The headline: "Dinner moved to 8:00 PM".
  final String title;

  /// The tiles, one per change.
  final List<ChangeTileData> changes;

  /// The line above the headline: "Done · from your request at 5:40 PM".
  final String? eyebrow;

  /// The color of the card's border, glow and icon bubble.
  final AppTone tone;

  /// The narrowest a tile gets before one fewer is shown.
  static const double _tileWidth = 138;

  static const int _maxTiles = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        if (!constraints.hasBoundedWidth) return _card(_maxTiles, bounded);
        const gap = AppSpacing.s3;
        final inner = constraints.maxWidth - 2 * AppSpacing.cardPadding;
        final fitting = ((inner + gap) / (_tileWidth + gap)).floor();
        return _card(fitting.clamp(1, _maxTiles), bounded);
      },
    );
  }

  Widget _card(int tiles, bool bounded) {
    final eyebrow = this.eyebrow;
    final shown = changes.take(tiles).toList();
    final radius = BorderRadius.circular(AppSpacing.cardRadius);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: _ChangeTile(shown[i], tone: tone, spread: bounded),
          ),
        ],
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: radius,
        boxShadow: AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: tone.accent.withValues(alpha: 0.45)),
          ),
          child: Stack(
            children: [
              // The ambient glow: a soft disc behind the top left corner.
              Positioned(
                left: -121,
                top: -161,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                  child: Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      color: tone.wash,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: AppSpacing.iconBubble,
                          height: AppSpacing.iconBubble,
                          decoration: BoxDecoration(
                            color: tone.wash,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.byName('sparkle'),
                            size: 26,
                            color: tone.ink,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (eyebrow != null)
                                Text(
                                  eyebrow,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label,
                                ),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleLarge,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    if (bounded)
                      Expanded(child: row)
                    else
                      IntrinsicHeight(child: row),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One changed value of the change summary.
class _ChangeTile extends StatelessWidget {
  const _ChangeTile(this.data, {required this.tone, required this.spread});

  final ChangeTileData data;
  final AppTone tone;

  /// Whether the tile has a height to spread its label and value over.
  final bool spread;

  /// The icons that read as an action on a person, in the accent color.
  static const _actions = {'send', 'chat', 'share', 'undo', 'bell'};

  @override
  Widget build(BuildContext context) {
    final icon = data.icon;
    final detail = data.previous ?? data.note;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.fillWarm,
        borderRadius: BorderRadius.circular(AppSpacing.innerPanelRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s5,
          vertical: AppSpacing.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: spread ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    AppIcons.byName(icon),
                    size: 20,
                    color: _actions.contains(icon)
                        ? AppColors.accent
                        : tone.ink,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                ],
                Flexible(
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label,
                  ),
                ),
              ],
            ),
            if (spread)
              const Spacer()
            else
              const SizedBox(height: AppSpacing.s2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                maxLines: 1,
                style: AppTypography.headlineSmall,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
