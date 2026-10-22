import 'package:flutter/material.dart';

/// {@template default_error_bubble}
/// The default notice rendered for a failed turn in `GenUIZone.chat`.
///
/// Themed from the `error` roles of `Theme.of(context).colorScheme` so it reads
/// as a failure without pulling in extra dependencies.
/// {@endtemplate}
class DefaultErrorBubble extends StatelessWidget {
  /// {@macro default_error_bubble}
  const DefaultErrorBubble({required this.message, super.key});

  /// The failure description to render.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
