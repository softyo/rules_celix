# rules_celix documentation

This documentation covers both ways of working with `rules_celix`:

- [**Using `rules_celix`**](using/) is for **consumers** (people who add the ruleset to their module and build Celix bundles and containers with Bazel).
- [**Developing `rules_celix`**](developing/) is for **contributors** (people who work on the ruleset itself).

If you are new here, start with the [quick start](using/quickstart.md).

## For consumers (`docs/using/`)

| Document                              | What it covers                                                                 |
|---------------------------------------|--------------------------------------------------------------------------------|
| [quickstart.md](using/quickstart.md)  | Requirements, adding the module to `MODULE.bazel`, writing your first bundle, building it |
| [bundles.md](using/bundles.md)        | `celix_bundle` attributes, the `celix_c_bundle` / `celix_cpp_bundle` convenience macros, manifest formats (Celix 2.x vs 3.x) |
| [containers.md](using/containers.md)  | `celix_container`: assembly, `bazel run`, start levels / autostart, the distributable tarball |
| [api.md](using/api.md)                | The public API surface: targets, symbols, providers, and the load line |

## For contributors (`docs/developing/`)

| Document                                | What it covers                                                     |
|-----------------------------------------|--------------------------------------------------------------------|
| [setup.md](developing/setup.md)         | Dev environment, `bazelw`, formatting, testing, stardoc generation |
| [roadmap.md](developing/roadmap.md)     | Project status and the milestone roadmap (single source of truth)  |
| [implementation-notes.md](developing/implementation-notes.md) | Internal design: hermetic deps, zip/manifest assembly, framework resolution, runner & tarball design |
| [testing.md](developing/testing.md)     | Test expectations, the `tests/` layout, and test-writing style     |
| [releasing.md](developing/releasing.md) | How to cut a release and publish the source archive                |

## Related

- [README](../README.md): the short project overview (goals, status, quick pointer to this doc tree)
- [CONTRIBUTING](../CONTRIBUTING.md): how to file issues and submit pull requests
- [AGENTS.md](../AGENTS.md): guidance for AI agents / automated contributors