# home_catalog

Shared A2UI component catalog for A2UI VGV Smart Home.

This pure-Dart package is the source of truth for the components a kit
instance supports. The frontend zone consumes it to build Flutter widget
catalogs. The API server hands the catalog to `a2ui_agent`, which writes the
LLM's A2UI prompt from its schemas and checks every reply against them.

## Layout

```
lib/
├── home_catalog.dart   # Public barrel
└── src/
    ├── components/                     # GenUiComponent definitions
    ├── catalog/                        # homeCatalog + catalog id
    └── prompt/                         # catalog-prompt.prompt asset and
                                        # the card sizes for the layout prompt
```

## Catalog prompt

`lib/src/prompt/catalog-prompt.prompt` is a
[dotprompt](https://google.github.io/dotprompt/) asset describing the
relationships between this catalog's components — when to use each one, how they
compose — so the LLM picks the right component. It lives under `lib/` so the
package can export its location as the `catalogPromptAssetUri` package URI; the
API server resolves that, renders it once at startup, and prepends it as a
system message after the A2UI instructions `a2ui_agent` writes. It ships empty; run the
`build_genui_catalog_prompt` MCP prompt to generate it from your components, or
write it by hand. Keep it about component selection — do not restate A2UI/JSON
mechanics or app voice here.

## Adding a component

1. Add a `lib/src/components/<name>_definition.dart` extending
   `GenUiComponent` with a unique `name` and a `Schema`.
2. Add the definition to `homeCatalog` in
   `lib/src/catalog/home_catalog.dart`.
3. Export the new definition from `lib/home_catalog.dart`.
4. On the frontend, register a widget builder under the same name in the
   kit's `widget_builders.dart`.

The schemas in this package are built from `CommonSchemasV1` of
`package:a2ui_core`, the A2UI 1.0 common types, and nothing from the Flutter
renderer, which keeps this package pure Dart.
