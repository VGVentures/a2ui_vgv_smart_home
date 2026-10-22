import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_catalog/home_catalog.dart' show HomeActions;
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `DeviceCard` component.
///
/// Works with literal and data-bound props. The model only chooses the device
/// and the control; the builder writes the event a press raises. A toggle or
/// stepper also shows the new value in the card's own state (and writes it to
/// the bound path), and a failed turn restores the old one.
Widget deviceCardBuilder(CatalogItemContext context) {
  final raw = context.data as Map<String, Object?>;
  return OptimisticWritesHost(
    dataContext: context.dataContext,
    builder: (_, writes) => BoundProps(
      dataContext: context.dataContext,
      data: raw,
      builder: (_, props) => _build(context, writes, raw, props),
    ),
  );
}

Widget _build(
  CatalogItemContext context,
  OptimisticWrites writes,
  Map<String, Object?> raw,
  Map<String, Object?> props,
) {
  final control = props['control'];
  final controlMap = control is Map<String, Object?> ? control : null;
  final deviceId = string(raw, 'deviceId');
  // A device the panel can command shows its on/off switch even when the
  // model sent no control; `none` is the way to ask for no control at all.
  final type = controlMap == null
      ? (deviceId == null ? DeviceControlType.none : DeviceControlType.toggle)
      : DeviceControlType.byName(string(controlMap, 'type'));
  final tone = AppTone.byName(string(props, 'tone'));
  final name = string(props, 'name') ?? '';
  final label = name.toLowerCase();
  final controlLabel = controlMap == null ? null : string(controlMap, 'label');
  final command = controlMap == null ? null : string(controlMap, 'command');
  final isActive = props['isActive'] == true;
  final value = _text(props['value']);

  return DeviceCard(
    name: name,
    status: _text(props['status']) ?? '',
    room: string(props, 'room'),
    icon: string(props, 'icon'),
    tone: tone,
    value: value,
    unit: string(props, 'unit'),
    delta: _text(props['delta']),
    tag: _tag(props['tag'], tone),
    isActive: isActive,
    isLoading: props['isLoading'] == true,
    controlType: type,
    controlLabel: controlLabel,
    controlIcon: controlMap == null ? null : string(controlMap, 'icon'),
    onToggle: type == DeviceControlType.toggle && deviceId != null
        ? (next) {
            writes.write(context, raw['isActive'], next);
            unawaited(
              dispatch(
                context,
                homeAction(
                  HomeActions.toggleDevice,
                  next ? 'Turn on $label' : 'Turn off $label',
                  {'deviceId': deviceId, 'on': next},
                ),
              ),
            );
          }
        : null,
    onIncrement: type == DeviceControlType.stepper && deviceId != null
        ? () => _step(context, writes, raw, deviceId, label, value, 'up')
        : null,
    onDecrement: type == DeviceControlType.stepper && deviceId != null
        ? () => _step(context, writes, raw, deviceId, label, value, 'down')
        : null,
    onPressed: type == DeviceControlType.button && command != null
        ? () => unawaited(
            dispatch(
              context,
              homeAction(
                HomeActions.runDeviceAction,
                controlLabel ?? 'Run $label',
                {'deviceId': deviceId, 'command': command},
              ),
            ),
          )
        : null,
  );
}

void _step(
  CatalogItemContext context,
  OptimisticWrites writes,
  Map<String, Object?> raw,
  String deviceId,
  String label,
  String? value,
  String direction,
) {
  // The step size is 1.
  final current = num.tryParse(value ?? '');
  if (current != null) {
    final next = direction == 'up' ? current + 1 : current - 1;
    writes.write(context, raw['value'], '$next');
  }
  unawaited(
    dispatch(
      context,
      homeAction(
        HomeActions.adjustDevice,
        '${direction == 'up' ? 'Raise' : 'Lower'} $label',
        {'deviceId': deviceId, 'direction': direction},
      ),
    ),
  );
}

String? _text(Object? value) {
  if (value == null) return null;
  return value is String ? value : '$value';
}

StatusTag? _tag(Object? value, AppTone tone) {
  if (value is! Map<String, Object?>) return null;
  final label = string(value, 'label');
  if (label == null) return null;
  final kind = StatusTagKind.byName(string(value, 'kind'));
  final icon = string(value, 'icon');
  return StatusTag(
    label: label,
    kind: kind,
    icon: icon,
    dot: kind == StatusTagKind.updated && icon == null ? AppColors.ink : null,
    tint: AppColors.overlayOnTintStrong,
    ink: tone == AppTone.neutral ? AppColors.ink : tone.ink,
  );
}
