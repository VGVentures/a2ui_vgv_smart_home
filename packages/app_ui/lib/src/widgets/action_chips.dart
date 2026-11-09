import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_icons.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_tone.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:app_ui/src/widgets/action_pill.dart';
import 'package:flutter/material.dart';

/// {@template action_chip_data}
/// One suggested next step: its label, icon and what pressing it does.
/// {@endtemplate}
class ActionChipData {
  /// {@macro action_chip_data}
  const ActionChipData({
    required this.label,
    this.icon,
    this.isPrimary = false,
    this.onPressed,
  });

  /// The chip text.
  final String label;

  /// {@macro app_icon_name}
  final String? icon;

  /// Draws the chip as the recommended one. When no chip says so, the first
  /// one is primary.
  final bool isPrimary;

  /// Called when the chip is pressed. Null disables it.
  final VoidCallback? onPressed;
}

/// {@template action_chips}
/// A short row of suggested next steps, led by a "Suggested" label and lined
/// up on the right, which leaves the left of the row to the panel's clock.
/// {@endtemplate}
class ActionChips extends StatelessWidget {
  /// {@macro action_chips}
  const ActionChips({
    required this.chips,
    this.label = 'Suggested',
    super.key,
  });

  /// The suggested steps. Empty keeps the row's room without showing any.
  final List<ActionChipData> chips;

  /// The text next to the sparkle.
  final String label;

  @override
  Widget build(BuildContext context) {
    // Without suggestions the row keeps its room, so the cards stay put.
    if (chips.isEmpty) return const SizedBox(height: ActionPill.height);
    final primary = chips.any((chip) => chip.isPrimary)
        ? chips.indexWhere((chip) => chip.isPrimary)
        : 0;
    return Align(
      alignment: Alignment.centerRight,
      heightFactor: 1,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.s4,
        runSpacing: AppSpacing.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: AppSpacing.s1),
              Icon(
                AppIcons.byName('sparkle'),
                size: 22,
                color: AppColors.spark,
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(width: AppSpacing.s2),
            ],
          ),
          for (var i = 0; i < chips.length; i++)
            ActionPill(
              label: chips[i].label,
              icon: chips[i].icon,
              onPressed: chips[i].onPressed,
              style: i == primary
                  ? ActionPillStyle.primary
                  : ActionPillStyle.outlined,
              iconColor: i == primary ? null : _iconColor(chips[i].icon),
            ),
        ],
      ),
    );
  }

  /// The icon of a white pill: the lighting ink for what lights and scenes
  /// do, the accent blue for the rest.
  static Color _iconColor(String? icon) => switch (icon) {
    'scene' || 'light' || 'blinds' || 'restaurant' => AppTone.lighting.ink,
    _ => AppColors.accent,
  };
}
