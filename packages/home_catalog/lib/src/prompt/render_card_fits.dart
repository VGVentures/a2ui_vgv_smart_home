import 'package:home_catalog/src/components/gen_ui_component.dart';

/// The cells each card of [components] is built for, one line per card, for the
/// catalog prompt.
///
/// Rendered from `GenUiComponent.fit`, so the prompt can never say a size the
/// component does not declare. Components that are not cards are left out.
String renderCardFits(Iterable<GenUiComponent> components) => [
  for (final component in components)
    if (component.fit case final fit?)
      '- `${component.name}`: ${_sentence(fit.describe())}',
].join('\n');

String _sentence(String text) => text.endsWith('.') ? text : '$text.';
