import 'package:a2ui_vgv_smart_home/api_key/gemini_key_store.dart';
import 'package:home_frontend/home_frontend.dart';
import 'package:home_repository/home_repository.dart';

/// {@template agent_factory}
/// Builds the [GenUIAgent] that talks to the backend for one user.
///
/// A seam so tests can supply a fake agent without a backend.
/// {@endtemplate}
// ignore: one_member_abstracts
abstract interface class AgentFactory {
  /// Builds the agent that serves [user]'s dashboard.
  GenUIAgent create(HomeUser user);
}

/// {@template http_agent_factory}
/// Builds an `HttpGenUIAgent` for a user, over the backend, with the
/// visitor's session id and Gemini key.
/// {@endtemplate}
class HttpAgentFactory implements AgentFactory {
  /// {@macro http_agent_factory}
  const HttpAgentFactory({
    required this.keys,
    required this.sessionId,
    required this.baseUri,
  });

  /// Where the agent gets the visitor's Gemini key from.
  final GeminiKeyStore keys;

  /// The visitor's session id on the backend.
  final String sessionId;

  /// The base URI of the backend.
  final Uri baseUri;

  @override
  GenUIAgent create(HomeUser user) => HttpGenUIAgent(
    catalog: homeCatalog,
    widgetBuilders: widgetBuilders,
    tokenProvider: keys.token,
    sessionId: sessionId,
    stableSurfaceId: dashboardSurfaceId,
    baseUri: baseUri,
  );
}
