import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/scenario/calendar_service.dart';
import 'package:home_timeline/home_timeline.dart';

/// {@template bakery_service}
/// The mocked bakery's order desk.
/// {@endtemplate}
///
/// A request is written down as `pending`. The bakery confirms it
/// `confirmMinutes` later. The courier then leaves at one of the fixed
/// `deliverySlots` and always takes `deliveryMinutes`, so the cake arrives at
/// the slot plus that duration. Every moment comes from the clock, see
/// `ScenarioEngine`, so the order only moves on when time does.
class BakeryService {
  /// {@macro bakery_service}
  ///
  /// Creates a bakery service over the mock database.
  BakeryService(this._database, this._calendar);

  final MockDatabase _database;
  final CalendarService _calendar;

  /// The fixed ways the bakery can deliver: how long the trip takes and the
  /// departure slots still ahead of the scenario clock, each with the time the
  /// cake would arrive.
  Map<String, Object?> deliveryOptions() {
    final bakery = _database.bakery;
    final duration = bakery['deliveryMinutes'] as int;
    final now = _database.clock.now;
    final confirmsAt = now.add(
      Duration(minutes: bakery['confirmMinutes'] as int),
    );
    final fixed = [
      for (final slot in (bakery['deliverySlots'] as List<dynamic>))
        if (!atHhmm(now, slot as String).isBefore(confirmsAt)) slot,
    ];
    // Once every fixed slot has gone, the courier leaves as soon as the order
    // is confirmed, so a late request is never refused.
    final slots = fixed.isEmpty ? [hhmm(confirmsAt)] : fixed;
    return {
      'durationMinutes': duration,
      'defaultSlot': fixed.isEmpty ? slots.first : bakery['defaultSlot'],
      'slots': [
        for (final slot in slots)
          {
            'slot': slot,
            'departsAt': clock12(atHhmm(now, slot)),
            'arrivesAt': clock12(
              atHhmm(now, slot).add(Duration(minutes: duration)),
            ),
          },
      ],
    };
  }

  /// Asks the bakery to deliver the cake to the house instead of waiting for
  /// the pickup. Idempotent: a second ask returns the order that exists.
  ///
  /// [slot] is the courier's departure, `HH:mm`, one of the bakery's
  /// `deliverySlots`; it defaults to the bakery's `defaultSlot`. When every
  /// fixed slot has passed, the only slot is the courier leaving as soon as the
  /// order is confirmed.
  ///
  /// Only the person the pickup is assigned to may ask: the cake is theirs to
  /// sort out.
  ///
  /// Throws [MockDataNotFound] for an unknown user, for someone the pickup is
  /// not assigned to, when there is no pickup to replace, or for a slot the
  /// bakery does not offer.
  Map<String, Object?> requestDelivery(String userId, {String? slot}) {
    _database.requireUser(userId);
    final owner = _calendar.event('cal_cake')['userId'];
    if (owner != userId) {
      throw MockDataNotFound(
        'The cake pickup is assigned to $owner, so only $owner can ask the '
        'bakery to deliver it.',
      );
    }
    final bakery = _database.bakery;
    final orders =
        (bakery['orders'] as List<dynamic>).cast<Map<String, dynamic>>()
          // An order from later than now, left by a rewind, is not one yet.
          ..removeWhere((order) => order['status'] == 'future');
    for (final order in orders) {
      if (order['userId'] == userId) return _result('already_requested', order);
    }
    final now = _database.clock.now;
    final confirmsAt = now.add(
      Duration(minutes: bakery['confirmMinutes'] as int),
    );
    final options = deliveryOptions();
    final offered = (options['slots']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final chosen = slot ?? options['defaultSlot']! as String;
    final match = offered.where((o) => o['slot'] == chosen);
    if (match.isEmpty) {
      throw MockDataNotFound(
        'The bakery has no "$chosen" slot. Available: '
        '${offered.map((o) => o['slot']).join(', ')}.',
      );
    }
    final departsAt = atHhmm(now, chosen);
    final eta = departsAt.add(
      Duration(minutes: options['durationMinutes']! as int),
    );
    final order = <String, dynamic>{
      'id': 'order_cake',
      'userId': userId,
      'item': 'Cake',
      'bakeryName': bakery['name'],
      'method': 'delivery',
      'address': 'Rivera Home',
      'replacesEventId': 'cal_cake',
      'requestedAt': wallIso(now),
      'confirmsAt': wallIso(confirmsAt),
      'slot': chosen,
      'departsAt': wallIso(departsAt),
      'durationMinutes': options['durationMinutes'],
      'eta': wallIso(eta),
      'progressPercent': 0,
      'status': 'pending',
    };
    orders.add(order);
    return _result('requested', order);
  }

  /// Tells the bakery when the guests arrive and notes it in its message log.
  Map<String, Object?> notifyGuestsArrival(DateTime arrival, DateTime before) {
    final message =
        'Guests now arrive at ${clock12(arrival)} (was ${clock12(before)}).';
    (_database.bakery['messages'] as List<dynamic>).add({
      'at': _database.clock.nowIso,
      'text': message,
    });
    return {
      'service': 'bakery',
      'action': 'notify_guests_arrival',
      'message': message,
    };
  }

  Map<String, Object?> _result(String action, Map<String, dynamic> order) => {
    'service': 'bakery',
    'action': action,
    'order': order,
  };
}
