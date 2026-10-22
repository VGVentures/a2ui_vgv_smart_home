import 'package:app_ui/src/theme/icon_from_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(iconFromWords, () {
    test('reads the icon from the words', () {
      const expected = {
        'Preheat oven': 'oven',
        'Chill wine': 'wine',
        'Start dining scene': 'scene',
        'Grab the cake Rise Bakery': 'cake',
        'School pickup Lincoln Elementary': 'school',
        'Guests arrive': 'guests',
        'Drive to the airport': 'car',
        'Lock front door': 'lock',
        'Coffee ready': 'coffee',
        'Home Rivera Home': 'home',
        'Something else': 'clock',
      };
      for (final MapEntry(key: text, value: icon) in expected.entries) {
        expect(iconFromWords(text), icon, reason: text);
      }
    });
  });
}
