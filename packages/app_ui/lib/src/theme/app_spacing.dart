/// {@template app_spacing}
/// The spacing, radius and size tokens of the panel, on a 4pt grid.
/// {@endtemplate}
abstract final class AppSpacing {
  /// One grid step, for the tightest gaps.
  static const s1 = 4.0;

  /// Two grid steps, for gaps between small related elements.
  static const s2 = 8.0;

  /// Three grid steps, for gaps inside a row of content.
  static const s3 = 12.0;

  /// Four grid steps, for gaps between sibling controls.
  static const s4 = 16.0;

  /// Five grid steps, for the horizontal padding of a field.
  static const s5 = 20.0;

  /// Six grid steps, for the horizontal padding of a button.
  static const s6 = 24.0;

  /// Eight grid steps, for the widest standard gap.
  static const s8 = 32.0;

  /// The corner radius of a card.
  static const cardRadius = 32.0;

  /// The padding inside a card (`padding/card`).
  static const cardPadding = 32.0;

  /// The vertical padding of a card that spreads its content
  /// (`padding/card-compact`).
  static const cardPaddingCompact = 28.0;

  /// The gap between the parts of a card's content (`gap/card-content`).
  static const cardContentGap = 12.0;

  /// The height of a chip (`size/chip-height`).
  static const chipHeight = 36.0;

  /// The horizontal padding of a chip (`padding/chip-horizontal`).
  static const chipPadding = 14.0;

  /// The height of a button (`size/button-height`).
  static const buttonHeight = 64.0;

  /// The diameter of an icon bubble (`size/icon-container`).
  static const iconBubble = 48.0;

  /// The corner radius of a panel inside a card (`component/inner-panel`).
  static const innerPanelRadius = 24.0;

  /// The corner radius of an inline surface or leading tile.
  static const tileRadius = 14.0;

  /// A fully rounded corner, for pills.
  static const pillRadius = 999.0;

  /// The minimum tap target, large enough for a wall panel.
  static const tapTarget = 48.0;

  /// The size of a leading icon tile.
  static const iconTile = 48.0;

  /// The size of a timeline marker.
  static const marker = 14.0;

  /// The width of the line joining timeline markers.
  static const rail = 2.0;

  /// The width of the time column on a timeline.
  static const timeColumn = 56.0;

  /// The width of the panel's screen, used by the frame.
  static const panelWidth = 1280.0;

  /// The height of the panel's screen, used by the frame.
  static const panelHeight = 800.0;

  /// The gap between the floating panels of the screen.
  static const gutter = 24.0;

  /// The margin between the screen edge and its content.
  static const screenMargin = 32.0;

  /// The bezel around the screen.
  static const bezelWidth = 14.0;

  /// The outer corner radius of the bezel.
  static const bezelRadius = 32.0;

  /// The inner corner radius of the screen.
  static const screenRadius = 20.0;

  /// The width of the bezel's edge line.
  static const bezelEdgeWidth = 2.0;

  /// The widest a form column gets.
  static const formWidth = 360.0;
}
