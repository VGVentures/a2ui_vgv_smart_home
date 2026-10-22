import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// {@template home_user}
/// A person who can be selected on the smart home panel.
/// {@endtemplate}
@immutable
class HomeUser {
  /// {@macro home_user}
  const HomeUser({
    required this.id,
    required this.name,
    required this.role,
    this.photo,
  });

  /// {@macro home_user}
  ///
  /// Reads the user from the JSON the backend sent, decoding the photo when it
  /// is there.
  factory HomeUser.fromJson(Map<String, dynamic> json) => HomeUser(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    photo: switch (json['photo']) {
      final String encoded => base64Decode(encoded),
      _ => null,
    },
  );

  /// The id the backend knows the user by.
  final String id;

  /// The name shown for the user.
  final String name;

  /// What the user is to the household, for example a parent.
  final String role;

  /// The encoded profile photo, when the backend has one.
  ///
  /// Not part of equality: it is the same person with or without it.
  final Uint8List? photo;

  /// The request sent to the model to build this user's dashboard.
  String get prompt =>
      'Build the home dashboard for $name (user_id "$id", role: $role). '
      'Call the tools with user_id "$id" to fetch their profile, what just '
      'happened and what is next (get_home_activity), their inbox (get_inbox), '
      'the Google Home '
      'devices and automations, their calendar, trips, the energy tariff and '
      'the recipe timeline, then rank the cards by that activity and compose '
      'the dashboard from the data. '
      '$_promptRules';

  @override
  bool operator ==(Object other) =>
      other is HomeUser &&
      other.id == id &&
      other.name == name &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);
}

const _promptRules = '''
The dashboard is for a landscape kitchen wall tablet. The sidebar sits to its
left, and the brand header and the ask bar sit above it.
The clock sits at the bottom-left, at the start of the chips row.
Keep everything on one screen without scrolling.
Building the dashboard is read-only: never call a tool that changes a
device, scene, schedule, list or order.
Use only data returned by the tools. Do not ask
questions and do not add a chat reply, respond only with the dashboard.''';
