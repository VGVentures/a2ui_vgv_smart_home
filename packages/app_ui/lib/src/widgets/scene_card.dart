import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_icons.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_tone.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:app_ui/src/widgets/action_pill.dart';
import 'package:app_ui/src/widgets/app_card.dart';
import 'package:app_ui/src/widgets/glow_surface.dart';
import 'package:app_ui/src/widgets/status_tag.dart';
import 'package:flutter/material.dart';

/// {@template scene_state}
/// Whether a scene waits to be started or is already on.
/// {@endtemplate}
enum SceneState {
  /// Shows the start pill.
  ready,

  /// Shows the `On` tag instead of the pill.
  running;

  /// The state the catalog calls [name]; unknown names read as [ready].
  static SceneState byName(String? name) => name == 'running' ? running : ready;
}

/// {@template scene_card}
/// A group of device settings that run with one tap.
/// {@endtemplate}
class SceneCard extends StatelessWidget {
  /// {@macro scene_card}
  const SceneCard({
    required this.name,
    this.description,
    this.icon = 'scene',
    this.state = SceneState.ready,
    this.tone = AppTone.lighting,
    this.settings = const [],
    this.actionLabel = 'Start',
    this.runningLabel = 'On',
    this.onRun,
    super.key,
  });

  /// The scene name, for example `Dinner`.
  final String name;

  /// A line under the [name] saying what the scene is for.
  final String? description;

  /// {@macro app_icon_name}
  final String icon;

  /// Whether the scene waits to be started or is running.
  final SceneState state;

  /// The card color.
  final AppTone tone;

  /// What the scene sets, for example `Pendants 40 %`.
  final List<String> settings;

  /// The text of the start pill.
  final String actionLabel;

  /// The text of the tag shown while the scene runs.
  final String runningLabel;

  /// Called when the start pill is pressed. Null disables it.
  final VoidCallback? onRun;

  static const double _top = AppSpacing.buttonHeight;
  static const double _texts = 29 + 20 + AppSpacing.s1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        final room = constraints.maxHeight - 2 * AppSpacing.cardPadding;
        // The chips are what a short cell gives up first.
        final chips = bounded ? _chipRows(room) : _maxRows;
        final running = state == SceneState.running;
        final top = _topRow();
        final texts = _textBlock();
        final settings = this.settings.take(4).toList();
        final children = <Widget>[
          if (running && chips > 0 && settings.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.cardContentGap,
              children: [top, texts],
            )
          else ...[
            top,
            texts,
          ],
          if (chips > 0 && settings.isNotEmpty)
            _Settings(settings, rows: chips, ink: tone.ink),
        ];
        return GlowSurface(
          color: tone.wash ?? AppColors.surfaceRaised,
          // `Highlight` at the top left and `Ambient glow` past the right
          // edge, as the Figma scene card draws them.
          glows: [
            Glow(
              left: -80,
              top: -120,
              size: 260,
              color: AppColors.surfaceRaised.withValues(alpha: 0.9),
            ),
            Glow.fromRight(
              right: -60,
              top: 60,
              size: 360,
              color: tone.accent.withValues(alpha: 0.6),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: bounded ? 0 : AppSpacing.cardContentGap,
            children: children,
          ),
        );
      },
    );
  }

  static const int _maxRows = 2;

  /// How many rows of chips the room under the top row and the text leaves.
  int _chipRows(double room) {
    const gap = AppSpacing.s2;
    final left = room - _top - _texts - AppSpacing.cardContentGap;
    if (left < AppSpacing.chipHeight) return 0;
    final rows = ((left + gap) / (AppSpacing.chipHeight + gap)).floor();
    return rows.clamp(0, _maxRows);
  }

  Widget _topRow() {
    final running = state == SceneState.running;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconTile(
          icon: AppIcons.byName(icon),
          background: AppColors.overlayOnTint,
          color: tone.ink,
        ),
        const SizedBox(width: AppSpacing.s3),
        if (running)
          StatusTag(
            label: runningLabel,
            dot: tone.accent,
            tint: AppColors.overlayOnTint,
            ink: tone.ink,
          )
        else
          Flexible(
            child: ActionPill(
              label: actionLabel,
              icon: 'play',
              style: ActionPillStyle.primary,
              iconColor: tone.accent,
              horizontalPadding: 24,
              onPressed: onRun,
            ),
          ),
      ],
    );
  }

  Widget _textBlock() {
    final description = this.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.s1,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleSmall.copyWith(color: tone.ink),
        ),
        if (description != null)
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(color: tone.ink),
          ),
      ],
    );
  }
}

/// The setting chips, in at most [rows] whole rows.
class _Settings extends StatelessWidget {
  const _Settings(this.settings, {required this.rows, required this.ink});

  final List<String> settings;
  final int rows;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    const gap = AppSpacing.s2;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: rows * (AppSpacing.chipHeight + gap) - gap,
      ),
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        clipBehavior: Clip.hardEdge,
        children: [
          for (final setting in settings) _Setting(setting, ink: ink),
        ],
      ),
    );
  }
}

/// One setting line of a scene.
class _Setting extends StatelessWidget {
  const _Setting(this.text, {required this.ink});

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.overlayOnTint,
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.pillRadius)),
      ),
      child: SizedBox(
        height: AppSpacing.chipHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.chipPadding,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              text,
              style: AppTypography.labelMedium.copyWith(color: ink),
            ),
          ),
        ),
      ),
    );
  }
}
