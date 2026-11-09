import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_shadows.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// {@template ask_bar}
/// The field where the user talks to the assistant.
///
/// Shows [text] muted as a hint, or in full while [isHint] is false, such as
/// the command being spoken. The [trailing] button sits at its end.
/// {@endtemplate}
class AskBar extends StatelessWidget {
  /// {@macro ask_bar}
  const AskBar({
    required this.text,
    required this.trailing,
    this.isHint = true,
    super.key,
  });

  /// The hint or the command being spoken.
  final String text;

  /// Whether [text] is a muted hint rather than a command.
  final bool isHint;

  /// The button at the end of the bar, such as the microphone.
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 8, 8),
          child: Row(
            spacing: 16,
            children: [
              const Icon(
                Symbols.auto_awesome_rounded,
                size: 28,
                color: AppColors.spark,
              ),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    color: isHint ? AppColors.ink2 : AppColors.ink,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
