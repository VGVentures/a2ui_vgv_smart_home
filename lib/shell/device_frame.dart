import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// {@template device_frame}
/// Presents [child] as a kitchen wall tablet in the middle of the page.
///
/// The panel never exceeds a mid sized tablet, [maxWidth] by [maxHeight], and
/// shrinks to fit smaller windows while keeping that 16:10 ratio. The screen
/// inside the bezel is always [AppSpacing.panelWidth] by
/// [AppSpacing.panelHeight] to the child, scaled down to fit a smaller window,
/// so the layout is the same at every window size.
/// {@endtemplate}
class DeviceFrame extends StatelessWidget {
  /// {@macro device_frame}
  const DeviceFrame({required this.child, super.key});

  /// The screen shown inside the bezel.
  final Widget child;

  static const double _bezel =
      AppSpacing.bezelWidth + AppSpacing.bezelEdgeWidth;

  /// The widest the frame gets: the screen plus a bezel on each side.
  static const double maxWidth = AppSpacing.panelWidth + 2 * _bezel;

  /// The tallest the frame gets: the screen plus a bezel on each side.
  static const double maxHeight = AppSpacing.panelHeight + 2 * _bezel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: AspectRatio(
          aspectRatio: maxWidth / maxHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(AppSpacing.bezelRadius),
              border: Border.all(
                color: AppColors.bezelEdge,
                width: AppSpacing.bezelEdgeWidth,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.bezelWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.screenRadius),
                // The screen is laid out at its full size and scaled to the
                // frame, so a small window shrinks the panel, not its grid.
                child: FittedBox(
                  child: SizedBox(
                    width: AppSpacing.panelWidth,
                    height: AppSpacing.panelHeight,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: const Size(
                          AppSpacing.panelWidth,
                          AppSpacing.panelHeight,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
