import 'package:home_backend/env/home_env.dart';
import 'package:home_backend/env/home_var.dart';

/// {@template cors_config}
/// Browser origins allowed to call the API, loaded from
/// `HOME_CORS_ALLOWED_ORIGINS`.
/// {@endtemplate}
class CorsConfig {
  /// {@macro cors_config}
  ///
  /// Creates a [CorsConfig] from already-resolved origins. Prefer
  /// [CorsConfig.fromEnvironment] for production use.
  const CorsConfig({required this.allowedOrigins});

  /// {@macro cors_config}
  ///
  /// Reads a comma separated origin list from [env]. An unset variable yields
  /// an empty allowlist, so no browser origin is trusted until one is set.
  factory CorsConfig.fromEnvironment([HomeEnv? env]) {
    final raw = (env ?? HomeEnv()).optional(HomeVar.corsAllowedOrigins);
    final origins = <String>{
      for (final entry in (raw ?? '').split(','))
        if (entry.trim().isNotEmpty) _normalize(entry),
    };
    return CorsConfig(allowedOrigins: origins);
  }

  /// Exact origins, such as `https://app.example.com`, without a trailing
  /// slash.
  final Set<String> allowedOrigins;

  /// Whether [origin] is on the allowlist. A literal match only, so no
  /// wildcard or suffix trickery.
  bool allows(String? origin) =>
      origin != null && allowedOrigins.contains(origin);

  static String _normalize(String origin) {
    final trimmed = origin.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
