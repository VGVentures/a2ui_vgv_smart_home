import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// {@template microphone_button}
/// The round microphone button of the ask bar and of the voice card.
/// {@endtemplate}
class MicrophoneButton extends StatelessWidget {
  /// {@macro microphone_button}
  const MicrophoneButton({
    required this.tooltip,
    required this.onPressed,
    this.size = 64,
    super.key,
  });

  /// The button's diameter; the icon grows with it.
  final double size;

  /// The label shown on long press and read by screen readers.
  final String tooltip;

  /// Called when the button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.ink,
          ),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              Symbols.mic_rounded,
              size: size * 0.46,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
