import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/gemini_key/gemini_api_key.dart';
import 'package:home_backend/gemini_key/gemini_key_middleware.dart';
import 'package:home_backend/transcribe/transcribe_relay.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

/// A context whose `provide` runs the way Dart Frog's does and remembers the
/// [GeminiApiKey] it was given.
class _Provided {
  _Provided(this.context);

  final _MockRequestContext context;
  GeminiApiKey? key;
}

_Provided _context({
  String? authorization,
  String? protocols,
  String path = '/generate',
}) {
  final context = _MockRequestContext();
  final request = _MockRequest();
  final provided = _Provided(context);
  when(() => context.request).thenReturn(request);
  when(() => request.uri).thenReturn(Uri.parse('http://localhost:8080$path'));
  when(() => request.headers).thenReturn({
    if (authorization != null) HttpHeaders.authorizationHeader: authorization,
    'sec-websocket-protocol': ?protocols,
  });
  when(() => context.provide<GeminiApiKey>(any())).thenAnswer((invocation) {
    final create =
        invocation.positionalArguments.single as GeminiApiKey Function();
    provided.key = create();
    return context;
  });
  return provided;
}

void main() {
  setUpAll(() {
    registerFallbackValue(() => const GeminiApiKey('fallback'));
  });

  group('requireGeminiKey', () {
    final middleware = requireGeminiKey();
    final handler = middleware((_) => Response(body: 'ok'));

    test('rejects a request without an Authorization header', () async {
      final response = await handler(_context().context);

      expect(response.statusCode, HttpStatus.unauthorized);
      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['message'], 'Missing Gemini API key');
    });

    test('rejects an Authorization header that is not a bearer', () async {
      final response = await handler(
        _context(authorization: 'Basic abc').context,
      );

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test('rejects an empty bearer', () async {
      final response = await handler(
        _context(authorization: 'Bearer   ').context,
      );

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    for (final path in ['/generate', '/action']) {
      test('provides the bearer key on $path', () async {
        final provided = _context(authorization: 'Bearer k-1', path: path);

        final response = await handler(provided.context);

        expect(response.statusCode, HttpStatus.ok);
        expect(provided.key?.value, 'k-1');
      });
    }

    test('reads the key of /transcribe from the subprotocol', () async {
      final provided = _context(
        path: '/transcribe',
        protocols: '$transcribeProtocol, k-1',
      );

      final response = await handler(provided.context);

      expect(response.statusCode, HttpStatus.ok);
      expect(provided.key?.value, 'k-1');
    });

    test('rejects /transcribe without a key beside the protocol', () async {
      final response = await handler(
        _context(path: '/transcribe', protocols: transcribeProtocol).context,
      );

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    for (final path in [
      '/health',
      '/users',
      '/users/ana',
      '/clock',
      '/reset',
      '/live',
    ]) {
      test('lets $path through with no key', () async {
        final provided = _context(path: path);

        final response = await handler(provided.context);

        expect(response.statusCode, HttpStatus.ok);
        expect(provided.key, isNull);
      });
    }
  });
}
