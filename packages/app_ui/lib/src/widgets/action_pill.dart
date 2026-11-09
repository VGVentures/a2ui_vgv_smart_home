import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_icons.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// {@template action_pill_style}
/// How an [ActionPill] looks: its fill, text and icon colors.
/// {@endtemplate}
enum ActionPillStyle {
  /// Ink fill, light text, spark icon.
  primary,

  /// Soft grey fill, ink text and icon.
  secondary,

  /// White fill with a hairline border, ink text and icon.
  outlined,

  /// Green wash with a check, for an action the server finished.
  done,
}

/// {@template action_pill}
/// A full-height pill button for the actions on a card or in a row.
/// {@endtemplate}
class ActionPill extends StatelessWidget {
  /// {@macro action_pill}
  const ActionPill({
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = ActionPillStyle.secondary,
    this.iconColor,
    this.fill,
    this.foreground,
    this.horizontalPadding = 28,
    super.key,
  });

  /// The pill text.
  final String label;

  /// An icon name from [AppIcons]. A [ActionPillStyle.done] pill always shows
  /// a check instead.
  final String? icon;

  /// How the pill looks.
  final ActionPillStyle style;

  /// Overrides the icon color the [style] gives.
  final Color? iconColor;

  /// Overrides the fill the [style] gives, for a pill that sits on a tint.
  final Color? fill;

  /// Overrides the text color the [style] gives.
  final Color? foreground;

  /// The padding before the icon and after the label.
  final double horizontalPadding;

  /// Null disables the pill. A done pill never reacts to presses.
  final VoidCallback? onPressed;

  /// The pill height.
  static const double height = AppSpacing.buttonHeight;

  Color get _fill =>
      fill ??
      switch (style) {
        ActionPillStyle.primary => AppColors.ink,
        ActionPillStyle.secondary => AppColors.fillWarm,
        ActionPillStyle.outlined => AppColors.surfaceRaised,
        ActionPillStyle.done => AppColors.successSoft,
      };

  Color get _foreground =>
      foreground ??
      switch (style) {
        ActionPillStyle.primary => AppColors.onPrimary,
        ActionPillStyle.done => AppColors.success,
        _ => AppColors.ink,
      };

  Color get _iconColor =>
      iconColor ??
      (style == ActionPillStyle.primary ? AppColors.spark : _foreground);

  @override
  Widget build(BuildContext context) {
    final isDone = style == ActionPillStyle.done;
    final iconData = isDone
        ? AppIcons.byName('check')
        : (icon == null ? null : AppIcons.byName(icon));
    final shape = StadiumBorder(
      side: style == ActionPillStyle.outlined
          ? const BorderSide(color: AppColors.line)
          : BorderSide.none,
    );
    return Material(
      color: _fill,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: isDone ? null : onPressed,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconData != null) ...[
                  Icon(iconData, size: 24, color: _iconColor),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      color: _foreground,
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
