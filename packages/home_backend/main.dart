import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:genkit/genkit.dart' show ModelRef;
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:home_backend/cors/cors_config.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_binder.dart';
import 'package:home_backend/devices/device_filler.dart';
import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/env/dotenv_loader.dart';
import 'package:home_backend/env/home_env.dart';
import 'package:home_backend/env/home_var.dart';
import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_backend/logging/logging.dart';
import 'package:home_backend/prompt/system_prompt.dart';
import 'package:home_backend/runtime.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/session/demo_session.dart';
import 'package:home_backend/session/session_store.dart';
import 'package:home_backend/tools/agent_tools.dart';
import 'package:home_backend/transcribe/transcriber.dart';
import 'package:home_backend/validation/a2ui_envelope_validator.dart';
import 'package:home_backend/validation/catalog_component_validator.dart';
import 'package:home_backend/validation/layout_composer.dart';
import 'package:home_backend/validation/layout_validator.dart';
import 'package:home_catalog/home_catalog.dart';

/// Runs once on server start. Loads `.env` if present (the process environment
/// wins on overlap), validates the configuration, wires the model, its tools
/// and the mock world together, and renders the system prompt. Any failure
/// crashes the process so a misconfigured server never reports healthy.
Future<void> init(InternetAddress ip, int port) async {
  setupLogging();
  final env = HomeEnv({...loadDotEnv(), ...Platform.environment});

  final model = googleAI.gemini(
    env.optional(HomeVar.llmModel) ?? defaultModel,
  );

  runtime = Runtime(
    sessions: SessionStore(factory: () => _newSession(model)),
    systemPrompt: await SystemPrompt.load(homeCatalog),
    validators: [
      A2uiEnvelopeValidator(homeCatalog),
      CatalogComponentValidator(homeCatalog),
      LayoutValidator(homeCatalog),
    ],
    transcriber: Transcriber.gemini(),
    cors: CorsConfig.fromEnvironment(env),
  );
}

/// A visitor's own demo world, in the first state. Each has its own database,
/// device state machine, clock, `/live` hub and Genkit runtime with tools over
/// that database, so nothing a visitor does is seen by another.
Future<DemoSession> _newSession(ModelRef<dynamic> model) async {
  final database = await MockDatabase.load();
  final hub = LiveHub();
  final world = ScenarioWorld(database, live: hub);
  // The model's write tools and `/action` both change the home through this
  // machine, and the world brings the time dependent values up to date after
  // each change.
  final machine = DeviceStateMachine(database, onChanged: world.reconcile);

  final ai = buildGenkitRuntime();
  final tools = registerAgentTools(
    ai,
    buildAgentTools(database: database, machine: machine, world: world),
  );
  return DemoSession(
    database: database,
    machine: machine,
    world: world,
    hub: hub,
    // The model chooses the cards. They are laid out on the grid, the cells
    // they leave are filled with devices, and what a device shows is bound to
    // the data model, so the backend can move it as the device changes without
    // asking again.
    generate: bindingDevices(
      composingScreens(
        genkitGenerate(ai: ai, model: model, tools: tools),
        LayoutComposer(homeCatalog),
        DeviceFiller(database, DeviceReadings(database)),
      ),
      DeviceReadings(database),
    ),
  );
}

/// Starts the Dart Frog server for [handler] on [ip] and [port].
Future<HttpServer> run(Handler handler, InternetAddress ip, int port) {
  return serve(handler, ip, port);
}
