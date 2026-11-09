import 'package:a2ui_vgv_smart_home/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:a2ui_vgv_smart_home/l10n/gen/app_localizations.dart';

/// Reads the generated localizations as `context.l10n`.
extension AppLocalizationsX on BuildContext {
  /// The localizations of the closest [Localizations] above this context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
