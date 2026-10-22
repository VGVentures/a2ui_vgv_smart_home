# A2UI VGV Smart Home (A2UI 1.0)

A Flutter app that plays a wall-mounted smart home panel. 

IMPORTANT: The demo should target [A2UI 1.0](https://a2ui.org/specification/v1.0-a2ui/).

## Where code goes

The root is the Flutter app. `README.md` maps the seven path packages under `packages/`. Restyle through the `app_ui` tokens.

The layers follow the VGV layered architecture: the app's `lib/` holds the blocs, cubits and views, `packages/home_repository` holds the repositories over `packages/home_api_client`, the data layer, and a bloc never reads another bloc. Packages are imported through their barrel, never `src/`.

Three packages carry an `AGENTS.md`, which Claude Code does not load on its own. Read the matching one before editing in that package:

- `packages/home_catalog/AGENTS.md` for adding or changing a component. That change crosses the catalog, a frontend builder, an `app_ui` widget and `catalog-prompt.prompt`.
- `packages/home_frontend/AGENTS.md` for widget builders, the zone controller and the HTTP agent.
- `packages/home_backend/AGENTS.md` for routes, prompts, tools, the mock data in `data/`, auth and `openapi.json`.

## Checks

`mise run check` runs every check below across every package, and `mise tasks` lists each one alone (`format:check`, `analyze`, `licenses`, `spell`, and `test:app`, `test:app_ui`, `test:frontend`, `test:catalog`, `test:timeline`, `test:api_client`, `test:repository`, `test:backend`). The tasks run the Flutter that `mise.toml` pins. CI doesn't call mise, so a floor raised under `.github/workflows/` has to be raised in `mise.toml` too.

To run a check by hand, run it from inside each package you touched, on the paths CI uses. A root-level `dart format .` reaches into `packages/` and rewrites backend files when the backend's dependencies are unresolved.

| Package | Format and analyze | Test |
| --- | --- | --- |
| root app | `dart format lib test`, `flutter analyze lib test`, `dart run bloc_tools:bloc lint .` | `very_good test --coverage --min-coverage 100` |
| `app_ui`, `home_frontend` | `dart format lib test`, `flutter analyze lib test` | `very_good test --coverage --min-coverage <floor>` |
| `home_catalog`, `home_timeline`, `home_api_client`, `home_repository` | `dart format lib test`, `dart analyze --fatal-infos lib test` | `very_good dart test --coverage --min-coverage <floor>` |
| `home_backend` | `dart format .`, `dart analyze --fatal-infos .` | `very_good dart test --no-optimization --coverage --min-coverage <floor>` |

Each package's floor is in its job under `.github/workflows/`. Floors only go up.

The Flutter version is pinned under `[tools]` in `mise.toml`, and CI reads it from there, so change it nowhere else. The global `flutter` may be a different version, so prefix `dart`, `flutter` and `very_good` with `mise exec --` when running them by hand.

CI also spell-checks every Markdown file against the VGV dictionaries. New names and domain words go in `words` in `.github/cspell.json`. PR titles follow Conventional Commits.

## Running it

Follow "Run locally" in `README.md`.
