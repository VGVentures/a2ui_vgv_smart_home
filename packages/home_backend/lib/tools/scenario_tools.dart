import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/scenario/database_feed_source.dart';
import 'package:home_backend/scenario/scenario_world.dart';
import 'package:home_backend/tools/agent_tool.dart';
import 'package:home_backend/tools/tool_args.dart';
import 'package:home_timeline/home_timeline.dart';

/// A tool that returns one user's bakery orders.
AgentTool bakeryOrdersTool(MockDatabase database) {
  return AgentTool(
    name: 'get_bakery_orders',
    description:
        "Returns a user's bakery orders, such as a cake delivery, with the "
        'status (pending, confirmed or delivered), when it was confirmed and '
        'the delivery ETA, plus the messages the bakery was sent. The status '
        'follows the current time.',
    inputSchema: userIdInputSchema,
    onCall: (args) => database.bakeryFor(requiredUserId(args)),
  );
}

/// A tool that returns what just happened and what is coming up.
///
/// This is what a screen is ranked by: the most recent thing that happened and
/// the next thing to do decide which cards lead.
AgentTool homeActivityTool(MockDatabase database) {
  final feed = ActivityFeed(DatabaseFeedSource(database));
  return AgentTool(
    name: 'get_home_activity',
    description:
        'Returns what just happened (`recent`, newest first, the last 30 '
        'minutes) and what comes next (`next`, soonest first, the next 2 '
        'hours) for a user, as of the current time. Each moment has a time, '
        'minutesAgo or inMinutes, a kind (plan, oven, bakery, trip, calendar, '
        'doorbell, change or inbox), a summary and, when it is about one, the '
        'deviceId or plan stepId it points at. Call it first to decide which '
        'cards lead the screen.',
    inputSchema: userIdInputSchema,
    onCall: (args) => feed.forUser(requiredUserId(args)),
  );
}

/// A tool that moves the guests' arrival, and with it the whole dinner plan.
///
/// One call changes the calendar, the recipe plan and the oven schedule, tells
/// the bakery, and replans Marco's route. The result lists each of those as an
/// effect. The model should read the data again before it describes the day.
AgentTool rescheduleGuestArrivalTool(ScenarioWorld world) {
  return AgentTool(
    name: 'reschedule_guest_arrival',
    description:
        'Moves when the dinner guests arrive and moves everything that '
        'depends on it by the same amount: the calendar event, every step of '
        "the recipe plan, the oven's preheat and roast-in times, and the "
        "bakery is told. Marco's route is replanned too. Use it when the "
        'guests come earlier or later, for example "guests are coming an hour '
        'earlier" is shift_minutes -60. Give exactly one of shift_minutes '
        '(negative is earlier) or new_arrival. Pass requested_by, the user '
        'who is asking, so the other people the dinner is assigned to are '
        'told in their inbox what changed. Returns every change it made, the '
        'notifications included. Read the data again before you describe the '
        'result.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'shift_minutes': {
          'type': 'integer',
          'description':
              'Minutes to move the arrival by, negative for earlier.',
        },
        'new_arrival': {
          'type': 'string',
          'description':
              'The new arrival as HH:mm, 24 hour, for example 18:00.',
        },
        'requested_by': {
          'type': 'string',
          'description': 'The user asking, for example "ana".',
        },
      },
    },
    onCall: (args) {
      final result = world.planner.moveGuests(
        arrival: args['new_arrival'] as String?,
        shiftMinutes: (args['shift_minutes'] as num?)?.toInt(),
        requestedBy: args['requested_by'] as String?,
      );
      return result;
    },
  );
}

/// A tool that programmes the oven.
AgentTool scheduleOvenTool(ScenarioWorld world) {
  return AgentTool(
    name: 'schedule_oven',
    description:
        'Sets when the oven preheats and when the roast goes in, as HH:mm in '
        '24 hour time. The oven confirms the new schedule and reports the '
        'time it had before. Leave a field out to keep it. Use it to move '
        'only the oven; use reschedule_guest_arrival when the guests move.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'preheat_start': {'type': 'string', 'description': 'HH:mm'},
        'roast_in': {'type': 'string', 'description': 'HH:mm'},
      },
    },
    onCall: (args) {
      final result = world.oven.schedule(
        preheatStart: args['preheat_start'] as String?,
        roastIn: args['roast_in'] as String?,
      );
      world.reconcile();
      return result;
    },
  );
}

/// A tool that asks the bakery to deliver the cake.
AgentTool requestBakeryDeliveryTool(ScenarioWorld world) {
  return AgentTool(
    name: 'request_bakery_delivery',
    description:
        'Asks the bakery to deliver the cake to the house instead of someone '
        'picking it up. Only the person the cake pickup is assigned to (Marco) '
        'can ask. The order starts pending and the bakery confirms it a '
        "minute later. The courier leaves at one of the bakery's fixed slots "
        "(`slot`, HH:mm, default the bakery's default slot) and the trip "
        'always takes the same fixed duration, so the ETA is the slot plus '
        'that duration. Once confirmed, the pickup leaves the '
        "user's calendar and route, and their inbox items are marked read. "
        'Read get_bakery_orders for the status.',
    inputSchema: {
      'type': 'object',
      'properties': {
        ...(userIdInputSchema['properties']! as Map<String, dynamic>),
        'slot': {
          'type': 'string',
          'description':
              'The courier departure slot, HH:mm, 24 hour, one of the '
              'delivery slots the bakery offers. Omit for the default.',
        },
      },
      'required': ['user_id'],
    },
    onCall: (args) {
      final userId = requiredUserId(args);
      final slot = args['slot'];
      final result = world.bakery.requestDelivery(
        userId,
        slot: slot is String && slot.isNotEmpty ? slot : null,
      );
      world.inbox.markRead(userId);
      if (result['action'] == 'requested') {
        world.notifyDeliveryRequested(userId);
      }
      world.reconcile();
      return result;
    },
  );
}
