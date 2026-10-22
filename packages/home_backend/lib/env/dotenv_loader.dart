import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:home_backend/env/home_var.dart';
import 'package:logging/logging.dart';

/// Reads declared [HomeVar] values from a dotenv file.
///
/// Returns an empty map when [file] (defaulting to `.env` in the current
/// working directory) does not exist; production deployments typically set
/// real env vars and ship without a `.env`. Only the names declared in
/// [HomeVar] are forwarded — unknown keys in the file are ignored, matching
/// the rule used by the bootstrap logger.
///
/// Emits one line via [log] indicating whether a `.env` file was found, so
/// operators can confirm at boot time which source the server picked up.
Map<String, String> loadDotEnv({
  File? file,
  void Function(String line) log = _defaultLog,
}) {
  final target = file ?? File('.env');
  if (!target.existsSync()) {
    log('No .env configuration file found, using process environment only.');
    return const {};
  }
  log('Found .env configuration file.');
  final env = DotEnv(quiet: true)..load([target.path]);
  return {
    for (final variable in HomeVar.values)
      if (env.isDefined(variable.name)) variable.name: env[variable.name]!,
  };
}

void _defaultLog(String line) => Logger('bootstrap').info(line);
