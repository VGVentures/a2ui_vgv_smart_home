import 'package:dart_frog/dart_frog.dart';

/// `GET /`: a placeholder greeting.
Response onRequest(RequestContext context) {
  return Response(body: 'Welcome to Dart Frog!');
}
