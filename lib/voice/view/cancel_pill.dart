import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// {@template cancel_pill}
/// The "Cancel" pill of the voice card and of the toast that follows it.
/// {@endtemplate}
class CancelPill extends StatelessWidget {
  /// {@macro cancel_pill}
  const CancelPill({
    required this.onPressed,
    this.prominent = false,
    super.key,
  });

  /// Called when the pill is tapped.
  final VoidCallback onPressed;

  /// The tall dark pill of the listening card, instead of the light one of the
  /// toast.
  final bool prominent;

  /// `surface/surface-container-high`.
  static const Color _fill = AppColors.surfaceContainerHigh;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: context.l10n.cancelButton,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: prominent ? AppColors.ink : _fill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: SizedBox(
            height: prominent ? 64 : 48,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: prominent ? 28 : 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: prominent ? 10 : 8,
                children: [
                  Icon(
                    Symbols.close_rounded,
                    size: prominent ? 24 : 16,
                    color: prominent ? AppColors.onPrimary : null,
                  ),
                  Text(
                    context.l10n.cancelButton,
                    style: prominent
                        ? AppTypography.labelLarge.copyWith(
                            color: AppColors.onPrimary,
                          )
                        : AppTypography.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
