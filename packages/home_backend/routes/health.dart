import 'package:dart_frog/dart_frog.dart';

/// `GET /health`: answers `{"status": "ok"}` once the server is up.
Response onRequest(RequestContext context) {
  return Response.json(body: {'status': 'ok'});
}
