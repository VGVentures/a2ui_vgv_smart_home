import 'package:home_api_client/home_api_client.dart';
import 'package:home_repository/src/home_user.dart';

/// {@template users_repository}
/// Where the list of selectable users comes from.
///
/// {@template repository_seam}
/// A seam so tests can run without a backend.
/// {@endtemplate}
/// {@endtemplate}
// ignore: one_member_abstracts
abstract interface class UsersRepository {
  /// Throws if the users cannot be loaded.
  Future<List<HomeUser>> fetchUsers();
}

/// {@template users_request_failed}
/// The backend did not answer the users request with a 200.
/// {@endtemplate}
class UsersRequestFailed implements Exception {
  /// {@macro users_request_failed}
  const UsersRequestFailed(this.message);

  /// What went wrong, with the status the backend answered.
  final String message;

  @override
  String toString() => 'UsersRequestFailed: $message';
}

/// {@template http_users_repository}
/// Reads the users from the backend, from this visitor's own world, over
/// `client`.
/// {@endtemplate}
class HttpUsersRepository implements UsersRepository {
  /// {@macro http_users_repository}
  HttpUsersRepository({required this._client});

  final HomeApiClient _client;

  @override
  Future<List<HomeUser>> fetchUsers() async {
    try {
      return [
        for (final user in await _client.getUsers()) HomeUser.fromJson(user),
      ];
    } on HomeApiException catch (e) {
      throw UsersRequestFailed('Status ${e.statusCode}.');
    }
  }
}
