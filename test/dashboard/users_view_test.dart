import 'dart:async';
import 'dart:convert';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_repository/home_repository.dart';

import '../helpers/fake_agent.dart';
import '../helpers/helpers.dart';

/// A one pixel PNG.
const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf'
    'DwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  group('Dashboard users', () {
    testWidgets('shows the skeleton and no agent while users load', (
      tester,
    ) async {
      final gate = Completer<void>();
      final factory = FakeAgentFactory();
      await tester.pumpApp(
        factory,
        usersRepository: FakeUsersRepository(gate: gate),
      );

      expect(find.byType(SkeletonSurface), findsOneWidget);
      expect(find.text('Ana'), findsNothing);
      expect(factory.agents, isEmpty);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(factory.agents, hasLength(1));
    });

    testWidgets('builds the sidebar from the fetched users', (tester) async {
      await tester.pumpApp(
        FakeAgentFactory(),
        usersRepository: FakeUsersRepository(),
      );
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Marco'), findsOneWidget);
    });

    testWidgets('shows the photo of a user that has one', (tester) async {
      final photo = base64Decode(_pixel);
      await tester.pumpApp(
        FakeAgentFactory(),
        usersRepository: FakeUsersRepository(
          users: [
            HomeUser(id: 'ana', name: 'Ana', role: 'host', photo: photo),
          ],
        ),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, MemoryImage(photo));
    });

    testWidgets('shows the error with retry, then recovers', (tester) async {
      final repository = FakeUsersRepository(failures: 1);
      final factory = FakeAgentFactory();
      await tester.pumpApp(factory, usersRepository: repository);

      expect(find.text('Could not load the household.'), findsOneWidget);
      expect(find.text('Ana'), findsNothing);
      expect(factory.agents, isEmpty);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      expect(repository.calls, 2);
      expect(find.text('Could not load the household.'), findsNothing);
      expect(find.text('Marco'), findsOneWidget);
      expect(factory.agents, hasLength(1));
    });

    testWidgets('treats an empty list as a failure', (tester) async {
      await tester.pumpApp(
        FakeAgentFactory(),
        usersRepository: FakeUsersRepository(users: const []),
      );
      expect(find.text('Could not load the household.'), findsOneWidget);
    });

    testWidgets('the first request carries the selected user prompt', (
      tester,
    ) async {
      final factory = FakeAgentFactory();
      await tester.pumpApp(factory);
      expect(factory.agents.single.sent.single, contains('user_id "ana"'));
    });
  });
}
