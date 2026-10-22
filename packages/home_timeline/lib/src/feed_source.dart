/// {@template feed_source}
/// What the activity feed reads. The backend's mock database implements it.
///
/// Each list holds the JSON maps as the data files describe them. The feed
/// never writes to them.
/// {@endtemplate}
abstract interface class FeedSource {
  /// The scenario clock, as a naive local time.
  DateTime get now;

  /// The name of [userId]. Throws when there is no such user.
  String userName(String userId);

  /// The device with [id], or `null`.
  Map<String, dynamic>? device(String id);

  /// The steps of the recipe plan.
  List<Map<String, dynamic>> get recipeSteps;

  /// The to-do lists.
  List<Map<String, dynamic>> get todoLists;

  /// The bakery orders.
  List<Map<String, dynamic>> get orders;

  /// The messages the bakery was sent.
  List<Map<String, dynamic>> get bakeryMessages;

  /// The trips.
  List<Map<String, dynamic>> get trips;

  /// The calendar events.
  List<Map<String, dynamic>> get calendarEvents;

  /// The people [event] is assigned to.
  List<String> assigneesOf(Map<String, dynamic> event);

  /// The notifications people sent each other.
  List<Map<String, dynamic>> get inboxItems;
}
