import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `ChargeCard` component.
Widget chargeCardBuilder(CatalogItemContext context) {
  return BoundProps(
    dataContext: context.dataContext,
    data: context.data as Map<String, Object?>,
    builder: (_, data) {
      final percent = data['percent'];
      final tag = data['tag'];
      return ChargeCard(
        title: string(data, 'title') ?? 'Car',
        status: string(data, 'status'),
        percent: percent is num ? percent.round() : 0,
        range: string(data, 'range'),
        summary: string(data, 'summary'),
        window: string(data, 'window'),
        windowIcon: string(data, 'windowIcon') ?? 'clock',
        tag: tag is Map<String, Object?> ? string(tag, 'label') : null,
        tagKind: StatusTagKind.byName(
          tag is Map<String, Object?> ? string(tag, 'kind') : null,
        ),
        tagIcon: tag is Map<String, Object?> ? string(tag, 'icon') : null,
      );
    },
  );
}
