import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeminiKeyStore', () {
    test('has no key until one is saved', () async {
      final keys = GeminiKeyStore();

      expect(keys.hasKey, isFalse);
      expect(keys.key, isNull);
      expect(await keys.token(), isNull);
    });

    test('keeps a saved key without the whitespace around it', () async {
      final keys = GeminiKeyStore()..save('  AIza-key \n');

      expect(keys.hasKey, isTrue);
      expect(keys.key, 'AIza-key');
      expect(await keys.token(), 'AIza-key');
    });

    test('replaces an earlier key', () {
      final keys = GeminiKeyStore('old')..save('new');

      expect(keys.key, 'new');
    });

    test('tells its listeners each time a key is saved', () {
      final keys = GeminiKeyStore();
      var saved = 0;
      final sub = keys.saved.listen((_) => saved++);
      addTearDown(sub.cancel);

      keys
        ..save('one')
        ..save('two');

      expect(saved, 2);
    });

    test('can start with a key', () {
      expect(GeminiKeyStore('given').key, 'given');
    });
  });
}
