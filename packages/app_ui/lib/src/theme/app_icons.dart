import 'package:flutter/material.dart';

/// {@template app_icons}
/// Maps the icon names the model may emit to icons.
///
/// Unknown names fall back to [fallback], so a model slip never breaks a card.
/// {@endtemplate}
///
/// {@template app_icon_name}
/// An icon name from [AppIcons].
/// {@endtemplate}
abstract final class AppIcons {
  /// The icon shown for a name [AppIcons] does not know.
  static const IconData fallback = Icons.devices_other_rounded;

  static const Map<String, IconData> _byName = {
    'oven': Icons.microwave_rounded,
    'fridge': Icons.kitchen_rounded,
    'light': Icons.lightbulb_outline_rounded,
    'speaker': Icons.speaker_rounded,
    'thermostat': Icons.thermostat_rounded,
    'blinds': Icons.blinds_rounded,
    'lock': Icons.lock_outline_rounded,
    'garage': Icons.garage_outlined,
    'car': Icons.directions_car_filled_outlined,
    'charger': Icons.ev_station_outlined,
    'doorbell': Icons.doorbell_outlined,
    'meter': Icons.bolt_rounded,
    'dishwasher': Icons.local_laundry_service_outlined,
    'fan': Icons.air_rounded,
    'scene': Icons.auto_awesome_rounded,
    'alert': Icons.warning_amber_rounded,
    'trip': Icons.route_rounded,
    'delivery': Icons.local_shipping_outlined,
    'check': Icons.check_circle_outline_rounded,
    'restaurant': Icons.restaurant_rounded,
    'cake': Icons.cake_rounded,
    'school': Icons.school_rounded,
    'guests': Icons.groups_rounded,
    'flame': Icons.local_fire_department_rounded,
    'wine': Icons.wine_bar_rounded,
    'send': Icons.send_rounded,
    'chat': Icons.chat_bubble_outline_rounded,
    'undo': Icons.undo_rounded,
    'bell': Icons.notifications_none_rounded,
    'coffee': Icons.coffee_rounded,
    'radio': Icons.radio_rounded,
    'volume_down': Icons.volume_down_rounded,
    'timer': Icons.timer_outlined,
    'cart': Icons.shopping_cart_outlined,
    'share': Icons.ios_share_rounded,
    'rain': Icons.water_drop_outlined,
    'snowflake': Icons.ac_unit_rounded,
    'traffic': Icons.traffic_rounded,
    'savings': Icons.savings_outlined,
    'clock': Icons.schedule_rounded,
    'sparkle': Icons.auto_awesome_rounded,
    'edit': Icons.edit_outlined,
    'plus': Icons.add_rounded,
    'home': Icons.home_outlined,
    'play': Icons.play_arrow_rounded,
  };

  /// The icon names the model may use.
  static List<String> get names => _byName.keys.toList(growable: false);

  /// The icon for [name], or [fallback].
  static IconData byName(String? name) => _byName[name] ?? fallback;
}
