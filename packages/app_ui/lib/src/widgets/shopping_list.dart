import 'package:app_ui/src/theme/app_colors.dart';
import 'package:app_ui/src/theme/app_icons.dart';
import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:app_ui/src/widgets/app_card.dart';
import 'package:app_ui/src/widgets/optimistic_scope.dart';
import 'package:flutter/material.dart';

/// {@template shopping_item}
/// One row of a [ShoppingList].
/// {@endtemplate}
class ShoppingItem {
  /// {@macro shopping_item}
  const ShoppingItem({
    required this.id,
    required this.label,
    this.detail,
    this.checked = false,
  });

  /// The stable id of the row, passed back when it is ticked.
  final String id;

  /// The item name, for example `Lemons`.
  final String label;

  /// A line next to the [label], for example the quantity.
  final String? detail;

  /// Whether the item is ticked off.
  final bool checked;
}

/// {@template shopping_list}
/// A short checklist the user ticks off.
///
/// A tap shows the new tick at once in local state, whether or not the item is
/// bound to data. The local tick is dropped when that item's `checked` changes
/// (the surface answered) and when the nearest [OptimisticScope] bumps its
/// revision (the turn failed).
/// {@endtemplate}
class ShoppingList extends StatefulWidget {
  /// {@macro shopping_list}
  const ShoppingList({
    required this.title,
    required this.items,
    this.subtitle,
    this.icon = 'cart',
    this.onToggle,
    this.footerLabel,
    this.footerIcon,
    this.onFooter,
    super.key,
  });

  /// The list heading.
  final String title;

  /// A line under the [title].
  final String? subtitle;

  /// {@macro app_icon_name}
  final String icon;

  /// Up to six rows are shown.
  final List<ShoppingItem> items;

  /// Called with the row and the value the tap asks for.
  final void Function(ShoppingItem item, {required bool checked})? onToggle;

  /// The label of the footer pill, or null for no footer.
  final String? footerLabel;

  /// {@macro app_icon_name}
  final String? footerIcon;

  /// Called when the footer pill is pressed.
  final VoidCallback? onFooter;

  @override
  State<ShoppingList> createState() => _ShoppingListState();
}

/// Holds the ticks the person made, until the next answer settles.
class _ShoppingListState extends State<ShoppingList> {
  final Map<String, bool> _ticks = {};
  int? _revision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = OptimisticScope.of(context);
    if (_revision != null && _revision != revision) _ticks.clear();
    _revision = revision;
  }

  @override
  void didUpdateWidget(ShoppingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = {for (final i in oldWidget.items) i.id: i.checked};
    _ticks.removeWhere((id, _) {
      final now = widget.items.where((i) => i.id == id).firstOrNull;
      return now == null || before[id] != now.checked;
    });
  }

  void _toggle(ShoppingItem item) {
    final next = !item.checked;
    setState(() => _ticks[item.id] = next);
    widget.onToggle?.call(item, checked: next);
  }

  static const double _padding = 2 * AppSpacing.cardPadding + 2;
  static const double _header = 58;
  static const double _gap = AppSpacing.cardContentGap;
  static const double _footer = _gap + AppSpacing.buttonHeight;

  /// A row is 64 high and a divider is 1 high under it.
  static const double _rowExtent = 65;

  /// The tallest a row grows, when the list has room to spare.
  static const double _rowMax = 88;

  /// How many rows fit in [height], with or without the footer pill.
  ///
  /// The footer is dropped when fewer than three rows would fit beside it.
  (int, bool) _fit(double height, {required bool hasFooter}) {
    int rows(double chrome) => ((height - chrome) / _rowExtent).floor();
    if (hasFooter) {
      final withFooter = rows(_padding + _header + _gap + _footer);
      if (withFooter >= 3) return (withFooter, true);
    }
    return (rows(_padding + _header + _gap), false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasFooter = widget.footerLabel != null;
        if (!constraints.hasBoundedHeight) {
          return _card(6, footer: hasFooter, bounded: false);
        }
        final (rows, footer) = _fit(
          constraints.maxHeight,
          hasFooter: hasFooter,
        );
        return _card(rows.clamp(2, 6), footer: footer, bounded: true);
      },
    );
  }

  Widget _card(int rows, {required bool footer, required bool bounded}) {
    final subtitle = widget.subtitle;
    final footerLabel = widget.footerLabel;
    final footerIcon = widget.footerIcon;
    final title = widget.title;
    final icon = widget.icon;
    final shown = [
      for (final item in widget.items.take(6))
        ShoppingItem(
          id: item.id,
          label: item.label,
          detail: item.detail,
          checked: _ticks[item.id] ?? item.checked,
        ),
    ];
    final open = shown.where((item) => !item.checked).length;
    final visible = shown.take(rows).toList();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              IconTile(
                icon: AppIcons.byName(icon),
                background: AppColors.brandYellow100,
                color: AppColors.brandYellow300,
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Text('$open', style: AppTypography.headlineLarge),
            ],
          ),
          const SizedBox(height: _gap),
          // The rows share the room between the header and the footer; a row
          // never grows past [_rowMax], so a short list stays a list.
          if (bounded)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => _rows(
                  visible,
                  (constraints.maxHeight / visible.length - 1).clamp(
                    64.0,
                    _rowMax,
                  ),
                ),
              ),
            )
          else
            _rows(visible, 64),
          if (footer && footerLabel != null) ...[
            const SizedBox(height: _gap),
            PillButton(
              label: footerLabel,
              onPressed: widget.onFooter,
              icon: footerIcon == null ? null : AppIcons.byName(footerIcon),
            ),
          ],
        ],
      ),
    );
  }
}

/// Builds the rows of the list.
extension on _ShoppingListState {
  Widget _rows(List<ShoppingItem> visible, double height) {
    return Column(
      children: [
        for (final (i, item) in visible.indexed)
          _Row(
            item: item,
            height: height,
            divider: i < visible.length - 1,
            onTap: widget.onToggle == null ? null : () => _toggle(item),
          ),
      ],
    );
  }
}

/// One item of the shopping list.
class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.height,
    required this.divider,
    required this.onTap,
  });

  final ShoppingItem item;
  final double height;

  /// Whether a hairline closes the row.
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final detail = item.detail;
    return Semantics(
      checked: item.checked,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height + (divider ? 1 : 0),
          decoration: BoxDecoration(
            border: divider
                ? const Border(bottom: BorderSide(color: AppColors.line))
                : null,
          ),
          child: Row(
            children: [
              _Checkbox(checked: item.checked),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTypography.bodyLargeEmphasized.copyWith(
                    color: item.checked ? AppColors.ink2 : AppColors.ink,
                  ),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(width: AppSpacing.s2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    detail,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The checkbox drawn for an item, ticked or not.
class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: checked ? AppColors.ink : null,
        borderRadius: BorderRadius.circular(12),
        border: checked
            ? null
            : Border.all(color: AppColors.brandNeutral200, width: 2),
      ),
      child: checked
          ? const Icon(
              Icons.check_rounded,
              size: 24,
              color: AppColors.onPrimary,
            )
          : null,
    );
  }
}
