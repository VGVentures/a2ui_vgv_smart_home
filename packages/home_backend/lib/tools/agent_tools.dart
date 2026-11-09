import 'package:genkit/genkit.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_state_machine.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/tools/agent_tool.dart';
import 'package:home_backend/tools/device_command_tools.dart';
import 'package:home_backend/tools/google_home_tool.dart';
import 'package:home_backend/tools/inbox_tools.dart';
import 'package:home_backend/tools/scenario_tools.dart';
import 'package:home_backend/tools/todo_lists_tool.dart';
import 'package:home_backend/tools/user_data_tool.dart';
import 'package:schemantic/schemantic.dart';

/// The tools the model may call while generating a response.
///
/// Reads go to the mock [database]. Device and to-do writes go through
/// [machine], the same state machine the `/action` route uses. Scenario writes
/// (the dinner, the oven, the bakery, the inbox) go through [world].
List<AgentTool> buildAgentTools({
  required MockDatabase database,
  required DeviceStateMachine machine,
  required ScenarioWorld world,
}) => [
  userDataTool(database),
  googleHomeTool(database),
  inboxTool(database),
  markInboxReadTool(world),
  todoListsTool(database),
  bakeryOrdersTool(database),
  homeActivityTool(database),
  rescheduleGuestArrivalTool(world),
  scheduleOvenTool(world),
  requestBakeryDeliveryTool(world),
  runDeviceCommandTool(machine),
  runSceneTool(machine),
  setTodoItemTool(machine),
];

/// Registers [tools] on the Genkit runtime [ai] and returns the Genkit tools to
/// pass to `generate`. Each tool's arguments are described by a runtime schema
/// built from its `inputSchema`, so no `build_runner` codegen is needed.
List<Tool<dynamic, dynamic>> registerAgentTools(
  Genkit ai,
  List<AgentTool> tools,
) => [
  for (final tool in tools)
    ai.defineTool<Map<String, dynamic>, Object?>(
      name: tool.name,
      description: tool.description,
      inputSchema: SchemanticType.from<Map<String, dynamic>>(
        jsonSchema:
            tool.inputSchema ??
            const {'type': 'object', 'properties': <String, dynamic>{}},
        parse: (json) => json == null
            ? <String, dynamic>{}
            : (json as Map).cast<String, dynamic>(),
      ),
      fn: (input, _) => tool.call(input),
    ),
];
