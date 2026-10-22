import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// The header that names the visitor's own demo world on the backend.
const sessionHeader = 'X-Session-Id';

/// The subprotocol `/live` selects. The visitor's session id rides next to it,
/// because browsers can't set a header on a WebSocket.
const liveProtocol = 'genui.live.v1';

/// {@template live_connector}
/// Opens a WebSocket to [uri], offering [protocols].
/// {@endtemplate}
typedef LiveConnector =
    WebSocketChannel Function(Uri uri, Iterable<String> protocols);

WebSocketChannel _defaultConnect(Uri uri, Iterable<String> protocols) =>
    WebSocketChannel.connect(uri, protocols: protocols);

/// {@template home_api_exception}
/// The backend answered with a status other than 200.
/// {@endtemplate}
class HomeApiException implements Exception {
  /// {@macro home_api_exception}
  const HomeApiException(this.statusCode);

  /// The status the backend answered with.
  final int statusCode;

  @override
  String toString() => 'HomeApiException: Status $statusCode.';
}

/// {@template home_api_client}
/// Talks to the backend for one visitor's own demo world: the users, the
/// scenario clock and the `/live` socket. It returns the JSON as the backend
/// wrote it, and leaves reading it to the repositories.
///
/// It is made for [sessionId]'s world on the backend at `baseUri`.
/// {@endtemplate}
class HomeApiClient {
  /// {@macro home_api_client}
  HomeApiClient({
    required this.sessionId,
    required this._baseUri,
    http.Client? httpClient,
    this._connect = _defaultConnect,
  }) : _httpClient = httpClient ?? http.Client();

  /// The visitor's session id.
  final String sessionId;

  final Uri _baseUri;
  final http.Client _httpClient;
  final LiveConnector _connect;

  /// `GET /users`: the household members.
  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _httpClient.get(
      _baseUri.resolve('/users'),
      headers: {sessionHeader: sessionId},
    );
    if (response.statusCode != 200) throw HomeApiException(response.statusCode);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['users'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// `POST /clock`: moves the scenario clock to [time], a wall time without a
  /// zone, and returns the clock where it ended up.
  Future<Map<String, dynamic>> moveClock(String time) =>
      _post('/clock', body: {'to': time});

  /// `POST /reset`: restores the data and the clock to the first state, and
  /// returns the clock.
  Future<Map<String, dynamic>> reset() => _post('/reset');

  /// Opens the `/live` socket, over `wss` when the backend is `https`.
  WebSocketChannel connectLive() => _connect(
    _baseUri
        .resolve('/live')
        .replace(scheme: _baseUri.scheme == 'https' ? 'wss' : 'ws'),
    [liveProtocol, sessionId],
  );

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, Object?>? body,
  }) async {
    final response = await _httpClient.post(
      _baseUri.resolve(path),
      headers: {
        sessionHeader: sessionId,
        if (body != null) 'Content-Type': 'application/json',
      },
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode != 200) throw HomeApiException(response.statusCode);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
