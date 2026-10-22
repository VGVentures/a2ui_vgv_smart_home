import 'dart:convert';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// What the backend sends for a device: the reply the model wrote with its
/// card bound to the data model, and the values that seed it.
String _reply() {
  String fence(Object message) => '```json\n${jsonEncode(message)}\n```';
  return [
    fence({
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': 's_7',
        'catalogId': homeCatalog.id,
        'sendDataModel': true,
      },
    }),
    fence({
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': 's_7',
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['row', 'chips'],
          },
          {
            'id': 'row',
            'component': 'Row',
            'children': ['oven'],
          },
          {
            'id': 'oven',
            'component': 'DeviceCard',
            'deviceId': 'oven',
            'name': 'Oven',
            'weight': 4,
            'status': {'path': '/devices/oven/status'},
            'value': {'path': '/devices/oven/value'},
            'isActive': {'path': '/devices/oven/isActive'},
          },
          {
            'id': 'chips',
            'component': 'ActionChips',
            'chips': <Object?>[],
          },
        ],
      },
    }),
    fence({
      'version': 'v0.9',
      'updateDataModel': {
        'surfaceId': 's_7',
        'path': '/devices/oven',
        'value': {
          'status': 'Preheats at 6:30 PM',
          'value': '72',
          'isActive': false,
        },
      },
    }),
  ].join('\n');
}

void main() {
  testWidgets('a bound device card changes in place when the backend says so', (
    tester,
  ) async {
    final requests = <String>[];
    final agent = HttpGenUIAgent(
      catalog: homeCatalog,
      widgetBuilders: widgetBuilders,
      tokenProvider: () async => 'token',
      stableSurfaceId: 'dashboard',
      client: MockClient((request) async {
        requests.add(request.url.path);
        return http.Response(jsonEncode({'text': _reply()}), 200);
      }),
    );
    addTearDown(agent.dispose);
    await agent.start();
    await agent.sendMessage('build');
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 1104,
            height: 632,
            child: Surface(
              surfaceContext: agent.controller.contextFor('dashboard'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Preheats at 6:30 PM'), findsOneWidget);
    final before = tester.getRect(find.byType(DeviceCard));

    // The backend sends the new values as the oven starts. Nobody asks the
    // model again.
    agent.apply({
      'version': 'v0.9',
      'updateDataModel': {
        'surfaceId': 'dashboard',
        'path': '/devices/oven',
        'value': {
          'status': 'Preheating · 150 °F',
          'value': '150',
          'isActive': true,
        },
      },
    });
    // Messages reach the controller through a stream, a turn after they are
    // added.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Preheats at 6:30 PM'), findsNothing);
    expect(find.text('Preheating · 150 °F'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(tester.getRect(find.byType(DeviceCard)), before);
    expect(requests, ['/generate']);
    expect(tester.takeException(), isNull);
  });
}
