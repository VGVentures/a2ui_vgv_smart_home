/// The `package:` URI of the catalog prompt dotprompt asset this package ships.
///
/// The asset lives under `lib/` so it is addressable as a package URI rather
/// than by a filesystem path. Consumers (the API server) resolve this against
/// the running isolate's package config to locate and render the asset, so they
/// do not need to know where this package lives on disk.
///
/// The asset describes when to use each catalog component and how they relate;
/// it is authored by the `build_genui_catalog_prompt` MCP prompt and ships
/// empty.
final Uri catalogPromptAssetUri = Uri.parse(
  'package:home_catalog/src/prompt/catalog-prompt.prompt',
);
