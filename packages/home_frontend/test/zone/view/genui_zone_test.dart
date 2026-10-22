import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_frontend/src/zone/view/genui_zone_view.dart';
import 'package:mocktail/mocktail.dart';

// Stubs ChangeNotifier's protected getter so mocktail does not warn when
// ListenableBuilder calls addListener on the mock.
class _MockGenUIZoneController extends Mock implements GenUIZoneController {
  @override
  bool get hasListeners => false;
}

class _FakeSurfaceController extends Fake implements SurfaceController {}

class _MockSurfaceController extends Mock implements SurfaceController {}

// Renders as an empty surface: a null definition makes `Surface` build a
// `SizedBox.shrink()` without touching the catalog or data model. Mounting the
// real `Surface` over a bare `Fake` would throw `UnimplementedError` on the
// first `surfaceId`/`definition` access.
class _FakeSurfaceContext extends Fake implements SurfaceContext {
  @override
  String get surfaceId => 'fake-surface';

  @override
  final ValueNotifier<SurfaceDefinition?> definition =
      ValueNotifier<SurfaceDefinition?>(null);
}

Widget _pumpView(
  GenUIZoneController controller, {
  GenUISurfaceBuilder? surfaceBuilder,
  GenUIUserMessageBuilder? userMessageBuilder,
  GenUIErrorBuilder? errorBuilder,
  GenUILoadingBuilder? loadingBuilder,
}) {
  return MaterialApp(
    home: Scaffold(
      body: GenUIZoneView(
        controller: controller,
        surfaceBuilder: surfaceBuilder,
        userMessageBuilder: userMessageBuilder,
        errorBuilder: errorBuilder,
        loadingBuilder: loadingBuilder,
      ),
    ),
  );
}

// Captures the `isLatest` flag for each call so locking tests can assert the
// sequence directly. The wrapper gives the surface a fixed height so genui's
// `Surface` (which renders `SizedBox.shrink()` for the fakes used here) still
// materializes inside the lazy `ListView`.
class _SurfaceCallRecorder {
  final List<bool> isLatestFlags = <bool>[];

  Widget builder(
    BuildContext context,
    Widget surface,
    // Matches GenUISurfaceBuilder's positional bool.
    // ignore: avoid_positional_boolean_parameters
    bool isLatest,
  ) {
    isLatestFlags.add(isLatest);
    return SizedBox(height: 24, child: surface);
  }
}

void main() {
  late _MockGenUIZoneController controller;

  setUp(() {
    controller = _MockGenUIZoneController();
    when(() => controller.addListener(any())).thenAnswer((_) {});
    when(() => controller.removeListener(any())).thenAnswer((_) {});
    when(controller.dispose).thenAnswer((_) {});
    when(() => controller.isSending).thenReturn(false);
  });

  group(GenUIZone, () {
    testWidgets('builds a GenUIZoneView wired to the controller', (
      tester,
    ) async {
      when(() => controller.state).thenReturn(const GenUIZoneInitial());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenUIZone.chat(controller: controller)),
        ),
      );

      expect(find.byType(GenUIZoneView), findsOneWidget);
    });

    testWidgets('does not use BlocProvider', (tester) async {
      when(() => controller.state).thenReturn(const GenUIZoneInitial());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenUIZone.chat(controller: controller)),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(GenUIZoneView),
          matching: find.byType(ListenableBuilder),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rebuilds when the controller notifies', (tester) async {
      final realController = _RecordingController();
      addTearDown(realController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GenUIZone.chat(controller: realController)),
        ),
      );
      expect(find.text('boom'), findsNothing);

      realController.emitError('boom');
      await tester.pump();

      expect(find.text('boom'), findsOneWidget);
    });

    testWidgets('forwards surfaceBuilder and userMessageBuilder to the view', (
      tester,
    ) async {
      when(() => controller.state).thenReturn(
        GenUIZoneItemsUpdated(
          controller: _FakeSurfaceController(),
          items: const [UserMessageItem('hi')],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUIZone.chat(
              controller: controller,
              userMessageBuilder: (context, message) =>
                  Text('forwarded:$message'),
            ),
          ),
        ),
      );

      expect(find.text('forwarded:hi'), findsOneWidget);
    });
  });

  group(GenUIZoneView, () {
    group('state rendering', () {
      testWidgets('renders an empty SizedBox on Initial', (tester) async {
        when(() => controller.state).thenReturn(const GenUIZoneInitial());

        await tester.pumpWidget(_pumpView(controller));

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(ListView), findsNothing);
      });

      testWidgets('renders the error text on Error', (tester) async {
        when(
          () => controller.state,
        ).thenReturn(const GenUIZoneError(error: 'something broke'));

        await tester.pumpWidget(_pumpView(controller));

        expect(find.text('something broke'), findsOneWidget);
      });

      testWidgets('renders a ListView on ItemsUpdated', (tester) async {
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: const [],
          ),
        );

        await tester.pumpWidget(_pumpView(controller));

        expect(find.byType(ListView), findsOneWidget);
      });
    });

    group('builders', () {
      testWidgets('renders default user bubble for UserMessageItem', (
        tester,
      ) async {
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: const [UserMessageItem('hi')],
          ),
        );

        await tester.pumpWidget(_pumpView(controller));

        expect(find.text('hi'), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text('hi'),
            matching: find.byWidgetPredicate(
              (w) => w is Align && w.alignment == Alignment.centerRight,
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets(
        'userMessageBuilder replaces the default bubble when provided',
        (tester) async {
          when(() => controller.state).thenReturn(
            GenUIZoneItemsUpdated(
              controller: _FakeSurfaceController(),
              items: const [UserMessageItem('hi')],
            ),
          );

          await tester.pumpWidget(
            _pumpView(
              controller,
              userMessageBuilder: (context, message) => Text('custom:$message'),
            ),
          );

          expect(find.text('custom:hi'), findsOneWidget);
          expect(find.text('hi'), findsNothing);
        },
      );

      testWidgets('renders default error bubble for ErrorItem', (
        tester,
      ) async {
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: const [ErrorItem('boom')],
          ),
        );

        await tester.pumpWidget(_pumpView(controller));

        expect(find.byType(DefaultErrorBubble), findsOneWidget);
        expect(find.text('boom'), findsOneWidget);
      });

      testWidgets('errorBuilder replaces the default bubble when provided', (
        tester,
      ) async {
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: const [ErrorItem('boom')],
          ),
        );

        await tester.pumpWidget(
          _pumpView(
            controller,
            errorBuilder: (context, message) => Text('custom:$message'),
          ),
        );

        expect(find.text('custom:boom'), findsOneWidget);
        expect(find.byType(DefaultErrorBubble), findsNothing);
      });

      testWidgets('errorBuilder receives the error, not a rendering of it', (
        tester,
      ) async {
        // The whole point of carrying the object: a host branches on the type
        // to re-authenticate rather than matching on message text.
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: [ErrorItem(AuthError('token rejected'))],
          ),
        );

        await tester.pumpWidget(
          _pumpView(
            controller,
            errorBuilder: (context, error) =>
                Text(error is AuthError ? 'sign in again' : 'generic'),
          ),
        );

        expect(find.text('sign in again'), findsOneWidget);
      });

      testWidgets('GenUIZone.chat forwards errorBuilder to the view', (
        tester,
      ) async {
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: const [ErrorItem('boom')],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenUIZone.chat(
                controller: controller,
                errorBuilder: (context, message) => Text('forwarded:$message'),
              ),
            ),
          ),
        );

        expect(find.text('forwarded:boom'), findsOneWidget);
      });

      testWidgets('surfaceBuilder wraps the surface widget when provided', (
        tester,
      ) async {
        final surfaceController = _MockSurfaceController();
        when(
          () => surfaceController.contextFor(any()),
        ).thenReturn(_FakeSurfaceContext());
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: surfaceController,
            items: const [SurfaceItem('s-1')],
          ),
        );

        Widget? captured;
        await tester.pumpWidget(
          _pumpView(
            controller,
            surfaceBuilder: (context, surface, isLatest) {
              captured = surface;
              return const SizedBox(key: Key('wrapper'), width: 1, height: 1);
            },
          ),
        );

        expect(find.byKey(const Key('wrapper')), findsOneWidget);
        expect(captured, isA<Surface>());
      });
    });

    group('loading', () {
      testWidgets('renders the default indicator without dropping the items', (
        tester,
      ) async {
        when(() => controller.isSending).thenReturn(true);
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: const [UserMessageItem('hi')],
          ),
        );

        await tester.pumpWidget(_pumpView(controller));

        expect(find.byType(DefaultLoadingIndicator), findsOneWidget);
        expect(find.text('hi'), findsOneWidget);
      });

      testWidgets('renders no indicator when the controller is idle', (
        tester,
      ) async {
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: const [UserMessageItem('hi')],
          ),
        );

        await tester.pumpWidget(_pumpView(controller));

        expect(find.byType(DefaultLoadingIndicator), findsNothing);
      });

      testWidgets('loadingBuilder replaces the default indicator', (
        tester,
      ) async {
        when(() => controller.isSending).thenReturn(true);
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: const [],
          ),
        );

        await tester.pumpWidget(
          _pumpView(
            controller,
            loadingBuilder: (context) => const Text('custom-loading'),
          ),
        );

        expect(find.text('custom-loading'), findsOneWidget);
        expect(find.byType(DefaultLoadingIndicator), findsNothing);
      });

      testWidgets('GenUIZone.chat forwards loadingBuilder to the view', (
        tester,
      ) async {
        when(() => controller.isSending).thenReturn(true);
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: _FakeSurfaceController(),
            items: const [],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GenUIZone.chat(
                controller: controller,
                loadingBuilder: (context) => const Text('forwarded-loading'),
              ),
            ),
          ),
        );

        expect(find.text('forwarded-loading'), findsOneWidget);
      });

      testWidgets('appears and clears as the controller flips isSending', (
        tester,
      ) async {
        final realController = _RecordingController();
        addTearDown(realController.dispose);
        realController.emitItems(_FakeSurfaceController(), const [
          UserMessageItem('hi'),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GenUIZone.chat(controller: realController)),
          ),
        );
        expect(find.byType(DefaultLoadingIndicator), findsNothing);

        realController.isSending = true;
        await tester.pump();
        expect(find.byType(DefaultLoadingIndicator), findsOneWidget);

        realController.isSending = false;
        await tester.pump();
        expect(find.byType(DefaultLoadingIndicator), findsNothing);
      });
    });

    group('locking', () {
      late _MockSurfaceController surfaceController;

      setUp(() {
        surfaceController = _MockSurfaceController();
        when(
          () => surfaceController.contextFor(any()),
        ).thenReturn(_FakeSurfaceContext());
      });

      testWidgets(
        'flags all surfaces in a multi-surface latest turn together',
        (tester) async {
          when(() => controller.state).thenReturn(
            GenUIZoneItemsUpdated(
              controller: surfaceController,
              items: const [
                SurfaceItem('a'),
                SurfaceItem('b'),
                UserMessageItem('hi'),
                SurfaceItem('c'),
                SurfaceItem('d'),
              ],
            ),
          );
          final recorder = _SurfaceCallRecorder();

          await tester.pumpWidget(
            _pumpView(controller, surfaceBuilder: recorder.builder),
          );

          expect(recorder.isLatestFlags, [false, false, true, true]);
        },
      );

      testWidgets(
        'default surfaceBuilder wraps in LockableSurface(locked: !isLatest)',
        (tester) async {
          when(() => controller.state).thenReturn(
            GenUIZoneItemsUpdated(
              controller: surfaceController,
              items: const [
                SurfaceItem('a'),
                UserMessageItem('hi'),
                SurfaceItem('b'),
              ],
            ),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 200,
                  child: GenUIZoneView(controller: controller),
                ),
              ),
            ),
          );

          final lockedFlags = tester
              .widgetList<LockableSurface>(
                find.byType(LockableSurface, skipOffstage: false),
              )
              .map((w) => w.locked)
              .toList();
          expect(lockedFlags, [true, false]);
        },
      );

      testWidgets('an ErrorItem after a surface leaves it unlocked', (
        tester,
      ) async {
        // A failed turn drops its user item and records the failure instead, so
        // the surface the user pressed must stay live for a retry.
        when(() => controller.state).thenReturn(
          GenUIZoneItemsUpdated(
            controller: surfaceController,
            items: const [SurfaceItem('picker'), ErrorItem('boom')],
          ),
        );
        final recorder = _SurfaceCallRecorder();

        await tester.pumpWidget(
          _pumpView(controller, surfaceBuilder: recorder.builder),
        );

        expect(recorder.isLatestFlags, [true]);
      });

      testWidgets(
        'flips isLatest when the controller emits a later user message',
        (tester) async {
          final realController = _RecordingController();
          addTearDown(realController.dispose);
          realController.emitItems(surfaceController, const [SurfaceItem('a')]);
          final recorder = _SurfaceCallRecorder();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GenUIZone.chat(
                  controller: realController,
                  surfaceBuilder: recorder.builder,
                ),
              ),
            ),
          );
          expect(recorder.isLatestFlags, [true]);
          recorder.isLatestFlags.clear();

          realController.emitItems(surfaceController, const [
            SurfaceItem('a'),
            UserMessageItem('next'),
          ]);
          await tester.pump();

          expect(recorder.isLatestFlags, [false]);
        },
      );
    });
  });
}

class _RecordingController extends ChangeNotifier
    implements GenUIZoneController {
  GenUIZoneState _state = const GenUIZoneInitial();

  @override
  GenUIZoneState get state => _state;

  bool _isSending = false;

  @override
  bool get isSending => _isSending;

  set isSending(bool value) {
    _isSending = value;
    notifyListeners();
  }

  @override
  int get failedTurns => 0;

  @override
  void discardTurn() {}

  void emitError(String error) {
    _state = GenUIZoneError(error: error);
    notifyListeners();
  }

  void emitItems(SurfaceController controller, List<GenUIZoneItem> items) {
    _state = GenUIZoneItemsUpdated(controller: controller, items: items);
    notifyListeners();
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> sendMessage(String text) async {}
}
