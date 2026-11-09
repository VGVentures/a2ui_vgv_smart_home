import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/tools/agent_tool.dart';
import 'package:home_backend/tools/tool_args.dart';

/// A tool that returns what other people changed that concerns one user.
AgentTool inboxTool(MockDatabase database) {
  return AgentTool(
    name: 'get_inbox',
    description:
        "Returns a user's household inbox, newest first, with the count of "
        'unread items. An item is a change somebody else made that concerns '
        'this user, such as "Ana moved the dinner party": it has the title, '
        'the body, who sent it, when, whether it is read and, when one option '
        'is clearly best for this user, a `suggestion` ({tool, label, '
        'reason}) naming the tool that would fix their plan. Call it before '
        'you compose a screen: an unread item leads the screen, and its '
        'suggestion becomes the heads-up card or chip the user can tap.',
    inputSchema: userIdInputSchema,
    onCall: (args) => database.inboxFor(requiredUserId(args)),
  );
}

/// A tool that marks inbox items as read.
AgentTool markInboxReadTool(ScenarioWorld world) {
  return AgentTool(
    name: 'mark_inbox_read',
    description:
        "Marks a user's unread inbox items as read, or only the one named by "
        'item_id. Use it when the user dismisses or has dealt with a '
        'notification. Acting on its suggestion (for example asking the '
        'bakery to deliver) marks it read by itself.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'user_id': {
          'type': 'string',
          'description': 'The user whose inbox it is, for example "marco".',
        },
        'item_id': {
          'type': 'string',
          'description': 'One item to mark, for example "inbox_1".',
        },
      },
      'required': ['user_id'],
    },
    onCall: (args) => world.inbox.markRead(
      requiredUserId(args),
      itemId: args['item_id'] as String?,
    ),
  );
}
