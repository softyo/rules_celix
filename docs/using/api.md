# Public API

This page lists the current public surface of `rules_celix`.

## Targets and symbols

| Target / symbol       | Description                                      |
|-----------------------|--------------------------------------------------|
| `celix_bundle`        | Core rule / macro that builds a bundle zip from an existing `cc_shared_library` (explicit-activator path) |
| `celix_c_bundle`      | Convenience macro: compile a C activator + build a bundle in one call |
| `celix_cpp_bundle`    | Convenience macro: compile a C++ activator + build a bundle in one call |
| `celix_container`     | Assembles a runnable Celix container from `celix_bundle` targets. `bazel run` boots the framework via the per-container runner `cc_binary`. `bundles = {int level 0..6: [labels]}` plus optional `install_only` auto-start/install the bundles. `framework_package` (default `@rules_celix//third_party/celix`) selects the runner's framework package. `tarball = True` (default) also emits the distributable `<name>.tgz` |
| `celix_runtime`       | Declares a Celix runtime version contract        |
| `CelixBundleInfo`     | Provider carrying zip path, symbolic name, version, activator, `link_mode` (framework runtime/static), `uses_cpp` and `framework` (the framework package, from the bundle's `celix_runtime`) |
| `CelixContainerInfo`  | Provider carrying the container's runner, bundle zips, and config file |
| `CelixRuntimeInfo`    | Provider carrying the targeted Celix runtime version and its framework package |

## Load line

All symbols above are loaded from a single file, `@rules_celix//celix:defs.bzl`.

```python
load("@rules_celix//celix:defs.bzl", "celix_bundle", "celix_c_bundle", "celix_cpp_bundle", "celix_container", "celix_runtime", "CelixBundleInfo", "CelixContainerInfo", "CelixRuntimeInfo")
```

## Providers

- `CelixBundleInfo`. Produced by `celix_bundle`. It carries the bundle zip path, symbolic name, version, activator, `link_mode` (framework runtime/static), `uses_cpp` and `framework` (the framework package, from the bundle's `celix_runtime`).
- `CelixContainerInfo`. Produced by `celix_container`. It carries the container's runner, bundle zips, and config file.
- `CelixRuntimeInfo`. Produced by `celix_runtime`. It carries the targeted Celix runtime version (`celix_version`) and its framework package (`framework`).

The `celix_runtime` rule gains a `framework` attribute (a package label string, default `@rules_celix//third_party/celix`) selecting the framework binaries.
The macro-built bundles link against the same package via `framework_package`, and `celix_container` takes a matching `framework_package` for its per-container runner.
The container's per-framework consistency check reads the provider value and enforces that every bundle shares the runner's framework.

## Authoritative surface

See [celix/defs.bzl](../../celix/defs.bzl) for the authoritative surface.
Additional helpers (richer `celix_container` options) are planned.

Generated HTML documentation (Stardoc) can be produced locally.
See [setup](../developing/setup.md#generating-api-documentation).
