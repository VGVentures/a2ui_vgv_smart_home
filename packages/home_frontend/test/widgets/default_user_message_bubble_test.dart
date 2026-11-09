import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/src/widgets/default_user_message_bubble.dart';

void main() {
  Widget pump({ColorScheme? colorScheme, String message = 'hi'}) => MaterialApp(
    theme: colorScheme != null
        ? ThemeData.from(colorScheme: colorScheme)
        : ThemeData.light(),
    home: Scaffold(
      body: DefaultUserMessageBubble(message: message),
    ),
  );

  testWidgets('renders the message text', (tester) async {
    await tester.pumpWidget(pump(message: 'hi there'));

    expect(find.text('hi there'), findsOneWidget);
  });

  testWidgets('is right-aligned via Align with centerRight', (tester) async {
    await tester.pumpWidget(pump());

    expect(
      find.byWidgetPredicate(
        (w) => w is Align && w.alignment == Alignment.centerRight,
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses colorScheme.primaryContainer as background', (
    tester,
  ) async {
    const colorScheme = ColorScheme.light(
      primaryContainer: Color(0xFF112233),
      onPrimaryContainer: Color(0xFFFFFFFF),
    );

    await tester.pumpWidget(pump(colorScheme: colorScheme));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(Align),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, colorScheme.primaryContainer);

    final text = tester.widget<Text>(find.text('hi'));
    expect(text.style?.color, colorScheme.onPrimaryContainer);
  });
}
