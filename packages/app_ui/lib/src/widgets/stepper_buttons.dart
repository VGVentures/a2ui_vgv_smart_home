import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// {@template stepper_buttons}
/// Two round buttons, minus and plus, for nudging a value.
/// {@endtemplate}
class StepperButtons extends StatelessWidget {
  /// {@macro stepper_buttons}
  const StepperButtons({
    required this.onDecrement,
    required this.onIncrement,
    this.color = AppColors.ink,
    super.key,
  });

  /// {@template stepper_minus_tapped}
  /// Called when the minus button is tapped.
  /// {@endtemplate}
  final VoidCallback? onDecrement;

  /// {@template stepper_plus_tapped}
  /// Called when the plus button is tapped.
  /// {@endtemplate}
  final VoidCallback? onIncrement;

  /// The icon color: the ink of the card's tone.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          icon: Icons.remove,
          label: 'Decrease',
          color: color,
          onPressed: onDecrement,
        ),
        const SizedBox(width: AppSpacing.s3),
        _RoundButton(
          icon: Icons.add,
          label: 'Increase',
          color: color,
          onPressed: onIncrement,
        ),
      ],
    );
  }
}

/// One round step button.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  static const double _size = AppSpacing.buttonHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.overlayOnTintStrong,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(icon, size: 28, color: color),
          ),
        ),
      ),
    );
  }
}
