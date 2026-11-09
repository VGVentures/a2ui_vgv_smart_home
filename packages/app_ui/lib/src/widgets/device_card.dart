import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_icons.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_tone.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:app_ui/src/widgets/action_pill.dart';
import 'package:app_ui/src/widgets/app_card.dart';
import 'package:app_ui/src/widgets/app_switch.dart';
import 'package:app_ui/src/widgets/card_icon_bubble.dart';
import 'package:app_ui/src/widgets/optimistic_scope.dart';
import 'package:app_ui/src/widgets/status_tag.dart';
import 'package:app_ui/src/widgets/stepper_buttons.dart';
import 'package:flutter/material.dart';

/// {@template device_control_type}
/// The control a [DeviceCard] shows in its top-right slot.
/// {@endtemplate}
enum DeviceControlType {
  /// An on/off [AppSwitch].
  toggle,

  /// Two round minus and plus buttons.
  stepper,

  /// A primary pill with a label and an icon.
  button,

  /// Nothing.
  none;

  /// The type the catalog calls [name]; unknown names read as [none].
  static DeviceControlType byName(String? name) {
    for (final type in values) {
      if (type.name == name) return type;
    }
    return none;
  }
}

/// {@template device_card}
/// One device's state: icon, name, status line, a hero reading and one control
/// slot (a switch, a stepper, a button, a status tag, or nothing).
///
/// The switch and the stepper are optimistic: a tap shows the new value at once
/// in local state, whether or not the props are bound. The local value is
/// dropped when the props change (the surface answered) and when the nearest
/// [OptimisticScope] bumps its revision (the turn failed).
/// {@endtemplate}
class DeviceCard extends StatefulWidget {
  /// {@macro device_card}
  const DeviceCard({
    required this.name,
    required this.status,
    this.room,
    this.icon,
    this.tone = AppTone.neutral,
    this.value,
    this.unit,
    this.delta,
    this.tag,
    this.isActive = false,
    this.isLoading = false,
    this.controlType = DeviceControlType.none,
    this.controlLabel,
    this.controlIcon,
    this.onToggle,
    this.onIncrement,
    this.onDecrement,
    this.onPressed,
    super.key,
  });

  /// The device name, for example `Oven`.
  final String name;

  /// A short state line, for example `Preheats at 6:00 PM`.
  final String status;

  /// A prefix of the status line, for example `Entry`.
  final String? room;

  /// {@macro app_icon_name}
  final String? icon;

  /// The card color.
  final AppTone tone;

  /// The hero reading, for example `400` or `Locked`.
  final String? value;

  /// The small unit after the hero, for example `°F`.
  final String? unit;

  /// A line next to the hero, for example `↑ from 72 °F`.
  final String? delta;

  /// A pill that replaces the control slot visually.
  final StatusTag? tag;

  /// Whether the device is on, which tints the icon and the switch.
  final bool isActive;

  /// Draws the card as a skeleton with an "Updating…" note, while the device
  /// answers.
  final bool isLoading;

  /// Which control the top-right slot shows.
  final DeviceControlType controlType;

  /// The label of the [DeviceControlType.button] pill.
  final String? controlLabel;

  /// An icon name for the [DeviceControlType.button] pill.
  final String? controlIcon;

  /// Called with the new value when the switch is tapped.
  final ValueChanged<bool>? onToggle;

  /// {@macro stepper_plus_tapped}
  final VoidCallback? onIncrement;

  /// {@macro stepper_minus_tapped}
  final VoidCallback? onDecrement;

  /// Called when the button pill is tapped.
  final VoidCallback? onPressed;

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

/// Holds the toggle and value the person changed, until the next answer
/// settles.
class _DeviceCardState extends State<DeviceCard> {
  bool? _active;
  String? _value;
  int? _revision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = OptimisticScope.of(context);
    if (_revision != null && _revision != revision) {
      _active = null;
      _value = null;
    }
    _revision = revision;
  }

  @override
  void didUpdateWidget(DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) _active = null;
    if (oldWidget.value != widget.value) _value = null;
  }

  bool get _isActive => _active ?? widget.isActive;

  String? get _shownValue => _value ?? widget.value;

  void _toggle(bool next) {
    setState(() => _active = next);
    widget.onToggle?.call(next);
  }

  void _step(int by, VoidCallback? callback) {
    final current = num.tryParse(_shownValue ?? '');
    if (current != null) setState(() => _value = '${current + by}');
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    final value = _shownValue;
    final unit = widget.unit;
    final isActive = _isActive;
    final status = widget.status;
    if (widget.isLoading) return const _LoadingCard();
    final tag = widget.tag;
    final updated = tag != null;
    final tone = widget.tone;
    final card = LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        // A cell shorter than the full card draws a smaller hero and a
        // tighter card, so the three parts always fit.
        final compact =
            bounded &&
            constraints.maxHeight < _fullHeight(hasValue: value != null);
        return AppCard(
          tone: tone,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: compact ? AppSpacing.s4 : AppSpacing.cardPaddingCompact,
          ),
          child: Column(
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _top(isActive: isActive, tag: tag),
              if (!bounded) const SizedBox(height: AppSpacing.s4),
              _text(status),
              if (!bounded) const SizedBox(height: AppSpacing.s4),
              if (value != null)
                _heroBlock(
                  value,
                  unit,
                  highlighted: updated,
                  compact: compact,
                )
              else if (widget.delta != null)
                Text(widget.delta!, style: _label),
            ],
          ),
        );
      },
    );
    if (!updated) return card;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: tone.accent, width: 2),
      ),
      child: card,
    );
  }

  /// The height below which the card draws its compact form: the padding, the
  /// top row, the name and status, the hero and the gaps between them.
  double _fullHeight({required bool hasValue}) =>
      2 * AppSpacing.cardPaddingCompact +
      _topHeight +
      _textHeight +
      (hasValue ? _heroHeight : 0) +
      2 * AppSpacing.s2;

  static const double _textHeight = 29 + 4 + 20;
  static const double _heroHeight = 67;

  double get _topHeight => switch (widget.controlType) {
    DeviceControlType.stepper || DeviceControlType.button => 64,
    _ => AppSpacing.iconBubble,
  };

  bool get _neutral => widget.tone == AppTone.neutral;

  /// The ink of the card's text and icons: navy on white, the tone's ink on a
  /// tint.
  Color get _ink => _neutral ? AppColors.ink : widget.tone.ink;

  TextStyle get _label => AppTypography.label.copyWith(
    color: _neutral ? AppColors.ink2 : _ink.withValues(alpha: 0.78),
  );

  Widget _top({required bool isActive, required StatusTag? tag}) {
    final icon = widget.icon;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) _bubble(icon),
              if (tag != null) ...[
                if (icon != null) const SizedBox(width: AppSpacing.s2),
                Flexible(child: tag),
              ],
            ],
          ),
        ),
        _slot(isActive: isActive),
      ],
    );
  }

  /// The icon always sits in a colored circle, on or off: a yellow one on a
  /// white card, a white veil on a tint.
  Widget _bubble(String icon) => CardIconBubble(
    icon: AppIcons.byName(icon),
    background: _neutral ? AppColors.brandYellow100 : AppColors.overlayOnTint,
    color: _neutral ? AppColors.brandYellow300 : widget.tone.ink,
  );

  Widget _text(String status) {
    final room = widget.room;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.title.copyWith(color: _ink),
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          room == null ? status : '$room · $status',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _label,
        ),
      ],
    );
  }

  Widget _heroBlock(
    String value,
    String? unit, {
    required bool highlighted,
    required bool compact,
  }) {
    final delta = widget.delta;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: _hero(
                value,
                unit,
                highlighted: highlighted,
                compact: compact,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: 10),
              Flexible(child: _delta(delta)),
            ],
          ],
        ),
      ],
    );
  }

  /// The change next to the hero: an arrow and the previous value.
  Widget _delta(String delta) {
    final match = RegExp(r'^([↑↓])\s*(.*)$').firstMatch(delta);
    final style = AppTypography.labelMedium.copyWith(
      color: _ink.withValues(alpha: 0.8),
    );
    if (match == null) {
      return Text(
        delta,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          match.group(1) == '↑'
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          size: 18,
          color: _ink,
        ),
        const SizedBox(width: AppSpacing.s1),
        Flexible(
          child: Text(
            match.group(2)!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  Color get _switchColor => switch (widget.tone) {
    AppTone.neutral => AppColors.brandYellow200,
    AppTone.security => AppColors.ink,
    _ => widget.tone.accent,
  };

  /// A short unit such as `°F` or `%` is part of the hero; a word such as
  /// `cups ready` reads small beside it.
  static bool _isSymbol(String unit) => unit.length <= 2;

  /// The hero reading. After a change it sits on a soft white plate.
  Widget _hero(
    String value,
    String? unit, {
    required bool highlighted,
    required bool compact,
  }) {
    final style =
        (compact ? AppTypography.headlineMedium : AppTypography.displaySmall)
            .copyWith(color: _ink);
    final symbol = unit != null && _isSymbol(unit);
    final text = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            symbol ? '$value$unit' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (unit != null && !symbol) ...[
          const SizedBox(width: 10),
          Text(
            unit,
            style: AppTypography.title.copyWith(color: AppColors.ink2),
          ),
        ],
      ],
    );
    if (!highlighted) return text;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left: -10,
          right: -10,
          top: -2,
          bottom: -2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.overlayOnTint.withValues(alpha: 0.36),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        text,
      ],
    );
  }

  Widget _slot({required bool isActive}) {
    final controlIcon = widget.controlIcon;
    return switch (widget.controlType) {
      DeviceControlType.toggle => AppSwitch(
        value: isActive,
        activeColor: _switchColor,
        onChanged: widget.onToggle == null ? null : _toggle,
      ),
      DeviceControlType.stepper => StepperButtons(
        color: _ink,
        onDecrement: widget.onDecrement == null
            ? null
            : () => _step(-1, widget.onDecrement),
        onIncrement: widget.onIncrement == null
            ? null
            : () => _step(1, widget.onIncrement),
      ),
      DeviceControlType.button => ActionPill(
        label: widget.controlLabel ?? widget.name,
        icon: controlIcon,
        style: ActionPillStyle.primary,
        onPressed: widget.onPressed,
      ),
      DeviceControlType.none => const SizedBox.shrink(),
    };
  }
}

/// The skeleton a [DeviceCard] shows while the device answers.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Updating',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bounded = constraints.hasBoundedHeight;
            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _Block(
                        width: AppSpacing.iconBubble,
                        height: AppSpacing.iconBubble,
                        circle: true,
                      ),
                      const Spacer(),
                      const _LiveDot(),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        'Updating…',
                        style: AppTypography.labelStrong.copyWith(
                          color: AppColors.ink2,
                        ),
                      ),
                    ],
                  ),
                  if (!bounded) const SizedBox(height: AppSpacing.s4),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.6,
                        child: _Block(height: 22),
                      ),
                      SizedBox(height: 10),
                      FractionallySizedBox(
                        widthFactor: 0.8,
                        child: _Block(height: 16),
                      ),
                    ],
                  ),
                  if (!bounded) const SizedBox(height: AppSpacing.s4),
                  const FractionallySizedBox(
                    widthFactor: 0.5,
                    child: _Block(height: 56, radius: 20),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The live dot: a navy point inside a soft ring (`ext/live`, `ext/live-ring`).
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0x26020F30),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.ink,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// A placeholder block of the card's loading skeleton.
class _Block extends StatelessWidget {
  const _Block({
    required this.height,
    this.width,
    this.circle = false,
    this.radius,
  });

  final double? width;
  final double height;
  final bool circle;

  /// The corner radius; fully rounded when null.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.fillWarm,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle
            ? null
            : BorderRadius.circular(radius ?? AppSpacing.pillRadius),
      ),
    );
  }
}
