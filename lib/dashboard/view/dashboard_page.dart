import 'dart:async';

import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/api_key/view/api_key_dialog.dart';
import 'package:a2ui_vgv_smart_home/dashboard/agent_factory.dart';
import 'package:a2ui_vgv_smart_home/dashboard/view/member_dashboard.dart';
import 'package:a2ui_vgv_smart_home/l10n/l10n.dart';
import 'package:a2ui_vgv_smart_home/live/cubit/live_cubit.dart';
import 'package:a2ui_vgv_smart_home/timeline/cubit/timeline_cubit.dart';
import 'package:a2ui_vgv_smart_home/users/cubit/users_cubit.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_repository/home_repository.dart';

/// {@template dashboard_page}
/// The dashboard. Starting it starts the demo over, so the panel always
/// begins on Saturday at 7:30 AM with the backend in its first state.
/// {@endtemplate}
class DashboardPage extends StatefulWidget {
  /// {@macro dashboard_page}
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

/// Connects the live socket and resets the demo when the page opens, and
/// disconnects when it closes.
class _DashboardPageState extends State<DashboardPage> {
  late final LiveCubit _live;

  @override
  void initState() {
    super.initState();
    _live = context.read<LiveCubit>();
    unawaited(_live.connect());
    unawaited(context.read<TimelineCubit>().reset());
  }

  @override
  void dispose() {
    unawaited(_live.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = UsersCubit(
          repository: context.read<UsersRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: Builder(
        builder: (context) {
          final now = context.select<TimelineCubit, DateTime>(
            (cubit) => cubit.state.now,
          );
          // A wall time in the local fields: the model's times are compared as
          // wall times too, so the countdown is right in any time zone.
          final wall = DateTime(
            now.year,
            now.month,
            now.day,
            now.hour,
            now.minute,
            now.second,
          );
          return NowScope(now: () => wall, child: const DashboardView());
        },
      ),
    );
  }
}

/// {@template dashboard_view}
/// The whole screen: the sidebar beside the clock, the ask bar and the surface.
/// {@endtemplate}
class DashboardView extends StatelessWidget {
  /// {@macro dashboard_view}
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<UsersCubit>().state;
    final timeline = context.watch<TimelineCubit>().state;
    final status = switch ((state.status, timeline.status)) {
      (UsersStatus.failure, _) ||
      (_, TimelineStatus.failure) => UsersStatus.failure,
      (UsersStatus.loading, _) ||
      (_, TimelineStatus.loading) => UsersStatus.loading,
      _ => UsersStatus.loaded,
    };
    return BlocListener<TimelineCubit, TimelineState>(
      // A reset starts over on the first user, as the demo does.
      listenWhen: (previous, current) => previous.resets != current.resets,
      listener: (context, _) => context.read<UsersCubit>().selectFirst(),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: switch (status) {
            UsersStatus.loading => const SkeletonSurface(),
            UsersStatus.failure => const UsersError(),
            UsersStatus.loaded => Row(
              spacing: AppSpacing.gutter,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Sidebar(
                  profiles: [
                    for (final user in state.users)
                      SidebarProfile(
                        name: user.name,
                        photo: user.photo == null
                            ? null
                            : MemoryImage(user.photo!),
                      ),
                  ],
                  selectedIndex: state.users.indexOf(state.selected!),
                  onProfileSelected: (index) =>
                      context.read<UsersCubit>().select(state.users[index]),
                  onSettings: () => unawaited(
                    showApiKeyDialog(
                      context,
                      keys: context.read<GeminiKeyStore>(),
                      dismissible: true,
                    ),
                  ),
                  settingsTooltip: context.l10n.changeKeyTooltip,
                ),
                Expanded(
                  // Each settled time builds the dashboard again, from the
                  // data the backend holds at that time, behind the one on
                  // screen.
                  child: MemberDashboard(
                    key: ValueKey(state.selected!.id),
                    user: state.selected!,
                    agentFactory: context.read<AgentFactory>(),
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

/// {@template users_error}
/// Shown when the users or the clock cannot be loaded, with a button to try
/// again.
/// {@endtemplate}
class UsersError extends StatelessWidget {
  /// {@macro users_error}
  const UsersError({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.usersLoadFailed, style: AppTypography.body),
          const SizedBox(height: AppSpacing.s4),
          FilledButton(
            onPressed: () {
              unawaited(context.read<UsersCubit>().load());
              unawaited(context.read<TimelineCubit>().reset());
            },
            child: Text(l10n.retryButton),
          ),
        ],
      ),
    );
  }
}
