import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:a2ui_vgv_smart_home/app/app.dart';
import 'package:a2ui_vgv_smart_home/config/app_config.dart';
import 'package:a2ui_vgv_smart_home/dashboard/agent_factory.dart';
import 'package:a2ui_vgv_smart_home/voice/microphone.dart';
import 'package:a2ui_vgv_smart_home/voice/transcription_client.dart';
import 'package:flutter/widgets.dart';
import 'package:home_api_client/home_api_client.dart';
import 'package:home_repository/home_repository.dart';
import 'package:record/record.dart';

/// Builds the app wired to the real backend. The person's own Gemini key is
/// asked for when the app opens and held in [GeminiKeyStore], and a random
/// session id gives them a demo world of their own on the backend.
Future<Widget> buildApp() async {
  final keys = GeminiKeyStore();
  // This visitor's own demo world on the backend. A reload is a new one.
  final sessionId = newSessionId();
  final baseUri = Uri.parse(AppConfig.backendUrl);
  final apiClient = HomeApiClient(sessionId: sessionId, baseUri: baseUri);
  return App(
    keys: keys,
    usersRepository: HttpUsersRepository(client: apiClient),
    scenarioRepository: HttpScenarioRepository(client: apiClient),
    liveRepository: WebSocketLiveRepository(client: apiClient),
    agentFactory: HttpAgentFactory(
      keys: keys,
      sessionId: sessionId,
      baseUri: baseUri,
    ),
    microphone: RecordMicrophone(AudioRecorder()),
    transcriptionClient: WebSocketTranscriptionClient(
      keys: keys,
      baseUri: baseUri,
    ),
  );
}
