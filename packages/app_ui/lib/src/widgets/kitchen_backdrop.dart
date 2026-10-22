import 'dart:async';

import 'package:flutter/widgets.dart';

/// {@template kitchen_light}
/// The light the kitchen behind the panel is photographed in, one per part of
/// the day the design shows.
/// {@endtemplate}
enum KitchenLight {
  /// Early daylight.
  morning,

  /// Full daylight.
  day,

  /// The low light before dusk.
  sunset,

  /// After dark, with the lights on.
  evening;

  /// The photograph of the kitchen in this light.
  ImageProvider get image => AssetImage(
    'assets/images/kitchen_$name.jpg',
    package: 'app_ui',
  );

  /// Decodes every kitchen into the image cache, so a change of light never
  /// waits on an image. A kitchen that fails to load is skipped: the backdrop
  /// is only a backdrop and must not hold the app back.
  static Future<void> preload() => Future.wait([
    for (final light in values) load(light.image),
  ]);

  /// Resolves [image] into the image cache and completes once it has loaded or
  /// failed.
  @visibleForTesting
  static Future<void> load(ImageProvider image) {
    final loaded = Completer<void>();
    final stream = image.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void finish() {
      stream.removeListener(listener);
      loaded.complete();
    }

    listener = ImageStreamListener(
      (_, _) => finish(),
      onError: (_, _) => finish(),
    );
    stream.addListener(listener);
    return loaded.future;
  }
}

/// {@template kitchen_backdrop}
/// The kitchen behind the panel, filling the space it is given. A new [light]
/// fades in over the one before.
/// {@endtemplate}
class KitchenBackdrop extends StatelessWidget {
  /// {@macro kitchen_backdrop}
  const KitchenBackdrop({required this.light, super.key});

  /// The light the kitchen is shown in.
  final KitchenLight light;

  /// How long a new [light] takes to fade in.
  static const Duration fade = Duration(milliseconds: 600);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: fade,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        child: Image(
          key: ValueKey(light),
          image: light.image,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
