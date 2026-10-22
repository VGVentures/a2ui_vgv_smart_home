import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the faces bundled with the package, which tests otherwise draw with
/// a stand-in font twice as wide, so a layout is measured with real text.
///
/// Run from the package root, as `flutter test` does.
Future<void> loadFonts() async {
  const faces = {
    'packages/app_ui/HostGrotesk': 'assets/fonts/HostGrotesk.ttf',
    'packages/app_ui/RobotoMono': 'assets/fonts/RobotoMono.ttf',
  };
  for (final MapEntry(key: family, value: path) in faces.entries) {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
