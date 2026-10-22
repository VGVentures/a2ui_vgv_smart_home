import 'dart:math';

import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/api_key/view/api_key_gate.dart';
import 'package:a2ui_vgv_smart_home/dashboard/agent_factory.dart';
import 'package:a2ui_vgv_smart_home/dashboard/view/dashboard_page.dart';
import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:a2ui_vgv_smart_home/live/cubit/live_cubit.dart';
import 'package:a2ui_vgv_smart_home/shell/device_frame.dart';
import 'package:a2ui_vgv_smart_home/timeline/cubit/timeline_cubit.dart';
import 'package:a2ui_vgv_smart_home/timeline/day_phase.dart';
import 'package:a2ui_vgv_smart_home/timeline/view/timeline_bar.dart';
import 'package:a2ui_vgv_smart_home/voice/microphone.dart';
import 'package:a2ui_vgv_smart_home/voice/transcription_client.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_repository/home_repository.dart';

/// The room the timeline bar needs below the tablet, and above it to match.
///
/// Enough for the bar with its error line above the pill, the tallest it gets.
const double _timelineSlot = 112;

/// {@template app}
/// The page around the demo: a tablet frame holding the actual application.
/// {@endtemplate}
class App extends StatelessWidget {
  /// {@macro app}
  const App({
    required this.agentFactory,
    required this.keys,
    required this.usersRepository,
    required this.scenarioRepository,
    required this.liveRepository,
    required this.microphone,
    required this.transcriptionClient,
    super.key,
  });

  /// Builds the agent of each user's dashboard.
  final AgentFactory agentFactory;

  /// Holds the person's own Gemini API key.
  final GeminiKeyStore keys;

  /// Where the household's members come from.
  final UsersRepository usersRepository;

  /// Where the scenario's timeline comes from.
  final ScenarioRepository scenarioRepository;

  /// Where the live updates of the home come from.
  final LiveRepository liveRepository;

  /// Captures the voice commands' audio.
  final Microphone microphone;

  /// Turns the voice commands' audio into text.
  final TranscriptionClient transcriptionClient;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<GeminiKeyStore>.value(value: keys),
        RepositoryProvider<AgentFactory>.value(value: agentFactory),
        RepositoryProvider<UsersRepository>.value(value: usersRepository),
        RepositoryProvider<ScenarioRepository>.value(value: scenarioRepository),
        RepositoryProvider<LiveRepository>.value(value: liveRepository),
        RepositoryProvider<Microphone>.value(value: microphone),
        RepositoryProvider<TranscriptionClient>.value(
          value: transcriptionClient,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LiveCubit(repository: liveRepository)),
          BlocProvider(
            create: (_) => TimelineCubit(
              repository: scenarioRepository,
              live: liveRepository,
              autoPlay: true,
            ),
          ),
        ],
        child: MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          // The timeline control sits below the tablet, outside its screen.
          builder: (context, child) => ColoredBox(
            color: AppColors.bezel,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _Backdrop(),
                // The tablet is centered in the window, and the timeline bar
                // is centered in the gap between the tablet and the window's
                // bottom edge. The tablet leaves room for the bar on both
                // sides, so the two gaps match.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final frameHeight = [
                      DeviceFrame.maxHeight,
                      constraints.maxWidth *
                          DeviceFrame.maxHeight /
                          DeviceFrame.maxWidth,
                      constraints.maxHeight - 2 * _timelineSlot,
                    ].reduce(min).clamp(0, double.infinity).toDouble();
                    return Column(
                      children: [
                        const Spacer(),
                        SizedBox(
                          height: frameHeight,
                          child: DeviceFrame(child: child!),
                        ),
                        const Expanded(child: Center(child: TimelineBar())),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          home: const ApiKeyGate(child: DashboardPage()),
        ),
      ),
    );
  }
}

/// The kitchen behind the tablet, in the light of the time on the timeline.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final light = context.select<TimelineCubit, KitchenLight>(
      (cubit) => DayPhase.at(cubit.state.now).light,
    );
    return KitchenBackdrop(light: light);
  }
}
