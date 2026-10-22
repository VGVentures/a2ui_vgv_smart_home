/// The A2UI protocol version the demo speaks on the wire.
///
/// The renderer the app is pinned to reads this one, so every message the
/// backend writes and the schema the model is given say it. It is written here
/// and nowhere else: moving to a newer protocol starts with this constant.
const String a2uiVersion = 'v0.9';

/// The id of the one surface the dashboard is drawn on.
///
/// The model writes a new surface id on every reply and the client keeps them
/// all on this one (see `StableSurface`), so the backend can address an update
/// to the open dashboard without knowing which reply it came from.
const String dashboardSurfaceId = 'dashboard';
