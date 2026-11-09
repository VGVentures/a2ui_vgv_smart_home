import 'dart:async';

import 'package:a2ui_vgv_smart_home/action_toast/cubit/action_toast_cubit.dart';
import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/clock/view/clock_view.dart';
import 'package:a2ui_vgv_smart_home/dashboard/agent_factory.dart';
import 'package:a2ui_vgv_smart_home/dashboard/view/dashboard_surface.dart';
import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:a2ui_vgv_smart_home/live/cubit/live_cubit.dart';
import 'package:a2ui_vgv_smart_home/timeline/cubit/timeline_cubit.dart';
import 'package:a2ui_vgv_smart_home/voice/cubit/voice_cubit.dart';
import 'package:a2ui_vgv_smart_home/voice/microphone.dart';
import 'package:a2ui_vgv_smart_home/voice/transcription_client.dart';
import 'package:a2ui_vgv_smart_home/voice/view/voice_input.dart';
import 'package:a2ui_vgv_smart_home/voice/view/voice_layer.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_repository/home_repository.dart';

/// {@template member_dashboard}
/// One user's generated dashboard: the brand and ask bar above the surface,
/// the clock in its bottom-left corner beside the chips row, and the voice
/// layer over all of it.
///
/// Owns a fresh agent, controller and voice input. The parent keys this widget
/// by user, so switching user disposes this state and builds a new one, which
/// sends the request again and drops any command still being spoken.
///
/// When the data behind the dashboard changes (the time settled, or the
/// backend pushed a change for this user) it asks the agent to refresh.
///
/// {@macro dashboard_in_place_update}
///
/// The agent decides whether the answer still matters: a refresh that fails
/// leaves the surface where it is, triggers that arrive while one runs are
/// folded into one more, and one that meets a press or a spoken command is
/// dropped, because that turn is answered from fresh data already.
///
/// A jump of the time is different: the surface of the time left behind would
/// be wrong, so the moment the time moves it is replaced by a skeleton, and the
/// new dashboard is asked for once the backend has the clock there.
/// {@endtemplate}
class MemberDashboard extends StatefulWidget {
  /// {@macro member_dashboard}
  const MemberDashboard({
    required this.user,
    required this.agentFactory,
    super.key,
  });

  /// The user whose dashboard is generated.
  final HomeUser user;

  /// Builds the agent that generates the dashboard.
  final AgentFactory agentFactory;

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

/// An agent and the controller that drives it.
class _Session {
  _Session(this.agent) : controller = GenUIZoneController(agent: agent);

  final GenUIAgent agent;
  final GenUIZoneController controller;

  void dispose() {
    controller.dispose();
    agent.dispose();
  }
}

/// Owns the sessions of one user's dashboard: the one on screen and the ones
/// still fading out.
class _MemberDashboardState extends State<MemberDashboard> {
  static const double _barHeight = 80;
  static const double _askWidth = 634;

  /// How long a replaced session lives on, while its surface fades out.
  static const _fade = Duration(milliseconds: 400);

  /// The session on screen.
  late _Session _shown;

  /// Sessions that were replaced and have not been disposed yet, with the
  /// timer that disposes each.
  final _retired = <_Session, Timer>{};

  /// Whether the session on screen is a skeleton still waiting for the time
  /// to settle before it asks.
  bool _awaitingTime = false;

  late final GeminiKeyStore _keys;
  late final StreamSubscription<void> _keySub;
  late final StreamSubscription<Map<String, Object?>> _messageSub;

  /// Whether the session on screen is a skeleton still waiting for the person
  /// to enter their key, which the app asks for as it opens.
  bool _awaitingKey = false;

  @override
  void initState() {
    super.initState();
    _keys = context.read<GeminiKeyStore>();
    _keySub = _keys.saved.listen((_) => _keySaved());
    // What the backend sends to the dashboard on screen, such as a device
    // that changed, moves the surface in place.
    _messageSub = context.read<LiveCubit>().surfaceMessages.listen(
      (message) => _shown.agent.apply(message),
    );
    _shown = _Session(widget.agentFactory.create(widget.user));
    unawaited(_load(_shown));
  }

  /// The key was saved: asks for what was waiting for it.
  void _keySaved() {
    if (!_awaitingKey || !_keys.hasKey) return;
    _awaitingKey = false;
    unawaited(_loadQuietly(_shown));
  }

  Future<void> _load(_Session session) async {
    // Without a key every request would be refused. The skeleton stays up
    // while the key is asked for, and the dashboard is asked for the moment
    // it is saved.
    if (!_keys.hasKey) {
      _awaitingKey = true;
      return;
    }
    try {
      await session.controller.start();
      await session.controller.sendMessage(widget.user.prompt);
    } on Object {
      // Failed turns reach the zone as an ErrorItem. What lands here is the
      // agent's stream closing because the user was switched mid request.
      if (mounted) rethrow;
    }
  }

  /// Puts a skeleton where the surface is, to be asked for when the time
  /// settles.
  void _showSkeleton() {
    final previous = _shown;
    setState(() => _shown = _Session(widget.agentFactory.create(widget.user)));
    _awaitingTime = true;
    _retire(previous);
  }

  /// Disposes [session] once its surface has faded out.
  void _retire(_Session session) {
    _retired[session] = Timer(_fade, () {
      _retired.remove(session);
      session.dispose();
    });
  }

  /// The time settled: asks for the skeleton's dashboard, or, when the time
  /// did not jump, for the one on screen to refresh in place.
  void _timeSettled() {
    if (!_awaitingTime) return unawaited(_refresh());
    _awaitingTime = false;
    unawaited(_loadQuietly(_shown));
  }

  /// [_load], leaving the skeleton on screen when the request breaks.
  Future<void> _loadQuietly(_Session session) async {
    try {
      await _load(session);
    } on Object {
      // Nothing to swap in, and nothing to show but the skeleton.
    }
  }

  /// Asks the session on screen to refresh its surface in place.
  Future<void> _refresh() async {
    // The skeleton asks for itself once the time settles, or the key is saved.
    if (_awaitingTime || _awaitingKey) return;
    try {
      await _shown.agent.refresh(widget.user.prompt);
    } on Object {
      // The surface on screen stays; there is nothing to swap in.
    }
  }

  @override
  void dispose() {
    unawaited(_keySub.cancel());
    unawaited(_messageSub.cancel());
    _shown.dispose();
    _retired.forEach((session, timer) {
      timer.cancel();
      session.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _shown;
    return MultiBlocListener(
      listeners: [
        BlocListener<TimelineCubit, TimelineState>(
          listenWhen: (previous, current) => !previous.moving && current.moving,
          listener: (context, _) => _showSkeleton(),
        ),
        BlocListener<TimelineCubit, TimelineState>(
          listenWhen: (previous, current) =>
              previous.revision != current.revision,
          listener: (context, _) => _timeSettled(),
        ),
        BlocListener<LiveCubit, LiveState>(
          listenWhen: (previous, current) =>
              previous.refreshes[widget.user.id] !=
              current.refreshes[widget.user.id],
          listener: (context, _) => unawaited(_refresh()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => VoiceCubit(
              microphone: context.read<Microphone>(),
              client: context.read<TranscriptionClient>(),
            ),
          ),
          BlocProvider(
            key: ObjectKey(session),
            create: (_) => ActionToastCubit(events: session.agent.events),
          ),
        ],
        child: VoiceLayer(
          controller: session.controller,
          name: widget.user.name,
          collapsedSize: const Size(_askWidth, _barHeight),
          child: Column(
            spacing: AppSpacing.gutter,
            children: [
              SizedBox(
                height: _barHeight,
                child: Row(
                  children: [
                    BrandLockup(semanticLabel: context.l10n.brandLabel),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _askWidth,
                          ),
                          child: VoiceInput(
                            hint: context.l10n.askHint(widget.user.name),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DashboardSurface(controller: session.controller),
                    // The chips row lines up on the right, so the clock sits
                    // in the space it leaves on the left.
                    const Align(
                      alignment: Alignment.bottomLeft,
                      child: ClockView(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
