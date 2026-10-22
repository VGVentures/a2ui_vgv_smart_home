import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/scenario/calendar_service.dart';
import 'package:home_backend/scenario/trip_service.dart';
import 'package:home_timeline/home_timeline.dart';

/// {@template scenario_engine}
/// The demo's state as a function of time.
/// {@endtemplate}
///
/// [reconcile] reads the scenario clock and the schedules the demo holds (the
/// oven programme, the bakery order, the calendar) and writes down what is true
/// at that moment: the oven's temperature, whether the cake has arrived, who is
/// at the door. Nothing here is an event that fires once, so the clock can move
/// forward or back and the state is right either way, and a change the user
/// made (a rescheduled preheat, a new order) is kept because it is an input.
///
/// Call it after the clock moves and after anything changes a schedule.
class ScenarioEngine {
  /// {@macro scenario_engine}
  ///
  /// Creates an engine over the mock database.
  ScenarioEngine(
    this._database,
    this._calendar,
    this._trips, {
    this._onOrderChanged,
  });

  static const _ambientF = 72;
  static const _doorbellWindow = ActivityFeed.arrivalWindow;
  static const _preconditionLead = Duration(minutes: 5);

  final MockDatabase _database;
  final CalendarService _calendar;
  final TripService _trips;

  /// Told when an order reaches a new stage the person should see on screen:
  /// confirmed, out for delivery, halfway, delivered.
  final void Function(Map<String, dynamic> order)? _onOrderChanged;

  /// The last stage told for each order, so a stage is told once.
  final _told = <Object?, String>{};

  /// How long before departure the car starts its climate when it is told to
  /// precondition.
  static Duration get preconditionLead => _preconditionLead;

  /// Brings every time dependent value up to the scenario clock.
  void reconcile() {
    final now = _database.clock.now;
    final delivered = _reconcileBakery(now);
    _trips.replan(bakeryDelivers: delivered);
    _reconcileOven(now);
    _reconcileClimate(now);
    _reconcileDoorbell(now);
    _reconcileRecipe(now);
  }

  // ---- bakery -------------------------------------------------------------

  /// Sets each order's status and swaps the pickup on the calendar for the
  /// delivery. Returns whether a delivery is confirmed.
  bool _reconcileBakery(DateTime now) {
    var delivers = false;
    // An order that is gone (a reset) is forgotten, so the next one is new.
    _told.removeWhere((id, _) => !_orders.any((order) => order['id'] == id));
    for (final order in _orders) {
      final status = _orderStatus(order, now);
      order['status'] = status;
      order['progressPercent'] = _progress(order, now);
      order['statusLabel'] = _statusLabel(order, status, now);
      order['departsAtLabel'] = clock12(
        parseWall(order['departsAt'] as String),
      );
      order['etaLabel'] = clock12(parseWall(order['eta'] as String));
      final confirmed = status != 'pending' && status != 'future';
      delivers = delivers || confirmed;
      _syncCalendar(order, status);
      _tell(order, status);
    }
    if (_orders.isEmpty) return false;
    return delivers;
  }

  String _orderStatus(Map<String, dynamic> order, DateTime now) {
    // An order the clock has not reached yet, after a rewind, is not there.
    if (now.isBefore(parseWall(order['requestedAt'] as String))) {
      return 'future';
    }
    if (now.isBefore(parseWall(order['confirmsAt'] as String))) {
      return 'pending';
    }
    if (now.isBefore(parseWall(order['departsAt'] as String))) {
      return 'confirmed';
    }
    if (now.isBefore(parseWall(order['eta'] as String))) {
      return 'out_for_delivery';
    }
    return 'delivered';
  }

  /// The order in a few words, for the card that tracks it.
  String _statusLabel(
    Map<String, dynamic> order,
    String status,
    DateTime now,
  ) {
    final departs = clock12(parseWall(order['departsAt'] as String));
    final eta = parseWall(order['eta'] as String);
    return switch (status) {
      'pending' => 'Waiting for the bakery to confirm',
      'confirmed' => 'Pending · courier leaves the bakery at $departs',
      'out_for_delivery' =>
        'In progress · ${eta.difference(now).inMinutes} min left, '
            'arrives ${clock12(eta)}',
      _ => 'Delivered · ${clock12(eta)}',
    };
  }

  /// How long before the cake is at the door the tracker reads full.
  static const _arrivingWithin = Duration(minutes: 2);

  /// How far along the courier is, 0 until the bakery is left and 100 once the
  /// cake is at the door, or about to be: the last couple of minutes read full
  /// so the bar is at the end when the courier is.
  int _progress(Map<String, dynamic> order, DateTime now) {
    final departs = parseWall(order['departsAt'] as String);
    final eta = parseWall(order['eta'] as String);
    if (!now.isAfter(departs)) return 0;
    if (eta.difference(now) <= _arrivingWithin) return 100;
    return (100 *
            now.difference(departs).inSeconds /
            eta.difference(departs).inSeconds)
        .round();
  }

  /// Tells the listener once when [order] reaches a stage worth a screen: a
  /// new status, each quarter of the way, and the bar reading full.
  void _tell(Map<String, dynamic> order, String status) {
    final progress = order['progressPercent'] as int;
    final quarter = progress >= 100 ? 'full' : '${progress ~/ 25}';
    final stage = status == 'out_for_delivery' ? '$status $quarter' : status;
    if (_told[order['id']] == stage) return;
    final first = !_told.containsKey(order['id']);
    _told[order['id']] = stage;
    // The request itself is told to the screens by the tool that made it.
    if (first && status == 'pending') return;
    _onOrderChanged?.call(order);
  }

  /// Keeps the order on the calendar of everyone it concerns: the delivery is
  /// there from the moment it is asked for, tentative until the bakery
  /// confirms it, and then the pickup it replaces is cancelled. A rewind to
  /// before the request takes it off again.
  void _syncCalendar(Map<String, dynamic> order, String status) {
    final pickup = _calendar.event(order['replacesEventId'] as String);
    final deliveryId = '${order['replacesEventId']}_delivery';
    final confirmed = status != 'pending' && status != 'future';
    pickup['status'] = confirmed ? 'cancelled' : 'confirmed';
    if (status == 'future') {
      _calendar.removeEvent(deliveryId);
      return;
    }
    final departs = parseWall(order['departsAt'] as String);
    final eta = parseWall(order['eta'] as String);
    final owner = order['userId'] as String;
    _calendar.ensureEvent({
        'id': deliveryId,
        'userId': owner,
        'title': 'Cake delivery from the bakery',
      })
      ..['start'] = wallIso(departs)
      ..['end'] = wallIso(eta)
      ..['status'] = confirmed ? 'confirmed' : 'tentative'
      ..['leavesAt'] = clock12(departs)
      ..['arrivesAt'] = clock12(eta)
      ..['detail'] =
          'Leaves the bakery ${clock12(departs)} · arrives home '
          '${clock12(eta)} · ${order['durationMinutes']} min'
          '${confirmed ? '' : ' · waiting for the bakery to confirm'}'
      ..['assignedTo'] = {
        owner,
        ..._database.assigneesOf(_calendar.guestsEvent()),
      }.toList();
  }

  List<Map<String, dynamic>> get _orders =>
      (_database.bakery['orders'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

  // ---- oven ---------------------------------------------------------------

  void _reconcileOven(DateTime now) {
    final oven = _database.deviceOrNull('oven');
    if (oven == null) return;
    final traits = oven['traits'] as Map<String, dynamic>;
    if (!traits.containsKey('CookSchedule')) return;
    final control = traits['TemperatureControl'] as Map<String, dynamic>;
    final op = traits['OperationalState'] as Map<String, dynamic>;
    final cook = traits['CookSchedule'] as Map<String, dynamic>;
    final target = control['temperatureSetpointF'] as int;
    final start = control['scheduledStart'] as String?;
    if (start == null) {
      _ovenIs(op, control, cook, 'stopped', 'Off', _ambientF);
      return;
    }
    final preheat = atHhmm(now, start);
    final ready = preheat.add(Duration(minutes: cook['preheatMinutes'] as int));
    final roastAt = cook['roastInAt'] as String?;
    final roastIn = roastAt == null ? null : atHhmm(now, roastAt);
    final cookStart = roastIn == null || roastIn.isBefore(ready)
        ? ready
        : roastIn;
    final done = roastAt == null
        ? null
        : cookStart.add(Duration(minutes: cook['cookMinutes'] as int));
    cook['readyAt'] = hhmm(ready);
    cook['doneAt'] = done == null ? null : hhmm(done);
    cook['remainingMinutes'] = null;
    if (now.isBefore(preheat)) {
      _ovenIs(
        op,
        control,
        cook,
        'stopped',
        'Off · preheats at ${clock12(preheat)}',
        _ambientF,
      );
    } else if (now.isBefore(ready)) {
      final fraction =
          now.difference(preheat).inSeconds /
          ready.difference(preheat).inSeconds;
      final degrees = (_ambientF + (target - _ambientF) * fraction).round();
      _ovenIs(
        op,
        control,
        cook,
        'preheating',
        'Preheating · $degrees °F',
        degrees,
      );
    } else if (done == null || now.isBefore(cookStart)) {
      _ovenIs(op, control, cook, 'ready', 'Ready · $target °F', target);
    } else if (now.isBefore(done)) {
      cook['remainingMinutes'] = done.difference(now).inMinutes;
      _ovenIs(
        op,
        control,
        cook,
        'roasting',
        'Roasting · done ${clock12(done)}',
        target,
      );
    } else {
      _ovenIs(op, control, cook, 'done', 'Done · roast is ready', target);
    }
  }

  void _ovenIs(
    Map<String, dynamic> op,
    Map<String, dynamic> control,
    Map<String, dynamic> cook,
    String state,
    String label,
    int degrees,
  ) {
    op['state'] = state;
    op['statusLabel'] = label;
    control['currentTemperatureF'] = degrees;
  }

  // ---- car climate --------------------------------------------------------

  void _reconcileClimate(DateTime now) {
    final car = _database.deviceOrNull('car');
    if (car == null) return;
    final climate =
        (car['traits'] as Map<String, dynamic>)['Climate']
            as Map<String, dynamic>?;
    if (climate == null) return;
    final startAt = climate['startAt'] as String?;
    if (startAt == null) {
      climate['state'] = 'off';
      climate['statusLabel'] = 'Climate off';
      return;
    }
    final at = atHhmm(now, startAt);
    final on = !now.isBefore(at);
    climate['state'] = on ? 'on' : 'scheduled';
    climate['statusLabel'] = on ? 'Climate on' : 'Climate on at ${clock12(at)}';
  }

  // ---- doorbell -----------------------------------------------------------

  void _reconcileDoorbell(DateTime now) {
    final bell = _database.deviceOrNull('doorbell');
    if (bell == null) return;
    final traits = bell['traits'] as Map<String, dynamic>;
    if (!traits.containsKey('DoorbellEvent')) return;
    final press = traits['DoorbellPress'] as Map<String, dynamic>;
    final event = traits['DoorbellEvent'] as Map<String, dynamic>;
    final rings = _rings()
      ..sort((a, b) => (a['at']! as DateTime).compareTo(b['at']! as DateTime));
    Map<String, Object?>? current;
    for (final ring in rings) {
      final at = ring['at']! as DateTime;
      if (!now.isBefore(at)) {
        press['lastPressAt'] = wallIso(at);
        if (now.isBefore(at.add(_doorbellWindow))) current = ring;
      }
    }
    if (rings.every((ring) => now.isBefore(ring['at']! as DateTime))) {
      press['lastPressAt'] = null;
    }
    event['kind'] = current?['kind'];
    event['label'] = current?['label'];
    event['at'] = current == null ? null : wallIso(current['at']! as DateTime);
    event['handledBy'] = current?['handledBy'];
  }

  /// Everything that rings the bell: the cake courier and the guests.
  List<Map<String, Object?>> _rings() {
    final rings = <Map<String, Object?>>[];
    for (final order in _orders) {
      if (order['status'] != 'delivered') continue;
      final eta = parseWall(order['eta'] as String);
      rings.add({
        'at': eta,
        'kind': 'delivery',
        'label': 'Delivery · cake',
        'handledBy': _homeBy(order['userId'] as String, eta),
      });
    }
    for (final event in _database.calendarEvents) {
      if (event['kind'] != 'guests_arrive') continue;
      rings.add({
        'at': parseWall(event['start'] as String),
        'kind': 'guests',
        'label': 'Guests at the front door',
        'handledBy': null,
      });
    }
    return rings;
  }

  /// [userId] when their trip has them home by [moment], else `null`.
  String? _homeBy(String userId, DateTime moment) {
    for (final trip in _database.tripRows) {
      if (trip['userId'] != userId) continue;
      final arrival = trip['homeArrivalAt'] as String?;
      if (arrival == null) return null;
      return parseWall(arrival).isAfter(moment) ? null : userId;
    }
    return null;
  }

  // ---- recipe -------------------------------------------------------------

  void _reconcileRecipe(DateTime now) {
    final scene = _database.scenes.where((s) => s['id'] == 'dinner_party');
    final sceneRunning = scene.any((s) => s['state'] == 'running');
    for (final step in _database.recipeSteps) {
      final due = !now.isBefore(atHhmm(now, step['at'] as String));
      step['done'] = step['id'] == 'scene' ? due || sceneRunning : due;
    }
  }
}
