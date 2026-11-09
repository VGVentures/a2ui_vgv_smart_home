import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:home_frontend/home_frontend.dart';

/// {@template action_toast_status}
/// The stages of an action's toast.
/// {@endtemplate}
enum ActionToastStatus {
  /// No request is on its way, and the toast is away.
  idle,

  /// A request is on its way.
  loading,

  /// The request succeeded.
  success,

  /// The request failed.
  error,
}

/// {@template action_toast_state}
/// What the toast shows: its status, label, the reason a failure gives, and
/// whether it can be cancelled.
/// {@endtemplate}
class ActionToastState extends Equatable {
  /// {@macro action_toast_state}
  const ActionToastState({
    this.status = ActionToastStatus.idle,
    this.label = '',
    this.reason,
    this.cancellable = false,
  });

  /// Where the request stands.
  final ActionToastStatus status;

  /// What the user asked for: the action's label, or the spoken command. The
  /// same text in every state.
  final String label;

  /// A short line saying why it failed. Null means the generic one. Set only
  /// with [ActionToastStatus.error].
  final String? reason;

  /// Whether the user can still take the request back. Only a spoken or typed
  /// command can be: a press on the surface is already on its way.
  final bool cancellable;

  @override
  List<Object?> get props => [status, label, reason, cancellable];
}

/// {@template action_toast_cubit}
/// The one pill that follows every request from the press to the answer.
///
/// A press on the surface arrives as a [UiInteractionAdded] and ends with a
/// [UiInteractionCompleted] on the agent's event stream. A spoken or typed
/// command is announced by the view with [commandStarted] and [commandFinished]
/// because the turn that runs it belongs to the zone controller, which knows
/// how it ended.
///
/// Success is held for 1.5 s and failure for 3 s by default, then the
/// pill goes back to idle.
/// {@endtemplate}
class ActionToastCubit extends Cubit<ActionToastState> {
  /// {@macro action_toast_cubit}
  ActionToastCubit({
    required Stream<GenUIAgentEvent> events,
    this._successHold = const Duration(milliseconds: 1500),
    this._errorHold = const Duration(seconds: 3),
  }) : super(const ActionToastState()) {
    _events = events.listen(_onEvent);
  }

  final Duration _successHold;
  final Duration _errorHold;

  late final StreamSubscription<GenUIAgentEvent> _events;
  Timer? _hold;

  void _onEvent(GenUIAgentEvent event) {
    switch (event) {
      case UiInteractionAdded(:final label):
        _loading(label, cancellable: false);
      case UiInteractionCompleted(:final succeeded, :final reason):
        if (state.status == ActionToastStatus.loading) {
          if (succeeded) {
            _succeed();
          } else {
            _fail(reason);
          }
        }
      case _:
        break;
    }
  }

  /// A spoken or typed [command] was accepted and will be sent.
  void commandStarted(String command) {
    _loading(command, cancellable: true);
  }

  /// The turn of the last [commandStarted] ended, [succeeded] or not.
  void commandFinished({required bool succeeded}) {
    if (state.status != ActionToastStatus.loading) return;
    if (succeeded) {
      _succeed();
    } else {
      _fail(null);
    }
  }

  /// Takes the pill away at once, as when the user cancels the command.
  void dismiss() {
    _hold?.cancel();
    emit(const ActionToastState());
  }

  void _loading(String label, {required bool cancellable}) {
    _hold?.cancel();
    emit(
      ActionToastState(
        status: ActionToastStatus.loading,
        label: label,
        cancellable: cancellable,
      ),
    );
  }

  void _succeed() => _finish(
    ActionToastState(status: ActionToastStatus.success, label: state.label),
    _successHold,
  );

  void _fail(String? reason) => _finish(
    ActionToastState(
      status: ActionToastStatus.error,
      label: state.label,
      reason: reason,
    ),
    _errorHold,
  );

  void _finish(ActionToastState next, Duration hold) {
    _hold?.cancel();
    emit(next);
    _hold = Timer(hold, () => emit(const ActionToastState()));
  }

  @override
  Future<void> close() async {
    _hold?.cancel();
    await _events.cancel();
    return super.close();
  }
}
