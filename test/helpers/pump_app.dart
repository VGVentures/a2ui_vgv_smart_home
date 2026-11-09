import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/app/app.dart';
import 'package:a2ui_vgv_smart_home/dashboard/agent_factory.dart';
import 'package:a2ui_vgv_smart_home/voice/microphone.dart';
import 'package:a2ui_vgv_smart_home/voice/transcription_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_repository/home_repository.dart';

import 'fake_live_repository.dart';
import 'fake_scenario_repository.dart';
import 'fake_users_repository.dart';
import 'fake_voice.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    AgentFactory agentFactory, {
    GeminiKeyStore? keys,
    UsersRepository? usersRepository,
    ScenarioRepository? scenarioRepository,
    LiveRepository? liveRepository,
    Microphone? microphone,
    TranscriptionClient? transcriptionClient,
  }) async {
    view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
    await pumpWidget(
      App(
        agentFactory: agentFactory,
        keys: keys ?? GeminiKeyStore('test-key'),
        usersRepository: usersRepository ?? FakeUsersRepository(),
        scenarioRepository: scenarioRepository ?? FakeScenarioRepository(),
        liveRepository: liveRepository ?? FakeLiveRepository(),
        microphone: microphone ?? FakeMicrophone(),
        transcriptionClient: transcriptionClient ?? FakeTranscriptionClient(),
      ),
    );
    await pump();
    await pump();
  }
}
