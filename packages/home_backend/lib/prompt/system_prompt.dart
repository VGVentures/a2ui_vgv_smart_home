import 'dart:io';
import 'dart:isolate';

import 'package:dotprompt/dotprompt.dart';
import 'package:home_catalog/home_catalog.dart';

/// {@template system_prompt}
/// The system prompt sent with every request, rendered once at boot from four
/// dotprompt assets and joined into a single system message:
/// {@endtemplate}
///
/// 1. `assets/a2ui-prompt.prompt`: the A2UI mechanics (how to emit a surface).
/// 2. `assets/layout.prompt`: the layout, the panel grid and the proportion
///    each card is built for.
/// 3. The catalog package's `catalog-prompt.prompt`: which component when.
/// 4. `assets/system-prompt.prompt`: this demo's persona and rules.
///
/// They are one message because Anthropic and Gemini keep a single top-level
/// system field and silently drop later system entries.
class SystemPrompt {
  /// {@macro system_prompt}
  ///
  /// Wraps the rendered [text].
  const SystemPrompt(this.text);

  /// Renders the four assets against [catalog]. Throws a [StateError] when the
  /// A2UI asset is missing, so a misconfigured server fails at boot.
  static Future<SystemPrompt> load(
    GenUiComponentCatalog catalog, {
    String assetDirectory = 'assets',
  }) async {
    final names = catalog.components.keys.map((name) => '`$name`').join(', ');
    final input = {
      'a2uiVersion': a2uiVersion,
      'catalogId': catalog.id,
      'componentNames': names,
      'a2uiSchema': renderLeanA2uiMessageSchema(catalog),
      'cardFits': renderCardFits(catalog.components.values),
    };
    final catalogAsset = await Isolate.resolvePackageUri(catalogPromptAssetUri);
    final parts = [
      await _render(File('$assetDirectory/a2ui-prompt.prompt'), input),
      await _render(File('$assetDirectory/layout.prompt'), input),
      await _render(
        catalogAsset == null
            // An AOT build has no package config; the deploy copies the asset.
            ? File('$assetDirectory/catalog-prompt.prompt')
            : File.fromUri(catalogAsset),
        input,
      ),
      await _render(File('$assetDirectory/system-prompt.prompt'), input),
    ];
    return SystemPrompt(parts.where((p) => p.trim().isNotEmpty).join('\n\n'));
  }

  /// The prompt text.
  final String text;

  static Future<String> _render(File file, Map<String, Object?> input) async {
    if (!file.existsSync()) {
      throw StateError('Prompt asset not found at "${file.absolute.path}".');
    }
    final rendered = await Dotprompt().render(
      file.readAsStringSync(),
      DataArgument(input: input),
    );
    return rendered.messages
        .map((m) => m.content.whereType<TextPart>().map((p) => p.text).join())
        .where((text) => text.isNotEmpty)
        .join('\n');
  }
}
