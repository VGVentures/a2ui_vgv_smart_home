import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/tools/agent_tool.dart';

/// A tool that returns the household's users.
///
/// With a `user_id` it returns that person's full profile: role, what they care
/// about, what their dashboard leads with and the context signals to read.
/// Without one it lists every user so the model can discover valid ids.
AgentTool userDataTool(MockDatabase database) {
  return AgentTool(
    name: 'get_user_data',
    description:
        'Returns data about the people in the Rivera household. Pass user_id '
        'for one profile (role, interests, what their dashboard leads with, '
        'context signals). Omit it to list every user.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'user_id': {
          'type': 'string',
          'description': 'The user id, for example "ana". Omit to list users.',
        },
      },
    },
    onCall: (args) {
      final id = args['user_id'];
      if (id is String && id.isNotEmpty) return database.requireUser(id);
      return {'users': database.listUsers()};
    },
  );
}
