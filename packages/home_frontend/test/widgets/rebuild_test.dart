import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/widgets/rebuild.dart';

class _Host extends StatefulWidget {
  const _Host({required this.onBuild, required this.child, super.key});

  final VoidCallback onBuild;
  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return widget.child;
  }
}

/// Asks [host] to rebuild from inside the build of the frame.
class _Asker extends StatelessWidget {
  const _Asker({required this.host});

  final GlobalKey<State<_Host>> host;

  @override
  Widget build(BuildContext context) {
    rebuild(host.currentState!);
    return const SizedBox();
  }
}

void main() {
  group('rebuild', () {
    testWidgets('rebuilds a state at once outside a frame', (tester) async {
      final key = GlobalKey<State<_Host>>();
      var builds = 0;
      await tester.pumpWidget(
        _Host(key: key, onBuild: () => builds++, child: const SizedBox()),
      );

      rebuild(key.currentState!);
      await tester.pump();

      expect(builds, 2);
    });

    testWidgets('waits for the frame when asked while building', (
      tester,
    ) async {
      final key = GlobalKey<State<_Host>>();
      var builds = 0;
      await tester.pumpWidget(
        _Host(key: key, onBuild: () => builds++, child: const SizedBox()),
      );
      expect(builds, 1);

      // The host's child asks for a rebuild while the frame is building.
      await tester.pumpWidget(
        _Host(
          key: key,
          onBuild: () => builds++,
          child: _Asker(host: key),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(builds, greaterThan(2));
    });

    testWidgets('does nothing once the state is gone', (tester) async {
      final key = GlobalKey<State<_Host>>();
      await tester.pumpWidget(
        _Host(key: key, onBuild: () {}, child: const SizedBox()),
      );
      final state = key.currentState!;
      await tester.pumpWidget(const SizedBox());

      expect(() => rebuild(state), returnsNormally);
    });
  });
}
