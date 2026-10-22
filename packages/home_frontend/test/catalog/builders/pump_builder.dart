import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

/// A builder pumped inside a themed scaffold, with the events it dispatched.
class BuilderHarness {
  BuilderHarness(this.data) : events = [];

  final DataContext data;
  final List<UserActionEvent> events;
}

/// Pumps [builder] with [component] as its data.
Future<BuilderHarness> pumpBuilder(
  WidgetTester tester,
  Widget Function(CatalogItemContext) builder,
  String type,
  Map<String, Object?> component, {
  Map<String, Object?> model = const {},
  ValueNotifier<int>? revision,
}) async {
  final data = DataContext(InMemoryDataModel(), DataPath('/'));
  model.forEach((path, value) => data.update(DataPath(path), value));
  final harness = BuilderHarness(data);
  Widget scoped(Widget child) => revision == null
      ? child
      : ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (_, value, _) =>
              OptimisticScope(revision: value, child: child),
        );
  await tester.pumpWidget(
    scoped(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (buildContext) => builder(
                CatalogItemContext(
                  data: component,
                  id: 'id',
                  type: type,
                  buildChild: (id, [dataContext]) => const SizedBox(),
                  dispatchEvent: (event) {
                    if (event is UserActionEvent) harness.events.add(event);
                  },
                  buildContext: buildContext,
                  dataContext: data,
                  getComponent: (_) => null,
                  getCatalogItem: (_) => null,
                  surfaceId: 's',
                  reportError: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return harness;
}
