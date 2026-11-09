import 'package:a2ui_vgv_smart_home/users/cubit/users_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_users_repository.dart';

void main() {
  group('UsersCubit', () {
    test('starts loading with nothing selected', () {
      final cubit = UsersCubit(repository: FakeUsersRepository());
      expect(cubit.state.status, UsersStatus.loading);
      expect(cubit.state.selected, isNull);
    });

    blocTest<UsersCubit, UsersState>(
      'load selects the first user',
      build: () => UsersCubit(repository: FakeUsersRepository()),
      act: (cubit) => cubit.load(),
      expect: () => const [
        UsersState(),
        UsersState(
          status: UsersStatus.loaded,
          users: [ana, marco],
          selected: ana,
        ),
      ],
    );

    blocTest<UsersCubit, UsersState>(
      'load fails when the repository throws',
      build: () => UsersCubit(repository: FakeUsersRepository(failures: 1)),
      act: (cubit) => cubit.load(),
      expect: () => const [
        UsersState(),
        UsersState(status: UsersStatus.failure),
      ],
    );

    blocTest<UsersCubit, UsersState>(
      'load fails when there are no users',
      build: () => UsersCubit(repository: FakeUsersRepository(users: const [])),
      act: (cubit) => cubit.load(),
      expect: () => const [
        UsersState(),
        UsersState(status: UsersStatus.failure),
      ],
    );

    blocTest<UsersCubit, UsersState>(
      'load again after a failure recovers',
      build: () => UsersCubit(repository: FakeUsersRepository(failures: 1)),
      act: (cubit) async {
        await cubit.load();
        await cubit.load();
      },
      verify: (cubit) {
        expect(cubit.state.status, UsersStatus.loaded);
        expect(cubit.state.selected, ana);
      },
    );

    blocTest<UsersCubit, UsersState>(
      'select changes the selected user and keeps the list',
      build: () => UsersCubit(repository: FakeUsersRepository()),
      seed: () => const UsersState(
        status: UsersStatus.loaded,
        users: [ana, marco],
        selected: ana,
      ),
      act: (cubit) => cubit.select(marco),
      expect: () => const [
        UsersState(
          status: UsersStatus.loaded,
          users: [ana, marco],
          selected: marco,
        ),
      ],
    );

    blocTest<UsersCubit, UsersState>(
      'selectFirst goes back to the first user',
      build: () => UsersCubit(repository: FakeUsersRepository()),
      seed: () => const UsersState(
        status: UsersStatus.loaded,
        users: [ana, marco],
        selected: marco,
      ),
      act: (cubit) => cubit.selectFirst(),
      expect: () => const [
        UsersState(
          status: UsersStatus.loaded,
          users: [ana, marco],
          selected: ana,
        ),
      ],
    );

    blocTest<UsersCubit, UsersState>(
      'selectFirst does nothing before the users are loaded',
      build: () => UsersCubit(repository: FakeUsersRepository()),
      act: (cubit) => cubit.selectFirst(),
      expect: () => const <UsersState>[],
    );
  });
}
