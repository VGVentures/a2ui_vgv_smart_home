import 'package:home_catalog/home_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('homeCatalog', () {
    test('uses a stable, VGV-owned catalog id', () {
      // The id is part of the public contract between the API server and any
      // frontend that consumes this catalog. Bumping it is a breaking change
      // for already-generated surfaces.
      expect(genUiCatalogId, 'verygood.ventures/catalogs/home/v1');
    });

    test('ships the layout primitives and the home components', () {
      expect(
        homeCatalog.components.keys.toList(),
        [
          'Column',
          'Row',
          'PlanTimeline',
          'DeviceCard',
          'ActionChips',
          'TripCard',
          'ChargeCard',
          'SceneCard',
          'HeadsUpCard',
          'ChangeSummary',
          'CountdownCard',
          'ShoppingList',
        ],
      );
    });

    test('each component is its canonical definition', () {
      expect(
        homeCatalog.components['Column'],
        isA<ColumnComponentDefinition>(),
      );
      expect(
        homeCatalog.components['Row'],
        isA<RowComponentDefinition>(),
      );
      expect(
        homeCatalog.components['PlanTimeline'],
        isA<PlanTimelineComponentDefinition>(),
      );
      expect(
        homeCatalog.components['DeviceCard'],
        isA<DeviceCardComponentDefinition>(),
      );
      expect(
        homeCatalog.components['ActionChips'],
        isA<ActionChipsComponentDefinition>(),
      );
      expect(
        homeCatalog.components['TripCard'],
        isA<TripCardComponentDefinition>(),
      );
      expect(
        homeCatalog.components['ChargeCard'],
        isA<ChargeCardComponentDefinition>(),
      );
      expect(
        homeCatalog.components['SceneCard'],
        isA<SceneCardComponentDefinition>(),
      );
      expect(
        homeCatalog.components['HeadsUpCard'],
        isA<HeadsUpCardComponentDefinition>(),
      );
      expect(
        homeCatalog.components['ChangeSummary'],
        isA<ChangeSummaryComponentDefinition>(),
      );
    });
  });
}
