import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_shadows.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// {@template glow}
/// A soft round light laid over a [GlowSurface], placed from the top left of
/// the card, as the Figma `Highlight` and `Ambient glow` layers are.
/// {@endtemplate}
class Glow {
  /// {@macro glow}
  ///
  /// The box is [size] wide, with its top left at ([left], [top]) from the
  /// card's corner.
  const Glow({
    required double this.left,
    required this.top,
    required this.size,
    required this.color,
  }) : right = null;

  /// {@macro glow}
  ///
  /// It is placed from the card's right edge: [right] is the gap between the
  /// glow box's right side and the card's, negative when the glow runs past
  /// it. The ambient glow keeps its place in a wider or narrower card this
  /// way.
  const Glow.fromRight({
    required double this.right,
    required this.top,
    required this.size,
    required this.color,
  }) : left = null;

  /// The distance from the card's left edge, or null when placed from the
  /// right.
  final double? left;

  /// The distance from the card's right edge, or null when placed from the
  /// left.
  final double? right;

  /// The distance from the card's top edge.
  final double top;

  /// The side of the glow's box.
  final double size;

  /// The color at the center, which fades to nothing.
  final Color color;
}

/// {@template glow_surface}
/// A card surface with a flat fill, an optional border and round glows, for
/// the cards that are not a plain white `AppCard` or a wash from a tone.
///
/// The [padding] sits inside the [border], as it does in Figma.
/// {@endtemplate}
class GlowSurface extends StatelessWidget {
  /// {@macro glow_surface}
  const GlowSurface({
    required this.child,
    this.color = AppColors.surfaceRaised,
    this.border,
    this.glows = const [],
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    super.key,
  });

  /// The card content.
  final Widget child;

  /// The fill.
  final Color color;

  /// The border, drawn inside the card's edge.
  final BorderSide? border;

  /// The glows, back to front.
  final List<Glow> glows;

  /// The space between the border and the content.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.cardRadius);
    final border = this.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            border: border == null
                ? null
                : Border.all(color: border.color, width: border.width),
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              for (final glow in glows)
                Positioned(
                  left: glow.left == null ? null : glow.left! - glow.size / 4,
                  right: glow.right == null
                      ? null
                      : glow.right! - glow.size / 4,
                  top: glow.top - glow.size / 4,
                  width: glow.size * 1.5,
                  height: glow.size * 1.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [glow.color, glow.color.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: padding + EdgeInsets.all(border?.width ?? 0),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
