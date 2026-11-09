import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:home_backend/cors/cors_config.dart';
import 'package:home_backend/cors/cors_middleware.dart';
import 'package:home_backend/env/home_env.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

const _allowed = 'https://app.example.com';

void main() {
  group('CorsConfig.fromEnvironment', () {
    test('is empty when the variable is unset', () {
      expect(
        CorsConfig.fromEnvironment(HomeEnv(const {})).allowedOrigins,
        isEmpty,
      );
    });

    test('splits on commas, trims and drops trailing slashes', () {
      final config = CorsConfig.fromEnvironment(
        HomeEnv(const {
          'HOME_CORS_ALLOWED_ORIGINS': ' https://a.com/ , https://b.com,,',
        }),
      );
      expect(config.allowedOrigins, {'https://a.com', 'https://b.com'});
    });
  });

  group('cors', () {
    const config = CorsConfig(allowedOrigins: {_allowed});
    var handlerCalls = 0;

    Future<Response> run(HttpMethod method, {String? origin}) {
      handlerCalls = 0;
      final request = _MockRequest();
      when(() => request.method).thenReturn(method);
      when(
        () => request.headers,
      ).thenReturn({if (origin != null) 'origin': origin});
      final context = _MockRequestContext();
      when(() => context.request).thenReturn(request);
      final handler = cors(config)((_) {
        handlerCalls++;
        return Response(body: 'ok');
      });
      return Future.value(handler(context));
    }

    test('answers an allowed preflight without calling the handler', () async {
      final response = await run(HttpMethod.options, origin: _allowed);
      expect(response.statusCode, HttpStatus.noContent);
      expect(response.headers['Access-Control-Allow-Origin'], _allowed);
      expect(
        response.headers['Access-Control-Allow-Headers'],
        contains('Authorization'),
      );
      expect(response.headers['Vary'], 'Origin');
      expect(handlerCalls, 0);
    });

    test('rejects a preflight from an unknown origin', () async {
      final response = await run(
        HttpMethod.options,
        origin: 'https://evil.com',
      );
      expect(response.statusCode, HttpStatus.forbidden);
      expect(response.headers, isNot(contains('Access-Control-Allow-Origin')));
    });

    test('echoes an allowed origin on a normal response', () async {
      final response = await run(HttpMethod.post, origin: _allowed);
      expect(response.headers['Access-Control-Allow-Origin'], _allowed);
      expect(response.headers['Vary'], 'Origin');
      expect(handlerCalls, 1);
    });

    test('adds no allow header for an unknown origin', () async {
      final response = await run(HttpMethod.post, origin: 'https://evil.com');
      expect(response.headers, isNot(contains('Access-Control-Allow-Origin')));
      expect(response.headers['Vary'], 'Origin');
    });

    test('adds no allow header when there is no Origin header', () async {
      final response = await run(HttpMethod.post);
      expect(response.headers, isNot(contains('Access-Control-Allow-Origin')));
    });

    test('never answers with a wildcard', () async {
      final response = await run(HttpMethod.post, origin: _allowed);
      expect(response.headers['Access-Control-Allow-Origin'], isNot('*'));
    });
  });
}
