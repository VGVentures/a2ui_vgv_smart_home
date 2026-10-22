import 'package:flutter/material.dart';

/// {@template app_shadows}
/// The elevation tokens of the panel: small controls, floating panels and
/// cards.
/// {@endtemplate}
abstract final class AppShadows {
  /// Small controls.
  static const small = [
    BoxShadow(color: Color(0x1A101828), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// The floating panels around the dashboard: sidebar, ask bar, cards.
  static const soft = [
    BoxShadow(color: Color(0x0D1C1A14), blurRadius: 40, offset: Offset(0, 12)),
  ];

  /// Cards and surfaces.
  static const card = [
    BoxShadow(color: Color(0x0D101828), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x29141E3C),
      blurRadius: 26,
      spreadRadius: -10,
      offset: Offset(0, 10),
    ),
  ];
}
