import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_catalog/home_catalog.dart' show HomeActions;
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `ShoppingList` component.
Widget shoppingListBuilder(CatalogItemContext context) {
  final raw = context.data as Map<String, Object?>;
  return BoundProps(
    dataContext: context.dataContext,
    data: raw,
    builder: (_, props) =>
        _ShoppingListView(context: context, raw: raw, props: props),
  );
}

/// Writes ticks of bound rows and undoes them when a turn fails. The ticks of
/// literal rows live in [ShoppingList] itself, which resets them the same way.
class _ShoppingListView extends StatefulWidget {
  const _ShoppingListView({
    required this.context,
    required this.raw,
    required this.props,
  });

  final CatalogItemContext context;

  /// The props as the agent sent them, references intact.
  final Map<String, Object?> raw;

  /// The props with references resolved.
  final Map<String, Object?> props;

  @override
  State<_ShoppingListView> createState() => _ShoppingListViewState();
}

/// Holds the [OptimisticWrites] of the list and syncs them as its
/// dependencies change.
class _ShoppingListViewState extends State<_ShoppingListView> {
  final _writes = OptimisticWrites();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _writes.sync(context, widget.context.dataContext);
  }

  Map<String, Map<String, Object?>> get _rawItems => {
    for (final item in maps(widget.raw, 'items'))
      if (string(item, 'id') != null) string(item, 'id')!: item,
  };

  void _toggle(ShoppingItem item, {required bool checked}) {
    final raw = _rawItems[item.id];
    if (raw != null) _writes.write(widget.context, raw['checked'], checked);
    final listId = string(widget.raw, 'listId');
    if (listId == null) return;
    unawaited(
      dispatch(
        widget.context,
        homeAction(
          HomeActions.toggleTodo,
          checked ? 'Check off ${item.label}' : 'Uncheck ${item.label}',
          {'listId': listId, 'itemId': item.id, 'checked': checked},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final footer = props['footerAction'];
    final footerAction = footer is Map<String, Object?> ? footer : null;
    final footerText = footerAction == null
        ? null
        : string(footerAction, 'label');
    final listId = string(props, 'listId');
    return ShoppingList(
      title: string(props, 'title') ?? '',
      subtitle: string(props, 'subtitle'),
      icon: string(props, 'icon') ?? 'cart',
      items: [
        for (final item in maps(props, 'items'))
          ShoppingItem(
            id: string(item, 'id') ?? '',
            label: string(item, 'label') ?? '',
            detail: string(item, 'detail'),
            checked: item['checked'] == true,
          ),
      ],
      onToggle: _toggle,
      footerLabel: footerText,
      footerIcon: footerAction == null ? null : string(footerAction, 'icon'),
      onFooter: footerText == null || listId == null
          ? null
          : onPressed(
              widget.context,
              homeAction(HomeActions.shareList, footerText, {
                'listId': listId,
              }),
            ),
    );
  }
}
