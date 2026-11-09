import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_icons.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// {@template status_tag_kind}
/// How a [StatusTag] reads: what it says about the card.
/// {@endtemplate}
enum StatusTagKind {
  /// "Updated", "Updated just now".
  updated('sparkle'),

  /// "New".
  isNew('sparkle'),

  /// "Moved".
  moved('clock'),

  /// Any other short fact: "Now 4:30", "6 guests", "On".
  info(null);

  /// {@macro status_tag_kind}
  const StatusTagKind(this.defaultIcon);

  /// The icon used when the tag names none.
  final String? defaultIcon;

  /// The kind the catalog calls [name]; unknown names read as [info].
  static StatusTagKind byName(String? name) => switch (name) {
    'updated' => updated,
    'new' => isNew,
    'moved' => moved,
    _ => info,
  };
}

/// {@template status_tag}
/// The small pill in a card corner that says the card changed.
/// {@endtemplate}
class StatusTag extends StatelessWidget {
  /// {@macro status_tag}
  const StatusTag({
    required this.label,
    this.kind = StatusTagKind.info,
    this.icon,
    this.tint,
    this.dot,
    this.ink = AppColors.ink,
    super.key,
  });

  /// The pill text.
  final String label;

  /// The pill fill, for a card whose wash would swallow the default grey.
  final Color? tint;

  /// A small filled dot before the label, in place of the icon.
  final Color? dot;

  /// The label and icon color: the ink of the card's tone.
  final Color ink;

  /// How the tag reads, which picks its default icon.
  final StatusTagKind kind;

  /// An icon name from [AppIcons]; defaults from [kind].
  final String? icon;

  static const double _height = AppSpacing.chipHeight;

  @override
  Widget build(BuildContext context) {
    final iconName = icon ?? kind.defaultIcon;
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.chipPadding),
      decoration: BoxDecoration(
        color: tint ?? AppColors.fillWarm,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: AppSpacing.s2,
              height: AppSpacing.s2,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ] else if (iconName != null) ...[
            Icon(AppIcons.byName(iconName), size: 18, color: ink),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMedium.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
