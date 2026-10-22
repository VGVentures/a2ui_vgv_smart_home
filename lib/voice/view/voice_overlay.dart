import 'dart:async';

import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:a2ui_vgv_smart_home/voice/cubit/voice_cubit.dart';
import 'package:a2ui_vgv_smart_home/voice/view/cancel_pill.dart';
import 'package:a2ui_vgv_smart_home/voice/view/microphone_button.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// {@template voice_overlay}
/// The card that opens from the ask bar while the user speaks: who is being
/// listened to, the words as they come, how loud they are, and a way out.
///
/// It grows from [collapsedSize] (the ask bar) to the full width, then fades
/// its contents in. The screen behind it is faded by a [VoiceScrim]. Closing
/// runs it backwards.
/// Fill the stack it sits in with it: it is invisible and lets taps through
/// while closed.
/// {@endtemplate}
class VoiceOverlay extends StatefulWidget {
  /// {@macro voice_overlay}
  const VoiceOverlay({
    required this.open,
    required this.collapsedSize,
    required this.name,
    required this.text,
    required this.levels,
    required this.onCancel,
    required this.onSend,
    super.key,
  });

  /// Whether the card is open.
  final bool open;

  /// The ask bar's size, where the card starts and ends.
  final Size collapsedSize;

  /// Who is being listened to.
  final String name;

  /// What was heard so far. Empty until the first words.
  final String text;

  /// How loud the last chunks of audio were. See [VoiceState.levels].
  final List<double> levels;

  /// The user backed out of the command.
  final VoidCallback onCancel;

  /// The user tapped the microphone: that is all they had to say.
  final VoidCallback onSend;

  static const double _height = 328;
  static const double _radius = 40;

  @override
  State<VoiceOverlay> createState() => _VoiceOverlayState();
}

/// Animates the overlay open and closed.
class _VoiceOverlayState extends State<VoiceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    reverseDuration: const Duration(milliseconds: 350),
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(VoiceOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      unawaited(widget.open ? _controller.forward() : _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
    parent: _controller,
    curve: Interval(begin, end, curve: Curves.easeOut),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isDismissed) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            final full = Size(constraints.maxWidth, VoiceOverlay._height);
            final collapsed = Size(
              widget.collapsedSize.width.clamp(0, full.width),
              widget.collapsedSize.height,
            );
            final size = Size.lerp(
              collapsed,
              full,
              Curves.easeInOutCubicEmphasized.transform(_controller.value),
            )!;
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: SizedBox.fromSize(
                    size: size,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(
                          VoiceOverlay._radius,
                        ),
                        border: Border.all(color: AppColors.line),
                        boxShadow: AppShadows.soft,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          VoiceOverlay._radius,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FadeTransition(
                              opacity: _interval(0.1, 0.7),
                              child: const _Glow(),
                            ),
                            FadeTransition(
                              opacity: _interval(0.4, 1),
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: full.width,
                                maxWidth: full.width,
                                minHeight: full.height,
                                maxHeight: full.height,
                                child: _Content(
                                  name: widget.name,
                                  text: widget.text,
                                  levels: widget.levels,
                                  onCancel: widget.onCancel,
                                  onSend: widget.onSend,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// {@template voice_scrim}
/// The veil over the whole screen while the card is open.
///
/// It takes the taps while [open], so nothing behind the card is pressed, and
/// fades in and out with the card.
/// {@endtemplate}
class VoiceScrim extends StatelessWidget {
  /// {@macro voice_scrim}
  const VoiceScrim({required this.open, super.key});

  /// Whether the veil is showing.
  final bool open;

  @override
  Widget build(BuildContext context) {
    // The veil takes the taps while it shows and none once it is gone.
    return IgnorePointer(
      ignoring: !open,
      child: AnimatedOpacity(
        opacity: open ? 1 : 0,
        duration: Duration(milliseconds: open ? 300 : 210),
        curve: Curves.easeOut,
        child: SizedBox.expand(
          child: ColoredBox(color: AppColors.surface.withValues(alpha: 0.75)),
        ),
      ),
    );
  }
}

/// The warm light at the right of the card, behind the microphone: the amber
/// ambient glow above and the coral one below it.
class _Glow extends StatelessWidget {
  const _Glow();

  /// A blurred disc whose visible core is [size] across, centred where the
  /// Figma ellipse is. [right] and [top] place the ellipse's own box.
  Widget _disc(
    Color color, {
    required double size,
    required double right,
    required double top,
  }) {
    // The Figma glow bleeds past its ellipse by a third of its size.
    final spread = size * 0.3;
    return Positioned(
      right: right - spread,
      top: top - spread,
      width: size + 2 * spread,
      height: size + 2 * spread,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.4, 1],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _disc(AppColors.warningSoft, size: 420, right: -76, top: -120),
        _disc(AppColors.dangerSoft, size: 300, right: -96, top: 140),
      ],
    );
  }
}

/// The overlay's body: who is listening, the text heard, the levels, and the
/// cancel and send actions.
class _Content extends StatelessWidget {
  const _Content({
    required this.name,
    required this.text,
    required this.levels,
    required this.onCancel,
    required this.onSend,
  });

  final String name;
  final String text;
  final List<double> levels;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  /// `headline/medium-emphasized`.
  static final TextStyle _transcript = AppTypography.ui(
    size: 44,
    lineHeight: 52,
    weight: FontWeight.w400,
    letterSpacing: -0.88,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
      child: Column(
        spacing: 20,
        children: [
          SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    const Icon(
                      Symbols.auto_awesome_rounded,
                      size: 28,
                      color: AppColors.spark,
                    ),
                    Text(
                      l10n.voiceListeningTo(name),
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
                CancelPill(onPressed: onCancel, prominent: true),
              ],
            ),
          ),
          Expanded(
            child: Row(
              spacing: 40,
              children: [
                Expanded(
                  // Two lines, the gap and the bars are 4 taller than the
                  // body, as in the design: centred, they bleed into the
                  // padding.
                  child: OverflowBox(
                    maxHeight: 184,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 24,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.isEmpty ? '' : '“$text”',
                          maxLines: 2,
                          overflow: TextOverflow.fade,
                          style: _transcript,
                        ),
                        _LevelBars(levels: levels),
                      ],
                    ),
                  ),
                ),
                _Halo(
                  level: levels.lastOrNull ?? 0,
                  child: MicrophoneButton(
                    tooltip: l10n.voiceSendTooltip,
                    onPressed: onSend,
                    size: 96,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two soft rings around [child] that swell with the [level] of the voice, up
/// to the 160 and 128 of the design.
class _Halo extends StatelessWidget {
  const _Halo({required this.level, required this.child});

  final double level;
  final Widget child;

  static const _duration = Duration(milliseconds: 150);

  Widget _ring(double size, double alpha) => AnimatedContainer(
    duration: _duration,
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.warning.withValues(alpha: alpha),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(128 + 32 * level, 0.2),
          _ring(112 + 16 * level, 0.35),
          child,
        ],
      ),
    );
  }
}

/// The rolling timeline of how loud the voice was: a bar per chunk, yellow
/// when soft and orange when loud, and a dot where nothing was heard yet.
class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.levels});

  final List<double> levels;

  static const double _barWidth = 8;
  static const double _minHeight = 8;
  static const double _maxHeight = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        spacing: 6,
        children: [
          for (var i = 0; i < VoiceCubit.levelCount; i++)
            if (i < levels.length)
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: _barWidth,
                height: _minHeight + (_maxHeight - _minHeight) * levels[i],
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_barWidth),
                  color: Color.lerp(
                    AppColors.warning,
                    AppColors.danger,
                    ((levels[i] - 0.35) / 0.4).clamp(0, 1),
                  ),
                ),
              )
            else
              SizedBox.square(
                dimension: _barWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.fill.withValues(alpha: 0.6),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
