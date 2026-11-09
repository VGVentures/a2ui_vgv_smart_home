import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/cors/cors_config.dart';

const _allowMethods = 'POST, OPTIONS';
const _allowHeaders = 'Authorization, Content-Type, Accept, X-Session-Id';

/// Adds CORS headers for origins on [config]'s allowlist only.
///
/// A preflight from an allowed origin gets a `204` with the allow headers. A
/// preflight from any other origin gets a bare `403`. Responses to other
/// origins, and to requests with no `Origin` header, carry no CORS headers, so
/// a browser blocks the read. `Vary: Origin` is always set so caches keep the
/// variants apart.
Middleware cors(CorsConfig config) {
  return (handler) {
    return (context) async {
      final request = context.request;
      final origin = request.headers['origin'];
      final allowed = config.allows(origin);
      final isPreflight = request.method == HttpMethod.options;

      if (isPreflight) {
        if (!allowed) {
          return Response(statusCode: 403, headers: _vary);
        }
        return Response(
          statusCode: 204,
          headers: {..._vary, ..._allowHeadersFor(origin!)},
        );
      }

      final response = await handler(context);
      return response.copyWith(
        headers: {
          ...response.headers,
          ..._vary,
          if (allowed) 'Access-Control-Allow-Origin': origin,
        },
      );
    };
  };
}

const _vary = <String, String>{'Vary': 'Origin'};

Map<String, String> _allowHeadersFor(String origin) => {
  'Access-Control-Allow-Origin': origin,
  'Access-Control-Allow-Methods': _allowMethods,
  'Access-Control-Allow-Headers': _allowHeaders,
  'Access-Control-Max-Age': '86400',
};
