import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// {@template brand_lockup}
/// The Very Good Ventures lockup: the unicorn with "Very Good Ventures" and
/// "A2UI Smart Home." beside it.
///
/// The words are part of the artwork, so it is drawn as designed, in its own
/// colours, and [semanticLabel] says it to assistive tech.
/// {@endtemplate}
class BrandLockup extends StatelessWidget {
  /// {@macro brand_lockup}
  const BrandLockup({required this.semanticLabel, super.key});

  /// What a screen reader announces, for example
  /// `Very Good Ventures, A2UI Smart Home`.
  final String semanticLabel;

  static const double _width = 305;
  static const double _height = 57;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/vgv_lockup.svg',
      package: 'app_ui',
      width: _width,
      height: _height,
      semanticsLabel: semanticLabel,
    );
  }
}
