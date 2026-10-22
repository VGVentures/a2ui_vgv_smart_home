import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/tools/agent_tool.dart';
import 'package:home_backend/tools/tool_args.dart';

/// A tool that returns the to-do lists a user owns or has been shared.
AgentTool todoListsTool(MockDatabase database) {
  return AgentTool(
    name: 'get_todo_lists',
    description:
        'Returns the to-do lists a user owns or has been shared, such as the '
        'shopping list: id, title, subtitle, who it is shared with and items '
        'with id, label, detail and checked. The list `id` and each item `id` '
        'are the ids a ShoppingList must use (`listId`, `items[].id`). Lists '
        'are not Google Home data.',
    inputSchema: userIdInputSchema,
    onCall: (args) => database.todosFor(requiredUserId(args)),
  );
}
