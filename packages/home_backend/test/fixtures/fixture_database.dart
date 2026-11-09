import 'package:home_backend/data/mock_database.dart';

/// The demo's first mock data, before it was trimmed to the event timeline:
/// every kind of device the state machine and the validators know, three users
/// and a six-item shopping list.
///
/// Tests of the machinery (commands, validation, the reply format) use it so
/// they keep covering every trait whatever the shipped demo contains. Tests of
/// the shipped data load `data/` itself.
Future<MockDatabase> loadFixtureDatabase() =>
    MockDatabase.load(directory: 'test/fixtures/data');
