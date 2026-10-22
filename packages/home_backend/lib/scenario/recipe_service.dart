import 'package:home_backend/data/mock_database.dart';
import 'package:home_timeline/home_timeline.dart';

/// {@template recipe_service}
/// The mocked recipe plan: tonight's steps and when each one happens.
/// {@endtemplate}
class RecipeService {
  /// {@macro recipe_service}
  ///
  /// Creates a recipe service over the mock database.
  RecipeService(this._database);

  final MockDatabase _database;

  /// Moves every step by [by] and returns what changed.
  Map<String, Object?> shift(Duration by) {
    final day = _database.clock.now;
    final steps = <Map<String, Object?>>[];
    for (final step in _database.recipeSteps) {
      final from = step['at'] as String;
      final to = hhmm(atHhmm(day, from).add(by));
      step['at'] = to;
      steps.add({'id': step['id'], 'from': from, 'to': to});
    }
    return {
      'service': 'recipe',
      'action': 'shift_plan',
      'minutes': by.inMinutes,
      'steps': steps,
    };
  }
}
