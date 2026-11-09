import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// {@template app_switch}
/// A 72 x 40 on/off switch whose on color is set by the caller, usually the
/// card's tone accent.
/// {@endtemplate}
class AppSwitch extends StatelessWidget {
  /// {@macro app_switch}
  const AppSwitch({
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.ink,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value on tap. Null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// The track color when on.
  final Color activeColor;

  /// The width of the track.
  static const double width = 72;

  /// The height of the track.
  static const double height = 40;

  static const double _thumb = 32;
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          height: height,
          padding: const EdgeInsets.all(_inset),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? activeColor : AppColors.fill,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Container(
            width: _thumb,
            height: _thumb,
            decoration: const BoxDecoration(
              color: AppColors.surfaceRaised,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
