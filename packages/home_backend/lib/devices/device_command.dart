/// {@template device_command}
/// The command vocabulary shared by `run_device_action`, the
/// `run_device_command` tool and the state machine.
/// {@endtemplate}
enum DeviceCommand {
  /// Power on, run, arm or open, whichever the device's main trait means.
  on('on'),

  /// The opposite of [on].
  off('off'),

  /// Same as [on]; reads better for ovens, timers and chargers.
  start('start'),

  /// Same as [off].
  stop('stop'),

  /// Open a garage door or blinds.
  open('open'),

  /// Close a garage door or blinds.
  close('close'),

  /// Lock a door lock.
  lock('lock'),

  /// Unlock a door lock.
  unlock('unlock'),

  /// Add minutes to a timer, five by default.
  addTime('add_time'),

  /// Set a brightness or volume from 0 to 100 (needs a value).
  setLevel('set_level'),

  /// Set a target temperature in degrees Fahrenheit (needs a value).
  setTemperature('set_temperature'),

  /// One step up on the device's main setting.
  up('up'),

  /// One step down on the device's main setting.
  down('down');

  /// {@macro device_command}
  const DeviceCommand(this.wire);

  /// The snake_case name used on the wire.
  final String wire;

  /// The command named [wire], or `null` when there is none.
  static DeviceCommand? tryParse(Object? wire) {
    for (final command in values) {
      if (command.wire == wire) return command;
    }
    return null;
  }

  /// Every wire name, for tool schemas.
  static List<String> get wireNames => [for (final c in values) c.wire];
}
