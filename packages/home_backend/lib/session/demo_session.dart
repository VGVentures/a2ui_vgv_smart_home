import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/llm/llm.dart';
import 'package:home_backend/scenario/scenario_world.dart';

/// {@template demo_session}
/// One visitor's demo: their own household, clock, devices and `/live`
/// listeners. Nothing in it is shared with another visitor, so what one person
/// changes is never seen by another.
/// {@endtemplate}
class DemoSession {
  /// {@macro demo_session}
  ///
  /// Creates a session from its parts.
  const DemoSession({
    required this.database,
    required this.machine,
    required this.world,
    required this.hub,
    required this.generate,
  });

  /// The mock household data, loaded fresh for this visitor.
  final MockDatabase database;

  /// The only writer of this visitor's home.
  final DeviceStateMachine machine;

  /// The mocked world around this visitor's household and its clock.
  final ScenarioWorld world;

  /// Fans what changes out to this visitor's `/live` sockets.
  final LiveHub hub;

  /// Calls the model with tools that read and write only this session.
  final Generate generate;
}
