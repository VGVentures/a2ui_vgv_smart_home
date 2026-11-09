import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_catalog/home_catalog.dart' show HomeActions;
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `SceneCard` component.
Widget sceneCardBuilder(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final data = plainProps(props);
  final sceneId = string(data, 'sceneId');
  final name = string(data, 'name') ?? '';
  final actionLabel = string(data, 'actionLabel') ?? 'Start';
  return SceneCard(
    name: name,
    description: string(data, 'description'),
    icon: string(data, 'icon') ?? 'scene',
    tone: AppTone.byName(string(data, 'tone'), fallback: AppTone.lighting),
    state: SceneState.byName(string(data, 'state')),
    settings: [
      for (final setting in (data['settings'] as List<Object?>? ?? const []))
        if (setting is String) setting,
    ],
    actionLabel: actionLabel,
    onRun: sceneId == null
        ? null
        : onPressed(
            context,
            node,
            homeAction(HomeActions.runScene, '$actionLabel $name', {
              'sceneId': sceneId,
            }),
          ),
  );
}
