import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

extension PumpComponent on WidgetTester {
  Future<void> pumpComponent(Widget child) {
    return pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
