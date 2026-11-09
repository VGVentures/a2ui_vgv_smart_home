import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_shadows.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// {@template skeleton_surface}
/// A pulsing stand-in for the dashboard while it loads.
///
/// Mirrors the usual shape of a dashboard: two columns of cards around a tall
/// one, and a row of pills beneath, on the right like the chips row.
/// {@endtemplate}
class SkeletonSurface extends StatefulWidget {
  /// {@macro skeleton_surface}
  const SkeletonSurface({super.key});

  @override
  State<SkeletonSurface> createState() => _SkeletonSurfaceState();
}

/// Pulses the skeleton cards.
class _SkeletonSurfaceState extends State<SkeletonSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(
            CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
          ),
          child: const Column(
            spacing: AppSpacing.gutter,
            children: [
              Expanded(
                child: Row(
                  spacing: AppSpacing.gutter,
                  children: [
                    Expanded(
                      flex: 446,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppSpacing.gutter,
                        children: [
                          Expanded(child: _SkeletonCard()),
                          Expanded(child: _SkeletonCard()),
                        ],
                      ),
                    ),
                    Expanded(flex: 352, child: _SkeletonCard()),
                    Expanded(
                      flex: 258,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppSpacing.gutter,
                        children: [
                          Expanded(child: _SkeletonCard()),
                          Expanded(child: _SkeletonCard()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: AppSpacing.s4,
                children: [
                  _Bar(width: 140, height: AppSpacing.buttonHeight),
                  _Bar(width: 200, height: AppSpacing.buttonHeight),
                  _Bar(width: 180, height: AppSpacing.buttonHeight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A placeholder card of the skeleton.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.soft,
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.cardPaddingCompact,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.s3,
          children: [
            _Bar(width: 120, height: 28),
            Spacer(),
            _Bar(width: 180, height: 20),
            _Bar(width: 120, height: 56),
          ],
        ),
      ),
    );
  }
}

/// A placeholder bar of the skeleton.
class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandNeutral200.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}
