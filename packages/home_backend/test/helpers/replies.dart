import 'dart:convert';

typedef Json = Map<String, Object?>;

/// [messages] written the way the model writes A2UI: JSON inside tags.
String a2uiBlock(List<Json> messages) =>
    '<a2ui-json>${jsonEncode(messages)}</a2ui-json>';

Json _device(String id) => {
  'id': 'card_$id',
  'component': 'DeviceCard',
  'deviceId': id,
  'name': id,
  'status': 'The model said this',
  'value': '1',
  'weight': 4,
};

/// The components of a small dashboard: three device cards and the chips.
List<Json> dashboardComponents() => [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['row1', 'chips'],
  },
  {
    'id': 'row1',
    'component': 'Row',
    'children': ['card_oven', 'card_fridge', 'card_table_lights'],
  },
  _device('oven'),
  _device('fridge'),
  _device('table_lights'),
  {
    'id': 'chips',
    'component': 'ActionChips',
    'chips': [
      {
        'label': 'Dim the lights',
        'action': {'ask': 'Dim the lights'},
      },
    ],
  },
];

/// A reply that creates the dashboard: a `createSurface` and the components.
String createReply({
  String surfaceId = 'dashboard',
  List<Json>? components,
}) => a2uiBlock([
  {
    'version': '1.0',
    'createSurface': {
      'surfaceId': surfaceId,
      'catalogId': 'verygood.ventures/catalogs/home/v1',
      'sendDataModel': true,
    },
  },
  {
    'version': '1.0',
    'updateComponents': {
      'surfaceId': surfaceId,
      'components': components ?? dashboardComponents(),
    },
  },
]);

/// A reply that updates the dashboard already on screen.
String updateReply({List<Json>? components}) => a2uiBlock([
  {
    'version': '1.0',
    'updateComponents': {
      'surfaceId': 'dashboard',
      'components': components ?? dashboardComponents(),
    },
  },
]);
