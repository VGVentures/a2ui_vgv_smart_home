import 'package:a2ui_core/a2ui_core.dart';
import 'package:home_catalog/src/components/card_fit.dart';
import 'package:meta/meta.dart';

/// {@template gen_ui_component}
/// Base class for a component participating in A2UI VGV Smart Home catalog.
///
/// Concrete subclasses implement [name] and [schema] from [ComponentApi].
/// The intermediate base exists so the kit can layer kit-specific concerns
/// (e.g. a future `promptDescription`) onto every catalog component without
/// reaching back into upstream `a2ui_core`.
///
/// The frontend zone pairs each definition with a Flutter widget builder.
/// The API server renders the schema into the LLM system prompt.
/// {@endtemplate}
@immutable
abstract class GenUiComponent implements ComponentApi {
  /// {@macro gen_ui_component}
  ///
  /// Const so subclasses can be `const`.
  const GenUiComponent();

  /// The cells of the panel grid this component is built for, or `null` for a
  /// component that is not a card (a `Row`, a `Column`, the chips footer).
  CardFit? get fit => null;
}
