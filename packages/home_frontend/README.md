# A2UI VGV Smart Home frontend

The widget layer of the A2UI VGV Smart Home panel: one widget builder per catalog component, the zone controller, and `HttpGenUIAgent`, which talks to the backend.

## Package Structure

```
lib/home_frontend.dart    # Package public API
```

## Integrating In Your App

1. Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  home_frontend:
    path: packages/home_frontend
```

Get dependencies:

```bash
flutter pub get
```

2. Add a `GenUIZone` to your application

A controlled GenUI zone is a bounded location in your app where GenUI renders a personalized surface.
Add `GenUIZone` widgets to your feature screens and supply a `zoneId` and `dataContext`.

```dart
import 'package:home_frontend/home_frontend.dart';

GenUIZone.chat(
  zoneId: 'home_chat',
  dataContext: {'userId': currentUser.id},
);
```

A failed turn is appended to the conversation as a notice rather than replacing
it, and an in-flight turn shows a loading affordance after the last item. Pass
`errorBuilder` or `loadingBuilder` to render your own:

```dart
GenUIZone.chat(
  zoneId: 'home_chat',
  dataContext: {'userId': currentUser.id},
  // The error itself, so a notice can branch on the type.
  errorBuilder: (context, error) => error is AuthError
      ? const SignInAgainBanner()
      : MyErrorBanner('$error'),
  loadingBuilder: (context) => const MySpinner(),
);
```

## The Gemini key

The kit's API server needs the caller's own Gemini API key as an
`Authorization: Bearer <key>` header on every request that calls Gemini.
`HttpGenUIAgent` attaches it for you through the required `tokenProvider`
callback:

```dart
import 'package:home_frontend/home_frontend.dart';

HttpGenUIAgent(
  catalog: homeCatalog,
  widgetBuilders: widgetBuilders,
  tokenProvider: () async => keyTheUserEntered,
);
```

The provider is called on every request, so a key the user changes takes effect
on the next one. A `null` or empty result is treated as an `AuthError` before
the request leaves the client, so a missing key surfaces the same way as a
server-side 401.

Key failures surface as `AuthError` thrown from `sendMessage`. UI code
that needs to distinguish them from generic transport errors can branch
on the type:

```dart
try {
  await agent.sendMessage(text);
} on AuthError {
  // ask the user for their Gemini key again
} on HttpException {
  // generic transport or server error
}
```

`AuthError` extends `HttpException`, so any code that already catches
`HttpException` continues to handle auth failures without changes.
