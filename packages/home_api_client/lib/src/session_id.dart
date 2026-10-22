import 'dart:convert';
import 'dart:math';

/// A new random id for this visitor, 32 characters of `A-Z a-z 0-9 - _`.
///
/// It is made when the app opens and held in memory, so a reload is a new
/// visitor with a fresh demo world. Nobody signs in: the id only keeps one
/// visitor's world apart from another's, and it is not a secret to protect.
String newSessionId([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(24, (_) => source.nextInt(256));
  return base64UrlEncode(bytes);
}
