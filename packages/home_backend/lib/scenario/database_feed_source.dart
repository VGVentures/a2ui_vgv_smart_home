import 'package:home_backend/data/mock_database.dart';
import 'package:home_timeline/home_timeline.dart';

/// {@template database_feed_source}
/// Lets the activity feed read the mock database.
/// {@endtemplate}
class DatabaseFeedSource implements FeedSource {
  /// {@macro database_feed_source}
  ///
  /// Creates a source over [_database].
  const DatabaseFeedSource(this._database);

  final MockDatabase _database;

  @override
  DateTime get now => _database.clock.now;

  @override
  String userName(String userId) =>
      _database.requireUser(userId)['name'] as String;

  @override
  Map<String, dynamic>? device(String id) => _database.deviceOrNull(id);

  @override
  List<Map<String, dynamic>> get recipeSteps => _database.recipeSteps;

  @override
  List<Map<String, dynamic>> get todoLists => _database.todoLists;

  @override
  List<Map<String, dynamic>> get orders =>
      (_database.bakery['orders'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

  @override
  List<Map<String, dynamic>> get bakeryMessages =>
      (_database.bakery['messages'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

  @override
  List<Map<String, dynamic>> get trips => _database.tripRows;

  @override
  List<Map<String, dynamic>> get calendarEvents => _database.calendarEvents;

  @override
  List<String> assigneesOf(Map<String, dynamic> event) =>
      _database.assigneesOf(event);

  @override
  List<Map<String, dynamic>> get inboxItems => _database.inboxItems;
}
