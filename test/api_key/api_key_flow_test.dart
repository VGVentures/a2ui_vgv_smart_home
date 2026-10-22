import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/api_key/view/api_key_dialog.dart';
import 'package:a2ui_vgv_smart_home/dashboard/view/dashboard_page.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_repository/home_repository.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../helpers/fake_agent.dart';
import '../helpers/helpers.dart';

class _FakeUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final launched = <String>[];

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder get _field => find.descendant(
  of: find.byType(ApiKeyDialog),
  matching: find.byType(TextField),
);

Finder get _cancel => find.descendant(
  of: find.byType(ApiKeyDialog),
  matching: find.byType(TextButton),
);

Finder get _continue => find.descendant(
  of: find.byType(ApiKeyDialog),
  matching: find.byType(FilledButton),
);

void main() {
  group('Gemini key popup', () {
    testWidgets('opens over the dashboard when the app first opens', (
      tester,
    ) async {
      await tester.pumpApp(FakeAgentFactory(), keys: GeminiKeyStore());
      await _settle(tester);

      expect(find.byType(ApiKeyDialog), findsOneWidget);
      expect(find.byType(DashboardPage), findsOneWidget);
    });

    testWidgets('does not open when a key is already held', (tester) async {
      await tester.pumpApp(FakeAgentFactory());
      await _settle(tester);

      expect(find.byType(ApiKeyDialog), findsNothing);
    });

    testWidgets('links to Google AI Studio to get a key', (tester) async {
      final launcher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
      await tester.pumpApp(FakeAgentFactory(), keys: GeminiKeyStore());
      await _settle(tester);

      await tester.tap(find.text('Get a key at aistudio.google.com/apikey'));
      await tester.pump();

      expect(launcher.launched, ['https://aistudio.google.com/apikey']);
    });

    testWidgets('hides what is typed', (tester) async {
      await tester.pumpApp(FakeAgentFactory(), keys: GeminiKeyStore());
      await _settle(tester);

      expect(tester.widget<TextField>(_field).obscureText, isTrue);
    });

    testWidgets('cannot continue without a key', (tester) async {
      await tester.pumpApp(FakeAgentFactory(), keys: GeminiKeyStore());
      await _settle(tester);

      expect(tester.widget<FilledButton>(_continue).onPressed, isNull);

      await tester.enterText(_field, '   ');
      await tester.pump();

      expect(tester.widget<FilledButton>(_continue).onPressed, isNull);
    });

    testWidgets('cannot be cancelled or dismissed on first open', (
      tester,
    ) async {
      await tester.pumpApp(FakeAgentFactory(), keys: GeminiKeyStore());
      await _settle(tester);

      expect(_cancel, findsNothing);

      await tester.tapAt(const Offset(2, 2));
      await _settle(tester);

      expect(find.byType(ApiKeyDialog), findsOneWidget);
    });

    testWidgets('keeps the key that is entered and closes', (tester) async {
      final keys = GeminiKeyStore();
      await tester.pumpApp(FakeAgentFactory(), keys: keys);
      await _settle(tester);

      await tester.enterText(_field, ' AIza-mine ');
      await tester.pump();
      await tester.tap(_continue);
      await _settle(tester);

      expect(keys.key, 'AIza-mine');
      expect(find.byType(ApiKeyDialog), findsNothing);
    });

    testWidgets('submitting from the keyboard keeps the key', (tester) async {
      final keys = GeminiKeyStore();
      await tester.pumpApp(FakeAgentFactory(), keys: keys);
      await _settle(tester);

      await tester.enterText(_field, 'AIza-mine');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);

      expect(keys.key, 'AIza-mine');
      expect(find.byType(ApiKeyDialog), findsNothing);
    });

    testWidgets('submitting an empty field keeps nothing', (tester) async {
      final keys = GeminiKeyStore();
      await tester.pumpApp(FakeAgentFactory(), keys: keys);
      await _settle(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);

      expect(keys.hasKey, isFalse);
      expect(find.byType(ApiKeyDialog), findsOneWidget);
    });
  });

  group('the first dashboard', () {
    testWidgets('shows the skeleton and asks for nothing while the popup is '
        'open', (tester) async {
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, keys: GeminiKeyStore());
      await _settle(tester);

      expect(find.byType(ApiKeyDialog), findsOneWidget);
      expect(find.byType(SkeletonSurface), findsOneWidget);
      expect(find.text('Could not build the dashboard.'), findsNothing);
      expect(factory.agents.single.sent, isEmpty);
    });

    testWidgets('loads the moment the key is saved and the popup closes', (
      tester,
    ) async {
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, keys: GeminiKeyStore());
      await _settle(tester);

      await tester.enterText(_field, 'AIza-mine');
      await tester.pump();
      await tester.tap(_continue);
      await _settle(tester);

      expect(find.byType(ApiKeyDialog), findsNothing);
      expect(factory.agents.single.sent, [ana.prompt]);
      expect(find.byType(Surface), findsOneWidget);
      expect(find.byType(SkeletonSurface), findsNothing);
    });

    testWidgets('asks once, however many keys are saved after', (tester) async {
      final keys = GeminiKeyStore();
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, keys: keys);
      await _settle(tester);

      keys
        ..save('one')
        ..save('two');
      await _settle(tester);

      expect(factory.agents.single.sent, [ana.prompt]);
    });

    testWidgets('does not refresh a dashboard that has not been asked for', (
      tester,
    ) async {
      final live = FakeLiveRepository();
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(
        factory,
        keys: GeminiKeyStore(),
        liveRepository: live,
      );
      await _settle(tester);

      live.emit(const DataChanged(users: ['ana']));
      await _settle(tester);

      expect(factory.agents.single.refreshed, isEmpty);
      expect(factory.agents.single.sent, isEmpty);
    });

    testWidgets('waits for the key when the time jumps before it is entered', (
      tester,
    ) async {
      final keys = GeminiKeyStore();
      final live = FakeLiveRepository(answers: false);
      final factory = FakeAgentFactory(emitSurface: true);
      await tester.pumpApp(factory, keys: keys, liveRepository: live);
      await _settle(tester);

      await tester.tap(
        find.ancestor(
          of: find.text('Day'),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump();

      // The time settled and the new dashboard is due, but there is no key.
      expect(factory.agents.last.sent, isEmpty);

      keys.save('late');
      await _settle(tester);

      expect(factory.agents.last.sent, [ana.prompt]);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('changing the key', () {
    testWidgets('the settings button reopens the popup', (tester) async {
      await tester.pumpApp(FakeAgentFactory());

      await tester.tap(find.byIcon(Symbols.settings_rounded));
      await _settle(tester);

      expect(find.byType(ApiKeyDialog), findsOneWidget);
    });

    testWidgets('a new key replaces the old one', (tester) async {
      final keys = GeminiKeyStore('old');
      await tester.pumpApp(FakeAgentFactory(), keys: keys);

      await tester.tap(find.byIcon(Symbols.settings_rounded));
      await _settle(tester);
      await tester.enterText(_field, 'new');
      await tester.pump();
      await tester.tap(_continue);
      await _settle(tester);

      expect(keys.key, 'new');
    });

    testWidgets('cancelling leaves the key as it was', (tester) async {
      final keys = GeminiKeyStore('old');
      await tester.pumpApp(FakeAgentFactory(), keys: keys);

      await tester.tap(find.byIcon(Symbols.settings_rounded));
      await _settle(tester);
      await tester.enterText(_field, 'new');
      await tester.tap(_cancel);
      await _settle(tester);

      expect(keys.key, 'old');
      expect(find.byType(ApiKeyDialog), findsNothing);
    });
  });
}
