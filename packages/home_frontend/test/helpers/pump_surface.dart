import 'package:a2ui_core/a2ui_core.dart' show ComponentModel;
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_catalog/home_catalog.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/genui_catalog.dart';
import 'package:home_frontend/src/catalog/widget_builders.dart';

/// One component of a surface, as a test writes it.
class Component {
  /// A component with [id], of [type], with [properties].
  const Component({
    required this.id,
    required this.type,
    required this.properties,
  });

  /// The component id.
  final String id;

  /// The component name in the catalog.
  final String type;

  /// Its props, without `id` and `component`.
  final Map<String, Object?> properties;
}

/// A surface built from [components] on the real home catalog.
///
/// The components are added to the model directly, not through a message, so a
/// test can show a builder props the schema would refuse: the builders
/// tolerate what they are given, and the backend keeps the model to the
/// schema.
SurfaceModel<ComponentImplementation> buildSurface(
  List<Component> components, {
  Map<String, Object?> data = const {},
  CatalogImplementation? catalog,
}) {
  final resolved =
      catalog ??
      buildCatalog(catalog: homeCatalog, widgetBuilders: widgetBuilders);
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [resolved],
    defaultVersion: A2uiProtocolVersion.v1_0,
  );
  addTearDown(processor.model.dispose);
  processor.processMessages([
    {
      'version': '1.0',
      'createSurface': {
        'surfaceId': 's',
        'catalogId': resolved.id,
        if (data.isNotEmpty) 'dataModel': data,
      },
    },
  ]);
  final surface = processor.model.getSurface('s')!;
  for (final component in components) {
    surface.componentsModel.addComponent(
      ComponentModel(component.id, component.type, component.properties),
    );
  }
  return surface;
}

/// Pumps [components] as a surface of [size], at the top left of the screen.
Future<SurfaceModel<ComponentImplementation>> pumpComponents(
  WidgetTester tester,
  List<Component> components, {
  required Size size,
  Map<String, Object?> data = const {},
}) async {
  final surface = buildSurface(components, data: data);
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1400, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: A2uiSurface(surface: surface),
          ),
        ),
      ),
    ),
  );
  return surface;
}

/// Pumps [components] as a surface that scrolls, so it has no bounded height.
Future<SurfaceModel<ComponentImplementation>> pumpScrolling(
  WidgetTester tester,
  List<Component> components,
) async {
  final surface = buildSurface(components);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(child: A2uiSurface(surface: surface)),
      ),
    ),
  );
  return surface;
}
