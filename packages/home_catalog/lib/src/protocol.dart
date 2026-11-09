/// The A2UI protocol version the demo speaks on the wire.
///
/// Every message the backend writes and the schema the model is given say it.
/// It is written here and nowhere else: moving to a newer protocol starts with
/// this constant, and the catalog's `protocolVersion` beside it.
const String a2uiVersion = '1.0';

/// The id of the one surface the dashboard is drawn on.
///
/// Every reply of the backend, and every `/live` update, is addressed to this
/// one surface, so the panel updates the dashboard it shows instead of
/// replacing it.
const String dashboardSurfaceId = 'dashboard';
