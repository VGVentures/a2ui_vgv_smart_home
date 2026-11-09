import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_shadows.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_tone.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// {@template app_card}
/// The raised surface every panel card sits on.
/// {@endtemplate}
class AppCard extends StatelessWidget {
  /// {@macro app_card}
  const AppCard({
    required this.child,
    this.tint,
    this.tone = AppTone.neutral,
    this.outlined,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.cardPadding,
      vertical: AppSpacing.cardPaddingCompact,
    ),
    super.key,
  });

  /// The card content.
  final Widget child;

  /// An optional wash laid over the card, for example an alert color.
  final Color? tint;

  /// The card color: a radial wash from the top right, over white.
  final AppTone tone;

  /// Whether a hairline outlines the card. By default only a white card has
  /// one.
  final bool? outlined;

  /// The space between the card's edge and its content.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.cardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: radius,
        boxShadow: AppShadows.soft,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tint,
          gradient: tone.gradient,
          borderRadius: radius,
          // A white card is lifted by a hairline; a tinted one by its color.
          border: (outlined ?? (tone == AppTone.neutral && tint == null))
              ? Border.all(color: AppColors.line)
              : null,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// {@template icon_tile}
/// A round tile holding an icon in a soft fill, used to lead a row.
/// {@endtemplate}
class IconTile extends StatelessWidget {
  /// {@macro icon_tile}
  const IconTile({
    required this.icon,
    this.color = AppColors.accent,
    this.background = AppColors.accentSoft,
    super.key,
  });

  /// The icon drawn in the tile.
  final IconData icon;

  /// The icon color.
  final Color color;

  /// The tile fill.
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.iconTile,
      height: AppSpacing.iconTile,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 26, color: color),
    );
  }
}

/// {@template pill_button}
/// A pill-shaped button used for the small actions on a card.
/// {@endtemplate}
class PillButton extends StatelessWidget {
  /// {@macro pill_button}
  const PillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
    this.color = AppColors.accent,
    super.key,
  });

  /// The button text.
  final String label;

  /// Called when the button is pressed. Null disables it.
  final VoidCallback? onPressed;

  /// An optional icon before the [label].
  final IconData? icon;

  /// Whether the button is filled with [color] rather than the warm fill.
  final bool filled;

  /// The fill of a [filled] button.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final foreground = filled ? AppColors.onAccent : AppColors.ink;
    return Material(
      color: filled ? color : AppColors.fillWarm,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.buttonHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 24, color: foreground),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
