/// {@template device_command_exception}
/// A command the device state machine could not apply.
/// {@endtemplate}
///
/// [message] is written for people: the `/action` route sends it to the client
/// as is, and a model calling a write tool gets it back and can recover. It is
/// 60 characters or fewer, in plain words, with no codes.
sealed class DeviceCommandException implements Exception {
  /// {@macro device_command_exception}
  const DeviceCommandException(this.message);

  /// {@template user_safe_reason}
  /// The short, user-safe reason.
  /// {@endtemplate}
  final String message;

  @override
  String toString() => message;
}

/// {@template device_not_found}
/// The device, scene, list or list item named by a command does not exist.
/// Maps to `404`.
/// {@endtemplate}
class DeviceNotFound extends DeviceCommandException {
  /// {@macro device_not_found}
  ///
  /// Creates a [DeviceNotFound] with a ready-made [message].
  const DeviceNotFound(super.message);

  /// {@macro device_not_found}
  ///
  /// An unknown device, scene or list [id]: "Couldn't find the oven."
  ///
  /// The id is only echoed when it is made of plain characters, so a hostile
  /// value never reaches the client.
  factory DeviceNotFound.forId(String id, {String kind = ''}) {
    final plain = id.replaceAll(RegExp('[_-]+'), ' ').trim();
    final safe = RegExp(r'^[A-Za-z0-9 ]{1,30}$').hasMatch(plain);
    final what = safe ? plain.toLowerCase() : 'that';
    final suffix = kind.isEmpty ? '' : ' $kind';
    return DeviceNotFound(
      safe ? "Couldn't find the $what$suffix." : "Couldn't find that$suffix.",
    );
  }
}

/// {@template command_rejected}
/// The command is valid but the device cannot do it: offline, in the wrong
/// state, or it has no such capability. Maps to `409`.
/// {@endtemplate}
class CommandRejected extends DeviceCommandException {
  /// {@macro command_rejected}
  ///
  /// Creates a [CommandRejected] with a ready-made [message].
  const CommandRejected(super.message);

  /// {@macro command_rejected}
  ///
  /// "The oven can't do that right now."
  factory CommandRejected.cannot(String deviceName) =>
      CommandRejected("${_the(deviceName)} can't do that right now.");

  /// {@macro command_rejected}
  ///
  /// "The oven is offline."
  factory CommandRejected.offline(String deviceName) =>
      CommandRejected('${_the(deviceName)} is offline.');
}

String _the(String name) {
  final lower = name.toLowerCase();
  return 'The $lower';
}
