import 'package:flutter/material.dart';

/// {@template default_user_message_bubble}
/// The default bubble rendered for a user message in `GenUIZone.chat`.
///
/// Right-aligned and themed from `Theme.of(context).colorScheme` so it adopts
/// the host's branding without pulling in extra dependencies.
/// {@endtemplate}
class DefaultUserMessageBubble extends StatelessWidget {
  /// {@macro default_user_message_bubble}
  const DefaultUserMessageBubble({required this.message, super.key});

  /// The user message text to render.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(color: colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
