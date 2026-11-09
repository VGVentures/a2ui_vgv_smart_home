import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:home_catalog/home_catalog.dart' show HomeActions;
import 'package:home_frontend/src/a2ui/a2ui.dart';
import 'package:home_frontend/src/catalog/builders/builder_helpers.dart';

/// Renders the `ShoppingList` component.
Widget shoppingListBuilder(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => _ShoppingListView(node: node, bound: props);

/// Writes ticks of bound rows and undoes them when a turn fails. The ticks of
/// literal rows live in [ShoppingList] itself, which resets them the same way.
class _ShoppingListView extends StatefulWidget {
  const _ShoppingListView({required this.node, required this.bound});

  final ComponentNode<ComponentImplementation> node;

  /// The props as the renderer resolved them, bindings still wrapped.
  final ComponentProps bound;

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
    _writes.sync(context);
  }

  // The binding of an item's `checked` prop, by the item's id. Null for a
  // literal row.
  WritableBinding<Object?>? _checkedOf(String id) {
    for (final item in widget.bound.list('items')) {
      if (item is! Map<String, Object?>) continue;
      if (ComponentProps.asString(item['id']) != id) continue;
      final checked = item['checked'];
      return checked is WritableBinding<Object?> ? checked : null;
    }
    return null;
  }

  void _toggle(ShoppingItem item, {required bool checked}) {
    _writes.write(_checkedOf(item.id), checked);
    final listId = widget.bound.string('listId');
    if (listId == null) return;
    unawaited(
      dispatch(
        A2uiSurface.of(context),
        widget.node,
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
    final props = plainProps(widget.bound);
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
              context,
              widget.node,
              homeAction(HomeActions.shareList, footerText, {
                'listId': listId,
              }),
            ),
    );
  }
}
