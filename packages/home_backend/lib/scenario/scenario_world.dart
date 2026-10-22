import 'dart:convert';

import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/live/live_hub.dart';
import 'package:home_backend/scenario/bakery_service.dart';
import 'package:home_backend/scenario/calendar_service.dart';
import 'package:home_backend/scenario/dinner_planner.dart';
import 'package:home_backend/scenario/inbox_service.dart';
import 'package:home_backend/scenario/oven_service.dart';
import 'package:home_backend/scenario/recipe_service.dart';
import 'package:home_backend/scenario/scenario_engine.dart';
import 'package:home_backend/scenario/trip_service.dart';
import 'package:home_catalog/home_catalog.dart'
    show a2uiVersion, dashboardSurfaceId;
import 'package:home_timeline/home_timeline.dart';

/// {@template scenario_world}
/// The mocked world around the household: every service a tool may call, the
/// engine that keeps time dependent state right, and the clock.
/// {@endtemplate}
///
/// It is the demo's backend abstraction. A tool never edits the database. It
/// calls a service ([calendar], [oven], [recipe], [bakery], [inbox]) or the
/// [planner] that combines them, and the engine reconciles what follows from
/// the time.
///
/// When a [live] hub is given, what changes is pushed to it as it happens: the
/// clock, the devices' live values, the values a dashboard shows of them (as
/// `updateDataModel` messages) and every inbox item.
class ScenarioWorld {
  /// {@macro scenario_world}
  ///
  /// Creates the world over [database] and brings it up to the clock.
  ScenarioWorld(this.database, {this.live}) {
    calendar = CalendarService(database);
    inbox = InboxService(database, onPosted: _publishInbox);
    oven = OvenService(database);
    recipe = RecipeService(database);
    bakery = BakeryService(database, calendar);
    _engine = ScenarioEngine(
      database,
      calendar,
      TripService(database),
      onOrderChanged: _publishOrder,
    );
    planner = DinnerPlanner(
      database,
      calendar,
      recipe,
      oven,
      bakery,
      inbox,
      reconcile,
    );
    _engine.reconcile();
    // What the devices read at the start is what a screen is first built from,
    // so only a change from here on is sent.
    _publishDevices();
  }

  /// The database every service writes.
  final MockDatabase database;

  /// Where changes are pushed, or `null` when nobody listens.
  final LiveHub? live;

  /// The mocked Google Calendar.
  late final CalendarService calendar;

  /// The mocked oven programme.
  late final OvenService oven;

  /// The mocked recipe plan.
  late final RecipeService recipe;

  /// The mocked bakery.
  late final BakeryService bakery;

  /// The household inbox.
  late final InboxService inbox;

  /// Moves the dinner as one request.
  late final DinnerPlanner planner;

  late final ScenarioEngine _engine;

  /// Brings every time dependent value up to the clock, and tells the live
  /// connection what the devices read now. Called after the clock moves and
  /// after anything changes a schedule.
  void reconcile() {
    _engine.reconcile();
    _publishDevices();
  }

  /// The device values last sent, as JSON, by device id.
  final _sentDevices = <String, String>{};

  /// Sends the values of the devices that moved since the last time, to the
  /// dashboard on screen as `updateDataModel` messages: the cards bound to
  /// them change in place, with no model run.
  void _publishDevices() {
    final live = this.live;
    for (final MapEntry(:key, :value) in DeviceReadings(
      database,
    ).all().entries) {
      final json = jsonEncode(value);
      if (_sentDevices[key] == json) continue;
      _sentDevices[key] = json;
      live?.publish({
        'type': 'a2ui',
        'message': {
          'version': a2uiVersion,
          'updateDataModel': {
            'surfaceId': dashboardSurfaceId,
            'path': devicePath(key),
            'value': value,
          },
        },
      });
    }
  }

  /// Moves the clock to [target] (held within the scenario) and reconciles.
  void moveTo(DateTime target) {
    database.clock.moveTo(target);
    _reconcileAndTellClock();
  }

  /// Restores every document and the clock to the first state, then reconciles.
  void reset() {
    database.reset();
    _reconcileAndTellClock();
  }

  /// The `clock` frame of the live connection: where the clock stands.
  Map<String, Object?> clockFrame() => {'type': 'clock', ...clockJson()};

  /// The clock as the `/clock` route answers.
  Map<String, Object?> clockJson() {
    final clock = database.clock;
    return {
      'now': clock.nowIso,
      'start': wallIso(clock.start),
      'end': wallIso(clock.end),
      'timeZone': 'America/Chicago',
    };
  }

  void _reconcileAndTellClock() {
    _engine.reconcile();
    live?.publish(clockFrame());
    _publishDevices();
  }

  /// Tells the screens of everyone the cake delivery concerns, but its
  /// requester, to refresh so they start tracking it.
  ///
  /// There is no inbox item: the trip card is the news, and an item that only
  /// asks to be acknowledged is noise beside it.
  void notifyDeliveryRequested(String requester) {
    final others = database
        .assigneesOf(calendar.guestsEvent())
        .where((person) => person != requester)
        .toList();
    if (others.isEmpty) return;
    live?.publish({'type': 'changed', 'users': others, 'reason': 'bakery'});
  }

  /// Tells the screens of everyone the order concerns to refresh: it moved on.
  void _publishOrder(Map<String, dynamic> order) {
    final users = {
      order['userId'] as String,
      ...database.assigneesOf(calendar.guestsEvent()),
    };
    live?.publish({
      'type': 'changed',
      'users': users.toList(),
      'reason': 'bakery',
    });
  }

  void _publishInbox(Map<String, Object?> item) {
    final userId = item['userId']! as String;
    live
      ?..publish({
        'type': 'inbox',
        'userId': userId,
        'unread': database.inboxFor(userId)['unread'],
        'item': item,
      })
      ..publish({
        'type': 'changed',
        'users': [userId],
        'reason': item['kind'],
      });
  }
}
