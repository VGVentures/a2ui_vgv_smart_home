import 'dart:io';

import 'package:home_backend/env/home_var.dart';

/// {@template home_env_exception}
/// Thrown when a declared `HOME_*` environment variable is missing or
/// invalid.
/// {@endtemplate}
class HomeEnvException implements Exception {
  /// {@macro home_env_exception}
  ///
  /// Creates an exception with a human-readable [message].
  HomeEnvException(this.message);

  /// The human-readable error message.
  final String message;

  @override
  String toString() => 'HomeEnvException: $message';
}

/// {@template home_env}
/// Typed wrapper around an environment source for `HOME_*` variables.
/// {@endtemplate}
///
/// Call sites pass [HomeVar] symbols instead of string keys, so typos are
/// caught at compile time and the declared registry is the single source of
/// truth.
class HomeEnv {
  /// {@macro home_env}
  ///
  /// Creates a [HomeEnv] reading from [source]. Defaults to
  /// [Platform.environment] when [source] is omitted.
  HomeEnv([Map<String, String>? source])
    : _source = source ?? Platform.environment;

  final Map<String, String> _source;

  /// Returns the value for [variable]. Throws [HomeEnvException] if the
  /// variable is unset or empty.
  String requireNonEmpty(HomeVar variable) {
    final value = _source[variable.name];
    if (value == null || value.isEmpty) {
      throw HomeEnvException('${variable.name} is not set');
    }
    return value;
  }

  /// Returns the value for [variable], or `null` if it is unset or empty.
  String? optional(HomeVar variable) {
    final value = _source[variable.name];
    return (value == null || value.isEmpty) ? null : value;
  }
}
