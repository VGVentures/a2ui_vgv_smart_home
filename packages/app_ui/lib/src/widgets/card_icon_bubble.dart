import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// {@template icon_bubble}
/// A round bubble holding an icon, used to lead a card or a row.
/// {@endtemplate}
class CardIconBubble extends StatelessWidget {
  /// {@macro icon_bubble}
  const CardIconBubble({
    required this.icon,
    this.background = AppColors.accentSoft,
    this.color = AppColors.ink,
    this.size = 48,
    super.key,
  });

  /// The icon drawn in the bubble.
  final IconData icon;

  /// The bubble fill.
  final Color background;

  /// The icon color.
  final Color color;

  /// The bubble diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: size / 2, color: color),
    );
  }
}

/// Splits a display time such as `5:00 PM` into its digits and its suffix.
///
/// The suffix is empty when the value does not end in `AM` or `PM`.
(String, String) splitMeridiem(String time) {
  final match = RegExp(r'^(.*?)\s*(AM|PM)$').firstMatch(time.trim());
  if (match == null) return (time, '');
  return (match.group(1)!, match.group(2)!);
}
