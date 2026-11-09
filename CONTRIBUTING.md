# 🦄 Contributing to A2UI VGV Smart Home

First of all, thank you for taking the time to contribute! 🎉👍 Before you do, please carefully read this guide.

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Understanding A2UI VGV Smart Home

A2UI VGV Smart Home is a Flutter app that plays a wall-mounted smart home panel. An LLM composes the dashboard as [A2UI 1.0](https://a2ui.org/specification/v1.0-a2ui/) messages, and the app renders them. The [README](README.md) explains the data flow, and maps the packages under `packages/`.

Three packages have an `AGENTS.md` that says what a change has to touch. Read the matching one before editing in that package:

- [`home_catalog`](packages/home_catalog/AGENTS.md) for adding or changing a component.
- [`home_frontend`](packages/home_frontend/AGENTS.md) for widget builders, the zone controller and the HTTP agent.
- [`home_backend`](packages/home_backend/AGENTS.md) for routes, prompts, tools, the mock data, auth and `openapi.json`.

## Opening an issue

We highly recommend creating an issue if you have found a bug, want to suggest a feature, or recommend a change. Please do not immediately open a pull request. Opening an issue first allows us to reach an agreement on a fix before you put significant effort into a pull request.

When reporting a bug, please provide as much information as possible, including detailed reproduction steps. Once one of the maintainers has reviewed the issue and we reach an agreement on the fix, open a pull request.

To report a security vulnerability, follow the [Security Policy](SECURITY.md) instead of opening an issue.

## Developing for A2UI VGV Smart Home

To develop for A2UI VGV Smart Home you will need to become familiar with Very Good Ventures processes and conventions:

### Setting up your local development environment

1. Install [mise](https://mise.jdx.dev). It installs the pinned Flutter and runs the tasks in `mise.toml`.

2. Install the tools the checks use:

```sh
# 🛠️ Very Good CLI runs the tests and the license check
dart pub global activate very_good_cli

# 🐸 Dart Frog CLI runs the backend
dart pub global activate dart_frog_cli
```

3. Install the pinned Flutter and every package's dependencies from the repo root:

```sh
# 📂 Install the pinned SDK and get dependencies for every package
mise trust
mise install
mise run setup
```

4. Run all the checks:

```sh
# 🧪 Format, analyze, licenses, spell check and every package's tests
mise run check
```

`mise tasks` lists each check on its own. See "Run locally" in the [README](README.md) to start the backend and the app, which need your own Gemini API key.

💡 **Note**: The global `flutter` may be a different version than the pinned one. Prefix `dart`, `flutter` and `very_good` with `mise exec --` when you run them by hand.

### Creating a Pull Request

Before creating a Pull Request please:

1. [Fork](https://docs.github.com/en/get-started/quickstart/contributing-to-projects) the [GitHub repository](https://github.com/VGVentures/a2ui_vgv_smart_home) and create your branch from `main`:

```sh
# 🪵 Branch from `main`
git branch <branch-name>
git checkout <branch-name>
```

Where `<branch-name>` is an appropriate name describing your change.

2. Install dependencies:

```sh
# 📂 Get dependencies for every package
mise run setup
```

3. Ensure you have a meaningful [semantic][conventional_commits_link] commit message. The title of your Pull Request must follow Conventional Commits too.

4. Add tests! The root app requires 100% test coverage, and every package has a coverage floor in its job under `.github/workflows/`. Floors only go up, so Pull Requests that lower one will **not** be merged. If you're unsure on how to do so watch our [Testing Fundamentals Course](https://www.youtube.com/watch?v=M_eZg-X789w&list=PLprI2satkVdFwpxo_bjFkCxXz5RluG8FY).

5. Ensure the existing test suite passes locally:

```sh
# 🧪 Run every package's tests
mise run test:app
mise run test:app_ui
mise run test:frontend
mise run test:catalog
mise run test:timeline
mise run test:api_client
mise run test:repository
mise run test:backend
```

You only need to run the packages you changed.

6. Format your code:

```sh
# 🧼 Check the format of every package
mise run format:check
```

When you format by hand, run `dart format lib test` from inside each package you touched. A root-level `dart format .` reaches into `packages/` and rewrites backend files when the backend's dependencies are unresolved.

7. Analyze your code:

```sh
# 🔍 Analyze every package
mise run analyze
```

Some analysis issues may be fixed automatically with:

```sh
# Automatically fix analysis issues that have associated automated fixes
dart fix --apply
```

💡 **Note**: Our repositories use [Very Good Analysis](https://github.com/VeryGoodOpenSource/very_good_analysis).

8. Check the licenses and the spelling:

```sh
# 📜 Check the dependency licenses
mise run licenses

# 🔤 Spell-check every Markdown file
mise run spell
```

CI spell-checks every Markdown file against the VGV dictionaries. Add new names and domain words to `words` in `.github/cspell.json`.

9. Create the Pull Request with a meaningful description, linking to the original issue where possible.

10. Verify that all [status checks](https://github.com/VGVentures/a2ui_vgv_smart_home/actions/) are passing for your Pull Request once they have been approved to run by a maintainer.

💡 **Note**: While the prerequisites above must be satisfied prior to having your pull request reviewed, the reviewer(s) may ask you to complete additional work, tests, or other changes before your pull request can be accepted.

[conventional_commits_link]: https://www.conventionalcommits.org/en/v1.0.0
