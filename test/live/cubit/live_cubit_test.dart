import 'package:a2ui_vgv_smart_home/live/cubit/live_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_repository/home_repository.dart';

import '../../helpers/fake_live_repository.dart';

void main() {
  group(LiveCubit, () {
    late FakeLiveRepository repository;
    late LiveCubit cubit;

    setUp(() {
      repository = FakeLiveRepository();
      cubit = LiveCubit(repository: repository);
    });

    tearDown(() => cubit.close());

    test('starts empty', () {
      expect(cubit.state, const LiveState());
    });

    test('connects and disconnects through the repository', () async {
      await cubit.connect();
      await cubit.disconnect();

      expect(repository.connects, 1);
      expect(repository.closes, 1);
    });

    test('hands the messages for the dashboard on, once each', () async {
      final seen = <Map<String, Object?>>[];
      final sub = cubit.surfaceMessages.listen(seen.add);
      addTearDown(sub.cancel);

      repository
        ..emit(const SurfaceMessageReceived({'a': 1}))
        ..emit(const SurfaceMessageReceived({'b': 2}));
      await pumpEventQueue();

      expect(seen, [
        {'a': 1},
        {'b': 2},
      ]);
      // They are not state: a screen built later does not get them again.
      expect(cubit.state, const LiveState());
    });

    test('an inbox item counts as a change for that user', () async {
      repository
        ..emit(const InboxReceived(userId: 'marco', unread: 1))
        ..emit(const InboxReceived(userId: 'marco', unread: 2));
      await pumpEventQueue();

      expect(cubit.state.refreshes, {'marco': 2});
      expect(cubit.state.unread, {'marco': 2});
    });

    test('a data change counts for every user it names', () async {
      repository
        ..emit(const DataChanged(users: ['ana', 'marco']))
        ..emit(const DataChanged(users: ['marco']));
      await pumpEventQueue();

      expect(cubit.state.refreshes, {'ana': 1, 'marco': 2});
    });

    test("the clock is the timeline's business, not state", () async {
      repository.emit(
        ClockUpdated(
          ScenarioReading(
            now: DateTime.utc(2026),
            start: DateTime.utc(2026),
            end: DateTime.utc(2027),
          ),
        ),
      );
      await pumpEventQueue();

      expect(cubit.state, const LiveState());
    });

    test('closing hangs up', () async {
      await cubit.close();

      expect(repository.closes, 1);
    });
  });
}
