import 'package:flutter/material.dart';

/// {@template default_loading_indicator}
/// The default affordance rendered while a turn is in flight in
/// `GenUIZone.chat`.
/// {@endtemplate}
class DefaultLoadingIndicator extends StatelessWidget {
  /// {@macro default_loading_indicator}
  const DefaultLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
