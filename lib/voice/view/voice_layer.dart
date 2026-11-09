import 'dart:async';

import 'package:a2ui_vgv_smart_home/action_toast/cubit/action_toast_cubit.dart';
import 'package:a2ui_vgv_smart_home/action_toast/view/action_glow.dart';
import 'package:a2ui_vgv_smart_home/action_toast/view/action_toast.dart';
import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:a2ui_vgv_smart_home/voice/cubit/voice_cubit.dart';
import 'package:a2ui_vgv_smart_home/voice/view/voice_input.dart';
import 'package:a2ui_vgv_smart_home/voice/view/voice_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_frontend/home_frontend.dart';

/// {@template voice_layer}
/// Everything that happens on [child] once the user speaks: the card that
/// opens while they talk, the command itself, sent to [controller] as a
/// regular turn, and the [ActionToast] that follows it.
///
/// The toast is the one every request uses, and its state lives in the
/// [ActionToastCubit]: this layer tells it when a command starts and when its
/// turn ends. The dashboard behind is never replaced by a loading state. The
/// toast says something is on its way, and the answer lands where the old one
/// was.
///
/// A command finished while the panel is still answering the last one waits
/// and is sent when it is done, since turns cannot overlap. Needs a
/// [VoiceCubit] and an [ActionToastCubit] above it.
/// {@endtemplate}
class VoiceLayer extends StatefulWidget {
  /// {@macro voice_layer}
  const VoiceLayer({
    required this.controller,
    required this.name,
    required this.collapsedSize,
    required this.child,
    super.key,
  });

  /// The zone that receives the spoken commands as turns.
  final GenUIZoneController controller;

  /// Who is speaking.
  final String name;

  /// The size of the ask bar, where the card opens from.
  final Size collapsedSize;

  /// The content the voice card and the toast are laid over.
  final Widget child;

  @override
  State<VoiceLayer> createState() => _VoiceLayerState();
}

/// Runs one spoken command at a time and waits for the turn it starts to end.
class _VoiceLayerState extends State<VoiceLayer> {
  /// The command in flight, from the end of speech to the answer.
  String? _command;

  /// Counts commands, so a cancelled one does not report when its turn ends.
  int _turn = 0;

  /// Whether [_command] is still waiting for the last turn to end.
  bool _waiting = false;

  final OverlayPortalController _overlay = OverlayPortalController();
  final LayerLink _link = LayerLink();

  GenUIZoneController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _overlay.show();
    _controller.addListener(_onController);
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    super.dispose();
  }

  void _submit(String command) {
    final turn = ++_turn;
    _command = command;
    context.read<ActionToastCubit>().commandStarted(command);
    if (_controller.isSending) {
      _waiting = true;
    } else {
      unawaited(_send(command, turn));
    }
  }

  Future<void> _send(String command, int turn) async {
    final toast = context.read<ActionToastCubit>();
    await _controller.sendMessage(command);
    // A cancelled command already took the pill away.
    if (turn != _turn || _command == null) return;
    _command = null;
    // The controller swallows a failed turn and keeps it as an error item.
    final state = _controller.state;
    toast.commandFinished(
      succeeded:
          state is! GenUIZoneItemsUpdated || state.items.last is! ErrorItem,
    );
  }

  void _onController() {
    final command = _command;
    if (command == null || _controller.isSending || !_waiting) return;
    _waiting = false;
    unawaited(_send(command, _turn));
  }

  void _cancelCommand() {
    // A command still waiting never started, so the turn in flight is not its.
    if (!_waiting) _controller.discardTurn();
    _waiting = false;
    _command = null;
    _turn++;
    context.read<ActionToastCubit>().dismiss();
  }

  Future<void> _explainPermission(BuildContext context) async {
    final cubit = context.read<VoiceCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const MicrophonePermissionDialog(),
    );
    if (confirmed ?? false) {
      await cubit.permissionConfirmed();
    } else {
      cubit.permissionDismissed();
    }
  }

  void _showFailure(BuildContext context, VoiceFailure failure) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (failure) {
          VoiceFailure.microphoneUnavailable => l10n.microphoneUnavailable,
          VoiceFailure.transcriptionFailed => l10n.transcriptionFailed,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VoiceCubit, VoiceState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) => switch (state.status) {
        VoiceStatus.permissionNeeded => unawaited(_explainPermission(context)),
        VoiceStatus.done => _submit(state.text),
        VoiceStatus.failure => _showFailure(context, state.failure!),
        _ => null,
      },
      // The veil, the card, the light and the toast are drawn on the app's
      // overlay, which is the whole screen: the layer itself sits beside the
      // sidebar and inside the screen's margin, so they would stop short of
      // the edges there. The overlay entries below follow this box, so the card
      // and the toast still sit where the ask bar and the suggestions are.
      child: LayoutBuilder(
        builder: (context, constraints) => OverlayPortal(
          controller: _overlay,
          overlayChildBuilder: (_) =>
              _overlayLayer(context, constraints.biggest),
          child: CompositedTransformTarget(
            link: _link,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _overlayLayer(BuildContext context, Size size) {
    final cubit = context.read<VoiceCubit>();
    // Gives the overlay's children the same box as the layer.
    Widget inLayer(Widget child) => CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: size, child: child),
      ),
    );
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          BlocBuilder<VoiceCubit, VoiceState>(
            builder: (context, state) =>
                VoiceScrim(open: _isListening(state.status)),
          ),
          inLayer(
            BlocBuilder<VoiceCubit, VoiceState>(
              builder: (context, state) => VoiceOverlay(
                open: _isListening(state.status),
                collapsedSize: widget.collapsedSize,
                name: widget.name,
                text: state.text,
                levels: state.levels,
                onCancel: cubit.cancel,
                onSend: () => unawaited(cubit.finish()),
              ),
            ),
          ),
          BlocBuilder<ActionToastCubit, ActionToastState>(
            buildWhen: (a, b) => a.status != b.status,
            builder: (context, state) => ActionGlow(status: state.status),
          ),
          // On the line of the suggestions it takes the place of.
          inLayer(
            Align(
              alignment: Alignment.bottomCenter,
              child: BlocBuilder<ActionToastCubit, ActionToastState>(
                builder: (context, state) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.6),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: state.status == ActionToastStatus.idle
                      ? const SizedBox.shrink()
                      : ActionToast(
                          key: const ValueKey('toast'),
                          state: state,
                          onCancel: _cancelCommand,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isListening(VoiceStatus status) => switch (status) {
    VoiceStatus.connecting ||
    VoiceStatus.listening ||
    VoiceStatus.finishing => true,
    _ => false,
  };
}
