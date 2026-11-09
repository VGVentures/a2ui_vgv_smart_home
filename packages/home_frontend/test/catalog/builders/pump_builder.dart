import 'package:a2ui_core/a2ui_core.dart' show ComponentModel;
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';

/// A builder pumped inside a themed scaffold, with the actions it raised.
class BuilderHarness {
  BuilderHarness(this.surface) : events = [];

  /// The surface the component is drawn on.
  final SurfaceModel<ComponentImplementation> surface;

  /// The actions the component raised on its surface, in order.
  final List<A2uiRendererAction> events;

  /// The value at [path] of the surface's data model.
  Object? read(String path) => surface.dataModel.get(path);

  /// Writes [value] at [path], as a `/live` update would.
  void write(String path, Object? value) => surface.dataModel.set(path, value);
}

/// The renderer catalog of the one home component [type], drawn by [builder].
CatalogImplementation singleCatalog(
  String type,
  ComponentWidgetBuilder builder,
) => CatalogImplementation(
  id: genUiCatalogId,
  protocolVersion: A2uiProtocolVersion.v1_0,
  components: [
    ComponentImplementation(
      name: type,
      schema: homeCatalog.components[type]!.schema,
      builder: builder,
    ),
  ],
);

/// Pumps [builder] with [component] as the root of a real surface, so its
/// props are resolved by the renderer exactly as in the app. [component] is
/// not checked against the schema.
Future<BuilderHarness> pumpBuilder(
  WidgetTester tester,
  ComponentWidgetBuilder builder,
  String type,
  Map<String, Object?> component, {
  Map<String, Object?> model = const {},
  ValueNotifier<int>? revision,
}) async {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [singleCatalog(type, builder)],
    defaultVersion: A2uiProtocolVersion.v1_0,
  );
  addTearDown(processor.model.dispose);
  processor.processMessages([
    {
      'version': '1.0',
      'createSurface': {
        'surfaceId': 's',
        'catalogId': genUiCatalogId,
      },
    },
    for (final entry in model.entries)
      {
        'version': '1.0',
        'updateDataModel': {
          'surfaceId': 's',
          'path': entry.key,
          'value': entry.value,
        },
      },
  ]);
  final harness = BuilderHarness(processor.model.getSurface('s')!);
  // Added to the model directly, not through a message, so a builder can be
  // shown props the schema would refuse: the builders tolerate what they are
  // given, and the backend is what keeps the model to the schema.
  harness.surface.componentsModel.addComponent(
    ComponentModel(
      'root',
      type,
      {...component}
        ..remove('id')
        ..remove('component'),
    ),
  );
  harness.surface.onAction.subscribe(harness.events.add);
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
            child: A2uiSurface(surface: harness.surface),
          ),
        ),
      ),
    ),
  );
  return harness;
}
