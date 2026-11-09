import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:home_backend/a2ui/reply_pipeline.dart';
import 'package:home_backend/data/mock_database.dart';
import 'package:home_backend/devices/device_filler.dart';
import 'package:home_backend/devices/device_readings.dart';
import 'package:home_backend/validation/layout_composer.dart';
import 'package:home_backend/validation/layout_validator.dart';
import 'package:home_catalog/home_catalog.dart';

/// The processor `main.dart` builds: the home catalog, written as direct JSON.
A2uiRequestProcessor buildProcessor() =>
    A2uiGenerator(
      catalogs: [CatalogConfig(homeCatalog)],
      inferenceFormatFactory: const DirectJsonFormatFactory(
        allowedMessages: ['createSurface', 'updateComponents'],
      ),
    ).createProcessor(
      A2uiRendererCapabilities.forCatalogIds(
        [genUiCatalogId],
        version: A2uiProtocolVersion.v1_0,
      ),
    );

/// A reply pipeline over the devices of [database].
ReplyPipeline buildPipeline(
  MockDatabase database, {
  A2uiRequestProcessor? processor,
}) => ReplyPipeline(
  processor: processor ?? buildProcessor(),
  composer: LayoutComposer(homeCatalog),
  layout: LayoutValidator(homeCatalog),
  readings: DeviceReadings(database),
  filler: DeviceFiller(database, DeviceReadings(database)),
);

/// The `metadata` an A2UI 1.0 renderer sends: its capabilities and, for each
/// surface it shows, the data model.
Map<String, Object?> rendererMetadata({List<String> surfaces = const []}) => {
  'a2uiRendererCapabilities': A2uiRendererCapabilities.forCatalogIds([
    genUiCatalogId,
  ], version: A2uiProtocolVersion.v1_0).toJson(),
  if (surfaces.isNotEmpty)
    'a2uiRendererDataModel': {
      'version': '1.0',
      'surfaces': {for (final id in surfaces) id: <String, Object?>{}},
    },
};
