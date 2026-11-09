import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:home_repository/home_repository.dart';

/// {@template users_status}
/// Whether the users are loading, loaded or failed to load.
/// {@endtemplate}
enum UsersStatus {
  /// The users are being fetched.
  loading,

  /// The users arrived.
  loaded,

  /// The users could not be fetched, or there were none.
  failure,
}

/// {@template users_state}
/// The users, which one is selected, and whether they have loaded.
/// {@endtemplate}
class UsersState extends Equatable {
  /// {@macro users_state}
  const UsersState({
    this.status = UsersStatus.loading,
    this.users = const [],
    this.selected,
  });

  /// Whether the users have loaded.
  final UsersStatus status;

  /// The household's members.
  final List<HomeUser> users;

  /// The user whose dashboard is on screen. Null until users are loaded.
  final HomeUser? selected;

  @override
  List<Object?> get props => [status, users, selected];
}

/// {@template users_cubit}
/// Loads the users from the backend and tracks whose dashboard is on screen.
/// {@endtemplate}
class UsersCubit extends Cubit<UsersState> {
  /// {@macro users_cubit}
  UsersCubit({required this._repository}) : super(const UsersState());

  final UsersRepository _repository;

  /// Fetches the users and selects the first one, or fails when there are none.
  Future<void> load() async {
    emit(const UsersState());
    try {
      final users = await _repository.fetchUsers();
      if (users.isEmpty) {
        emit(const UsersState(status: UsersStatus.failure));
        return;
      }
      emit(
        UsersState(
          status: UsersStatus.loaded,
          users: users,
          selected: users.first,
        ),
      );
    } on Object {
      emit(const UsersState(status: UsersStatus.failure));
    }
  }

  /// Goes back to the first user, as the demo does when it starts over.
  void selectFirst() {
    if (state.users.isNotEmpty) select(state.users.first);
  }

  /// Puts [user]'s dashboard on screen.
  void select(HomeUser user) => emit(
    UsersState(status: UsersStatus.loaded, users: state.users, selected: user),
  );
}
