# home_catalog

Pure-Dart source of truth for the A2UI components this app supports. It answers
"what components exist and what shape is their data". It does not answer "how
are they rendered" — that is the frontend package's job.

Two consumers read this package:

- The Flutter frontend pairs each component with a widget builder and renders
  surfaces.
- The API server gives the catalog to `a2ui_agent`, which writes the component
  schemas into the LLM prompt and rejects a reply that uses a component that
  does not exist here.

## Layout

```
lib/
├── home_catalog.dart              public barrel
└── src/
    ├── catalog/home_catalog.dart  homeCatalog + genUiCatalogId
    ├── components/
    │   ├── gen_ui_component.dart       the GenUiComponent base class
    │   ├── catalog_schemas.dart        reusable schema helpers
    │   └── *_component_definition.dart one file per component
    └── prompt/
        ├── catalog-prompt.prompt       component-selection prompt asset
        ├── catalog_prompt_asset.dart   the asset's package URI
        └── render_card_fits.dart       the card sizes for the layout prompt
test/                                   mirrors lib/src/
```

## Adding a component

Six steps. A component that skips any of them either fails to compile, fails a
test, or throws at frontend startup.

1. **Define it.** Add `lib/src/components/<snake_name>_component_definition.dart`
   holding a `class <Name>ComponentDefinition extends GenUiComponent` with a
   `const` constructor.

2. **Register it.** Add an instance to the `components` list of
   `homeCatalog` in `lib/src/catalog/home_catalog.dart`.

3. **Export it.** Add a `show`-scoped export to `lib/home_catalog.dart`.
   The barrel is sorted by path and every export names its symbols explicitly;
   keep both properties.

4. **Test it.** Add `test/components/<snake_name>_component_definition_test.dart`.
   Existing tests assert the `name`, the `required` list, and the shape of each
   interesting property by reading `definition.schema.value`. Follow that.

5. **Build its widget.** Register a builder under the same `name` in the
   frontend package's `lib/src/catalog/widget_builders.dart`. See that package's
   `AGENTS.md`.

6. **Say which cells it fits.** A home card overrides `fit` with a `CardFit`:
   the cell it is best for and the others it is built for, each a `GridCell` of
   the columns it spans (out of 12) and the rows it takes (1 half tall, 2 full
   height), plus a note on when each applies. Take them from the Figma
   component catalog: its sizes are the source of truth, and a state or
   component that is not on it does not belong here. This is the one place a
   card's size is written. The layout prompt's size lines are rendered from it
   (`renderCardFits`, the `cardFits` variable), the backend's `LayoutValidator`
   rejects a screen that puts the card at any other span, and the frontend
   draws it at exactly that cell, so never write a size into a prompt by hand.
   Add sample content to `_full` in the frontend's
   `test/catalog/card_fit_test.dart`, which draws the card in every cell it
   lists and fails on any overflow. A component that is not a card (a `Row`)
   leaves `fit` null. If the card can be full height, teach `_isFullHeight` in
   `layout_validator.dart` and `_isFullHeightCard` in the frontend's
   `grid_layout.dart` which prop makes it so.

Step 5 is not optional. `buildCatalog` in the frontend throws a `StateError`
listing every component name with no registered builder, at construction time.
A component defined here and not built there breaks the app on launch.

### name

`name` is the A2UI discriminator, not a label. `GenUiComponent` writes it as the
`component` enum of the schema, and the frontend keys its builder map by the
same string. It must be unique across the catalog and
identical in all three places.

Use the canonical A2UI name in PascalCase, matching the existing entries:
`Column`, `Row`, `DeviceCard`, `HeadsUpCard`.

### schema

Build `schema` from the `CatalogSchemas` helpers plus `json_schema_builder`'s
`S` constructors. Reach for a helper before hand-rolling a shape:

| Need | Helper |
| --- | --- |
| A child component id | `CatalogSchemas.childList()` for a list of children, literal or data-bound |
| A string, number, or bool that may be data-bound | `CatalogSchemas.dynamicString()`, `.dynamicNumber()`, `.dynamicBoolean()` |
| A list that may be data-bound | `CatalogSchemas.dynamicList()` |
| A path into the data model | `CatalogSchemas.dataBinding()` |
| An icon, a tone or a status tag | `CatalogSchemas.icon()`, `.tone()`, `.statusTag()` |
| A user-triggered action | `HomeActions.spec()` |

They sit on `CommonSchemasV1` from `a2ui_core`, the A2UI 1.0 common types, so a
binding is written `{"@path": "/devices/oven/value"}`.

Reserved: do not declare a property named `component`. `GenUiComponent` adds
that key itself as the type discriminator.

## Imports

This package is pure Dart and depends only on `a2ui_core`,
`json_schema_builder`, and `meta`.

- **Never import `package:a2ui_flutter`.** It is a Flutter package. Adding it
  makes this package unusable by the Dart-only API server and breaks the build.
- **Do not import `package:a2ui_core` in a component definition.** A definition
  needs `GenUiComponent`, `CatalogSchemas` and `json_schema_builder` only. The
  three files that do import it are deliberate: `gen_ui_component.dart`,
  `catalog_schemas.dart` and `catalog/home_catalog.dart`, which declares the
  `GenUiComponentCatalog` typedef.
- **`a2ui_core` is declared in each package that imports it** (this one, the
  frontend and the backend), all on `^0.5.0` from pub.dev. Importing it
  through another package breaks `depend_on_referenced_packages`.

## catalog-prompt.prompt

`lib/src/prompt/catalog-prompt.prompt` is a dotprompt asset describing when to
use each component and how they compose. It ships empty, and the API server
sends no system message for it while it is empty.

It is a separate concern from the schemas: the schema says a component is
*legal*, the prompt says when it is *appropriate*. Adding a component makes it
legal but leaves the model with no guidance, so update this asset whenever the
component set changes. Either edit the body below the closing `---`, or
regenerate it with the `build_genui_catalog_prompt` MCP prompt.

Keep it to component selection. A2UI and JSON mechanics come from the server's
own prompt layer, and app voice comes from the system prompt.

The asset's location is exported as `catalogPromptAssetUri`, a `package:` URI.
Consumers resolve it against the package config, so never hand a consumer a
filesystem path to it, and never move it out of `lib/`.

## Catalog id

`genUiCatalogId` is the stable identifier both the server and the renderer
resolve against. Changing it invalidates every A2UI `createSurface` message
that names the old value. Treat it as a breaking change.

## Generating a component instead of writing it

The `convert_design_system_to_genui_catalog_item` MCP prompt takes a Flutter
widget — a file path, a class name, or its source — and produces the whole set:
the definition file here, the `widget_builders.dart` entry in the frontend, and
tests for both. Prefer it when porting an existing design system widget. Write
by hand when the component has no widget to port from.
