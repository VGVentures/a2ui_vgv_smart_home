/// The icon name that fits [text], for an entry or a stop whose sender named
/// none, read from its words. Falls back to `clock`.
///
/// The names are the ones `AppIcons` knows.
String iconFromWords(String text) {
  final words = text.toLowerCase();
  bool has(List<String> any) => any.any(words.contains);
  if (has(['oven', 'preheat', 'roast', 'baking'])) return 'oven';
  if (has(['wine', 'drink', 'chill'])) return 'wine';
  if (has(['scene', 'light', 'music', 'lamp'])) return 'scene';
  if (has(['cake', 'bakery', 'marco'])) return 'cake';
  if (has(['school', 'lesson', 'pickup', 'pick up', 'class'])) return 'school';
  if (has(['guest', 'serve', 'dinner', 'arrive', 'people'])) return 'guests';
  if (has(['car', 'charge', 'drive', 'leave'])) return 'car';
  if (has(['lock', 'door', 'garage'])) return 'lock';
  if (has(['coffee'])) return 'coffee';
  if (has(['home', 'house'])) return 'home';
  return 'clock';
}
