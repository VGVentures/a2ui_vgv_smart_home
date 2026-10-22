import 'dart:io';

import 'package:home_backend/prompt/system_prompt.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('SystemPrompt.load', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('prompt_test_'));

    tearDown(() => tempDir.deleteSync(recursive: true));

    File asset(String name, String body) =>
        File('${tempDir.path}/$name')..writeAsStringSync(body);

    test('renders the shipped assets into one message', () async {
      final prompt = await SystemPrompt.load(homeCatalog);

      expect(prompt.text, contains(homeCatalog.id));
      expect(prompt.text, contains('MUST be A2UI JSON'));
      // The version in the examples is the one constant, not a copy of it.
      expect(prompt.text, contains('"version": "$a2uiVersion"'));
      expect(prompt.text, isNot(contains('{{')));
      for (final name in homeCatalog.components.keys) {
        expect(prompt.text, contains('`$name`'));
      }
    });

    test(
      'joins the A2UI, layout, catalog and system prompts in that order',
      () async {
        asset('a2ui-prompt.prompt', '---\n---\nMECHANICS');
        asset('layout.prompt', '---\n---\nLAYOUT {{{cardFits}}}');
        asset('system-prompt.prompt', '---\n---\nPERSONA for {{{catalogId}}}');

        final prompt = await SystemPrompt.load(
          homeCatalog,
          assetDirectory: tempDir.path,
        );

        final mechanics = prompt.text.indexOf('MECHANICS');
        final persona = prompt.text.indexOf(
          'PERSONA for ${homeCatalog.id}',
        );
        final layout = prompt.text.indexOf('LAYOUT');
        expect(mechanics, 0);
        expect(layout, greaterThan(mechanics));
        expect(persona, greaterThan(layout));
        expect(prompt.text, contains('`DeviceCard`'));
      },
    );

    test('leaves out a system prompt that renders empty', () async {
      asset('a2ui-prompt.prompt', '---\n---\nMECHANICS');
      asset('layout.prompt', '---\n---\nLAYOUT {{{cardFits}}}');
      asset('system-prompt.prompt', '---\n---\n   ');

      final prompt = await SystemPrompt.load(
        homeCatalog,
        assetDirectory: tempDir.path,
      );

      expect(prompt.text, isNot(endsWith('\n')));
      expect(prompt.text, startsWith('MECHANICS'));
    });

    test('throws when an asset is missing', () {
      expect(
        () => SystemPrompt.load(homeCatalog, assetDirectory: tempDir.path),
        throwsStateError,
      );
    });
  });
}
