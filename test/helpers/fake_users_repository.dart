import 'dart:async';

import 'package:home_repository/home_repository.dart';

const ana = HomeUser(id: 'ana', name: 'Ana', role: 'host');
const marco = HomeUser(id: 'marco', name: 'Marco', role: 'logistics');

class FakeUsersRepository implements UsersRepository {
  FakeUsersRepository({
    this.users = const [ana, marco],
    this.failures = 0,
    this.gate,
  });

  final List<HomeUser> users;

  /// How many calls throw before one succeeds.
  int failures;

  /// Holds the request open until completed.
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<List<HomeUser>> fetchUsers() async {
    calls++;
    await gate?.future;
    if (failures > 0) {
      failures--;
      throw const UsersRequestFailed('boom');
    }
    return users;
  }
}
