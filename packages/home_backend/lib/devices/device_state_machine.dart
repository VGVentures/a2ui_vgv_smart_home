import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/command_result.dart';
import 'package:home_backend/devices/device_command.dart';
import 'package:home_backend/devices/device_exceptions.dart';
import 'package:home_backend/scenario/scenario_engine.dart';
import 'package:home_timeline/home_timeline.dart';

/// {@template device_state_machine}
/// The one place that changes the demo home.
/// {@endtemplate}
///
/// It mutates the same maps [MockDatabase] serves to the read tools, so every
/// `get_google_home_data` and `get_todo_lists` call after a command sees the
/// new values. Both the `/action` route and the model's write tools go through
/// it, so a press, a spoken request and a typed one change the same state.
///
/// Every command is deterministic and validated against the known devices and
/// the traits they carry (Home API style traits such as `OnOff`,
/// `OperationalState`, `LevelControl`, `Thermostat`, `WindowCovering`,
/// `OpenClose` and `DoorLock`). A command that fails throws a
/// [DeviceCommandException] and leaves the state untouched. A command whose
/// target is already in the wanted state is a no-op: it succeeds with an empty
/// change list.
class DeviceStateMachine {
  /// {@macro device_state_machine}
  ///
  /// Creates a state machine over the mock database.
  ///
  /// [onChanged] runs after every command that changed something, so values
  /// that follow from the new state and the clock (the oven's temperature, say)
  /// are brought up to date before anything reads them.
  DeviceStateMachine(this._database, {void Function()? onChanged})
    : _onChanged = onChanged ?? _noop;

  static void _noop() {}

  static const _maxUndo = 20;

  final MockDatabase _database;
  final void Function() _onChanged;
  final List<List<_Revert>> _undoStack = [];

  /// Forgets what can be undone. Called when the database is reset, because
  /// the undo stack points at maps that no longer exist.
  void reset() => _undoStack.clear();

  /// Applies [command] to the device [deviceId] (an id, a name or an alias).
  ///
  /// [value] is the number a command such as `set_level`, `set_temperature` or
  /// `add_time` takes.
  ///
  /// Throws [DeviceNotFound] for an unknown device and [CommandRejected] when
  /// the device is offline or cannot do the command.
  CommandResult execute(
    String deviceId,
    DeviceCommand command, {
    num? value,
  }) => _run((txn) => _command(txn, deviceId, command, value));

  /// Turns [deviceId] on or off: runs or stops, arms or disarms, opens or
  /// closes, locks or unlocks, whichever its main trait means.
  CommandResult setPower(String deviceId, {required bool on}) =>
      execute(deviceId, on ? DeviceCommand.on : DeviceCommand.off);

  /// Steps the main setting of [deviceId]: the thermostat setpoint, oven
  /// temperature, light level or speaker volume, or the blinds position.
  CommandResult adjust(String deviceId, {required bool up}) =>
      execute(deviceId, up ? DeviceCommand.up : DeviceCommand.down);

  /// Starts the scene [sceneId] (an id, a name or an alias): it applies the
  /// scene's actions and marks it `running`.
  ///
  /// Throws [DeviceNotFound] for an unknown scene.
  CommandResult runScene(String sceneId) => _run((txn) {
    final scene = _findScene(sceneId);
    final id = scene['id'] as String;
    if (scene['state'] == 'running') return;
    txn.set(id, scene, 'Scene', 'state', 'running');
    for (final action
        in (scene['actions'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      _sceneAction(txn, action);
    }
  });

  /// Ticks or unticks the item [itemId].
  ///
  /// [listId] narrows the search to one list; without it the first list that
  /// has the item wins. Throws [DeviceNotFound] for an unknown list or item.
  CommandResult toggleTodo({
    required String itemId,
    required bool checked,
    String? listId,
  }) => _run((txn) {
    final list = listId == null ? null : _findList(listId);
    final lists = list == null ? _database.todoLists : [list];
    for (final candidate in lists) {
      for (final item
          in (candidate['items'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        if (item['id'] == itemId) {
          txn.set(
            candidate['id'] as String,
            item,
            'TodoItem $itemId',
            'checked',
            checked,
          );
          return;
        }
      }
    }
    throw const DeviceNotFound("Couldn't find that item on the list.");
  });

  /// Shares the list [listId] with its `shareTarget`, the household member the
  /// "Share list" button is for.
  ///
  /// Throws [DeviceNotFound] for an unknown list and [CommandRejected] for a
  /// list with nobody to share it with.
  CommandResult shareList(String listId) => _run((txn) {
    final list = _findList(listId);
    final target = list['shareTarget'] as String?;
    if (target == null) {
      throw const CommandRejected("That list can't be shared.");
    }
    final shared = list['sharedWith'] as List<dynamic>;
    if (shared.contains(target)) return;
    txn.set(list['id'] as String, list, 'TodoList', 'sharedWith', [
      ...shared,
      target,
    ]);
  });

  /// Reverts the most recent command that changed something.
  CommandResult undoLast() {
    if (_undoStack.isEmpty) {
      return const CommandResult(summary: 'There was nothing to undo.');
    }
    final reverts = _undoStack.removeLast();
    final changes = <StateChange>[];
    for (final revert in reverts.reversed) {
      revert.target[revert.field] = revert.change.from;
      changes.add(
        StateChange(
          deviceId: revert.change.deviceId,
          trait: revert.change.trait,
          field: revert.change.field,
          from: revert.change.to,
          to: revert.change.from,
        ),
      );
    }
    _onChanged();
    return CommandResult(
      summary: 'Undid the last change: ${_describe(changes)}.',
      changes: changes,
    );
  }

  CommandResult _run(void Function(_Txn txn) body) {
    final txn = _Txn();
    try {
      body(txn);
    } on DeviceCommandException {
      // A command that fails half way leaves nothing behind.
      txn.rollback();
      rethrow;
    }
    if (!txn.changed) {
      return const CommandResult(
        summary: 'Already in that state, so nothing changed.',
      );
    }
    _undoStack.add(txn.reverts);
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    _onChanged();
    return CommandResult(
      summary: _describe(txn.changes),
      changes: List.unmodifiable(txn.changes),
    );
  }

  String _describe(List<StateChange> changes) => [
    for (final c in changes)
      '${c.deviceId} ${c.field}: ${c.from ?? 'none'} -> ${c.to ?? 'none'}',
  ].join('; ');

  // ---- lookup -------------------------------------------------------------

  /// The ids of every device, for validating the ids a response names.
  List<String> get deviceIds => _ids(_database.homeDevices);

  /// The ids of every scene.
  List<String> get sceneIds => _ids(_database.scenes);

  /// The ids of every to-do list.
  List<String> get listIds => _ids(_database.todoLists);

  /// Whether [id] names a device the way a command does: by id, name or alias.
  bool hasDevice(String id) => _match(_database.homeDevices, id) != null;

  /// Whether [id] names a scene by id, name or alias.
  bool hasScene(String id) => _match(_database.scenes, id) != null;

  /// Whether [id] names a to-do list by id or title.
  bool hasList(String id) =>
      _match(_database.todoLists, id, nameKey: 'title') != null;

  /// The ids of the items on the list [listId], or `null` for an unknown list.
  List<String>? itemIds(String listId) {
    final list = _match(_database.todoLists, listId, nameKey: 'title');
    if (list == null) return null;
    return _ids((list['items'] as List<dynamic>).cast<Map<String, dynamic>>());
  }

  static List<String> _ids(Iterable<Map<String, dynamic>> rows) => [
    for (final row in rows) row['id'] as String,
  ];

  static String _key(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  /// The row whose id, name or alias is [wanted], ignoring case, spacing and
  /// punctuation. An exact id beats a name or alias.
  Map<String, dynamic>? _match(
    Iterable<Map<String, dynamic>> rows,
    String wanted, {
    String nameKey = 'name',
  }) {
    final key = _key(wanted);
    for (final row in rows) {
      if (_key(row['id'] as String) == key) return row;
    }
    for (final row in rows) {
      final names = [
        row[nameKey] as String,
        ...((row['aliases'] as List<dynamic>?) ?? const []).cast<String>(),
      ];
      if (names.any((name) => _key(name) == key)) return row;
    }
    return null;
  }

  Map<String, dynamic> _findDevice(String id) =>
      _match(_database.homeDevices, id) ?? (throw DeviceNotFound.forId(id));

  Map<String, dynamic> _findScene(String id) =>
      _match(_database.scenes, id) ??
      (throw DeviceNotFound.forId(id, kind: 'scene'));

  Map<String, dynamic> _findList(String id) =>
      _match(_database.todoLists, id, nameKey: 'title') ??
      (throw DeviceNotFound.forId(id, kind: 'list'));

  // ---- commands -----------------------------------------------------------

  void _command(_Txn txn, String id, DeviceCommand command, num? value) {
    final device = _findDevice(id);
    final name = device['name'] as String;
    if (device['online'] == false) throw CommandRejected.offline(name);
    final traits = device['traits'] as Map<String, dynamic>;
    final cannot = CommandRejected.cannot(name);
    Map<String, dynamic>? trait(String key) =>
        traits[key] as Map<String, dynamic>?;
    void set(String traitName, String field, Object? to) => txn.set(
      device['id'] as String,
      trait(traitName)!,
      traitName,
      field,
      to,
    );

    switch (command) {
      case DeviceCommand.on || DeviceCommand.start:
        _power(txn, device, on: true);
      case DeviceCommand.off || DeviceCommand.stop:
        _power(txn, device, on: false);
      case DeviceCommand.open:
        _open(txn, device, open: true);
      case DeviceCommand.close:
        _open(txn, device, open: false);
      case DeviceCommand.lock:
        if (trait('DoorLock') == null) throw cannot;
        final openState = trait('OpenClose')?['openState'];
        if (openState != null && openState != 'closed') {
          throw CommandRejected(
            'The ${name.toLowerCase()} has to close first.',
          );
        }
        set('DoorLock', 'lockState', 'locked');
      case DeviceCommand.unlock:
        if (trait('DoorLock') == null) throw cannot;
        set('DoorLock', 'lockState', 'unlocked');
      case DeviceCommand.addTime:
        final timer = trait('Timer') ?? (throw cannot);
        final minutes = (value ?? 5).round();
        if (minutes < 1 || minutes > 120) {
          throw const CommandRejected('Add between 1 and 120 minutes.');
        }
        set(
          'Timer',
          'remainingMinutes',
          (timer['remainingMinutes'] as int) + minutes,
        );
        set('Timer', 'state', 'running');
      case DeviceCommand.setLevel:
        if (trait('LevelControl') == null) throw cannot;
        final level = value?.round();
        if (level == null || level < 0 || level > 100) {
          throw const CommandRejected('Pick a level from 0 to 100.');
        }
        set('LevelControl', 'currentLevel', level);
      case DeviceCommand.setTemperature:
        final degrees = value?.round();
        if (trait('Thermostat') != null) {
          if (degrees == null || degrees < 50 || degrees > 90) {
            throw const CommandRejected('Pick a temperature from 50 to 90.');
          }
          set('Thermostat', 'heatSetpointF', degrees);
        } else if (trait('TemperatureControl') != null) {
          if (degrees == null || degrees < 150 || degrees > 500) {
            throw const CommandRejected('Pick a temperature from 150 to 500.');
          }
          set('TemperatureControl', 'temperatureSetpointF', degrees);
        } else {
          throw cannot;
        }
      case DeviceCommand.up || DeviceCommand.down:
        final sign = command == DeviceCommand.up ? 1 : -1;
        int step(String t, String field, int by, int min, int max) =>
            ((trait(t)![field] as int) + sign * by).clamp(min, max);
        if (trait('Thermostat') != null) {
          set(
            'Thermostat',
            'heatSetpointF',
            step('Thermostat', 'heatSetpointF', 1, 50, 90),
          );
        } else if (trait('TemperatureControl') != null) {
          set(
            'TemperatureControl',
            'temperatureSetpointF',
            step('TemperatureControl', 'temperatureSetpointF', 25, 150, 500),
          );
        } else if (trait('LevelControl') != null) {
          set(
            'LevelControl',
            'currentLevel',
            step('LevelControl', 'currentLevel', 10, 0, 100),
          );
        } else if (trait('WindowCovering') != null) {
          set(
            'WindowCovering',
            'positionPercentOpen',
            step('WindowCovering', 'positionPercentOpen', 25, 0, 100),
          );
        } else {
          throw cannot;
        }
    }
  }

  /// `on` means: lit, running, open, armed, locked or charging, by trait.
  void _power(_Txn txn, Map<String, dynamic> device, {required bool on}) {
    final id = device['id'] as String;
    final traits = device['traits'] as Map<String, dynamic>;
    void set(String trait, String field, Object? to) => txn.set(
      id,
      traits[trait] as Map<String, dynamic>,
      trait,
      field,
      to,
    );

    if (traits.containsKey('CookSchedule')) {
      _ovenPower(txn, device, on: on);
    } else if (traits.containsKey('Climate')) {
      _climatePower(txn, device, on: on);
    } else if (traits.containsKey('OnOff')) {
      set('OnOff', 'onOff', on);
    } else if (traits.containsKey('OperationalState')) {
      set('OperationalState', 'state', on ? 'running' : 'stopped');
    } else if (traits.containsKey('FanControl')) {
      set('FanControl', 'fanMode', on ? 'low' : 'off');
      set('FanControl', 'percentSetting', on ? 33 : 0);
    } else if (traits.containsKey('OpenClose') ||
        traits.containsKey('WindowCovering')) {
      _open(txn, device, open: on);
    } else if (traits.containsKey('Thermostat')) {
      set('Thermostat', 'mode', on ? 'heat' : 'off');
    } else if (traits.containsKey('EnergyEvse')) {
      set('EnergyEvse', 'state', on ? 'charging' : 'pluggedInNoDemand');
    } else if (traits.containsKey('Timer')) {
      set('Timer', 'state', on ? 'running' : 'stopped');
    } else if (traits.containsKey('EnergySaver')) {
      set('EnergySaver', 'enabled', on);
    } else if (traits.containsKey('AlarmSettings')) {
      set('AlarmSettings', 'doorOpenAlarm', on ? 'armed' : 'disarmed');
    } else if (traits.containsKey('DoorLock')) {
      set('DoorLock', 'lockState', on ? 'locked' : 'unlocked');
    } else {
      throw CommandRejected.cannot(device['name'] as String);
    }
  }

  /// Starting the oven preheats it from now; stopping it clears its schedule.
  /// What it is doing at each moment after that follows from the clock.
  void _ovenPower(_Txn txn, Map<String, dynamic> device, {required bool on}) {
    final control =
        (device['traits'] as Map<String, dynamic>)['TemperatureControl']
            as Map<String, dynamic>;
    txn.set(
      device['id'] as String,
      control,
      'TemperatureControl',
      'scheduledStart',
      on ? hhmm(_database.clock.now) : null,
    );
  }

  /// Starting the car's climate preconditions the cabin for the next
  /// departure: it comes on shortly before the trip's leave-by time. Stopping
  /// it cancels that.
  void _climatePower(
    _Txn txn,
    Map<String, dynamic> device, {
    required bool on,
  }) {
    final climate =
        (device['traits'] as Map<String, dynamic>)['Climate']
            as Map<String, dynamic>;
    String? startAt;
    if (on) {
      final trips = _database.tripRows;
      if (trips.isEmpty) {
        throw const CommandRejected(
          'There is no trip to get the car ready for.',
        );
      }
      final leaveBy = parseWall(trips.first['leaveBy'] as String);
      startAt = hhmm(leaveBy.subtract(ScenarioEngine.preconditionLead));
    }
    txn.set(device['id'] as String, climate, 'Climate', 'startAt', startAt);
  }

  void _open(_Txn txn, Map<String, dynamic> device, {required bool open}) {
    final id = device['id'] as String;
    final traits = device['traits'] as Map<String, dynamic>;
    if (traits['OpenClose'] case final Map<String, dynamic> openClose) {
      // A locked door opens by unlocking first.
      final lock = traits['DoorLock'] as Map<String, dynamic>?;
      if (open && lock != null) {
        txn.set(id, lock, 'DoorLock', 'lockState', 'unlocked');
      }
      txn.set(
        id,
        openClose,
        'OpenClose',
        'openState',
        open ? 'open' : 'closed',
      );
    } else if (traits['WindowCovering'] case final Map<String, dynamic> cover) {
      txn.set(
        id,
        cover,
        'WindowCovering',
        'positionPercentOpen',
        open ? 100 : 0,
      );
    } else {
      throw CommandRejected.cannot(device['name'] as String);
    }
  }

  void _sceneAction(_Txn txn, Map<String, dynamic> action) {
    final target = action['deviceId'] as String;
    final group = _database.homeGroups
        .where((g) => g['id'] == target)
        .map((g) => (g['deviceIds'] as List<dynamic>).cast<String>())
        .firstOrNull;
    for (final id in group ?? [target]) {
      switch (action['command']) {
        case 'setLevel':
          _command(txn, id, DeviceCommand.setLevel, action['level'] as num);
        case 'setHeatSetpoint' || 'setTemperature':
          _command(
            txn,
            id,
            DeviceCommand.setTemperature,
            action['temperatureF'] as num,
          );
        case 'startCharging':
          _command(txn, id, DeviceCommand.on, null);
        case 'startPlaylist':
          final device = _findDevice(id);
          final traits = device['traits'] as Map<String, dynamic>;
          final media = traits['MediaPlayback'] as Map<String, dynamic>?;
          if (media == null) {
            throw CommandRejected.cannot(device['name'] as String);
          }
          _command(txn, id, DeviceCommand.on, null);
          txn.set(id, media, 'MediaPlayback', 'state', 'playing');
          txn.set(id, media, 'MediaPlayback', 'playlist', action['playlist']);
        default:
          throw const CommandRejected("That scene can't run right now.");
      }
    }
  }
}

/// How to put one field back: its target, the field and the change.
class _Revert {
  const _Revert(this.target, this.field, this.change);
  final Map<String, dynamic> target;
  final String field;
  final StateChange change;
}

/// The changes one command made, kept so a failure can be rolled back and the
/// last command can be undone.
class _Txn {
  final List<StateChange> changes = [];
  final List<_Revert> reverts = [];

  bool get changed => changes.isNotEmpty;

  void set(
    String id,
    Map<String, dynamic> target,
    String trait,
    String field,
    Object? to,
  ) {
    final from = target[field];
    if (from == to) return;
    target[field] = to;
    final change = StateChange(
      deviceId: id,
      trait: trait,
      field: field,
      from: from,
      to: to,
    );
    changes.add(change);
    reverts.add(_Revert(target, field, change));
  }

  void rollback() {
    for (final revert in reverts.reversed) {
      revert.target[revert.field] = revert.change.from;
    }
    changes.clear();
    reverts.clear();
  }
}
