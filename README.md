# rules_celix

[![CI](https://github.com/softyo/rules_celix/actions/workflows/ci.yml/badge.svg)](https://github.com/softyo/rules_celix/actions/workflows/ci.yml)

An OSS Bazel ruleset to support building [Apache Celix](https://celix.apache.org/) bundles and applications.

Celix is an OSGi-inspired framework for C and C++.
A Celix bundle is a zip archive containing a `META-INF/MANIFEST.MF`, one or more shared libraries, and optional resources.
This ruleset lets you produce valid Celix bundles from a fully hermetic Bazel build without invoking Celix’s CMake helpers.

## Status

**v0.1.0 released.**  
**v0.2.0 released** — adds the `celix_c_bundle` / `celix_cpp_bundle` convenience macros
(single call that also creates the activator shared library), hermetically built real-Celix
C and C++ examples (`examples/hello_c`, `examples/hello_cxx`), and expanded analysis + integration test coverage.

The ruleset is not yet on the [Bazel Central Registry (BCR)](https://registry.bazel.build/) —
BCR publication is planned for v1.0. Use it via `local_path_override` or `git_override` (pinned
to the `v0.2.0` tag or a commit).

## Requirements

The repository ships [`bazelw`](bazelw) (Linux / macOS) and [`bazelw.bat`](bazelw.bat) (Windows) wrapper scripts that
download [Bazelisk](https://github.com/bazelbuild/bazelisk) and use the Bazel version pinned in
[`.bazelversion`](.bazelversion).  No pre-installed Bazel is required — just run `./bazelw` (or `bazelw` on Windows)
instead of `bazel`.

If you prefer a system Bazel, Bazel 7+ with bzlmod is recommended.

Build-tool dependencies (`rules_cc`, `rules_pkg`, etc.) are declared in `MODULE.bazel` and resolved
automatically by bzlmod — you do **not** need to add them to your own module.

The only thing you need to provide yourself:

- **Apache Celix headers / libraries** — available as a Bazel target in your workspace
  (this ruleset does **not** vendor Celix; see [`rules_foreign_cc`](https://github.com/bazel-contrib/rules_foreign_cc) or your own module to fetch it)

Two exceptions apply:

- The **runnable container** (`celix_container`) needs no consumer-side `@celix` at all — its runner is built once inside rules_celix with the framework embedded and copied into the container.
- For bundle-activator consumers who want the same bundled framework, `@rules_celix//third_party/celix:framework` aliases `@celix//:framework` (see the `celix_deps` extension block in `MODULE.bazel` / `third_party/celix/upstream.bzl`); users supplying their own `@celix` continue to pass `@celix//:framework` directly.

## Quick start (before BCR publication)

### 1. Add the ruleset to your `MODULE.bazel`

Until the module is on BCR, point at a local checkout or a git commit:

```python
# MODULE.bazel

bazel_dep(name = "rules_celix", version = "0.2.0")
local_path_override(
    module_name = "rules_celix",
    path = "../rules_celix",          # path to this repository
)

# or, for a git pin:
# git_override(
#     module_name = "rules_celix",
#     remote = "https://github.com/<you>/rules_celix.git",
#     commit = "<commit-sha>",
# )
```

You also need Celix itself (headers + framework library).
How you obtain it is up to you—`rules_foreign_cc`, a pre-built sysroot, or your own module.

### 2. Write a bundle

```python
# BUILD.bazel
load("@rules_celix//celix:defs.bzl", "celix_bundle")
load("@rules_cc//cc:defs.bzl", "cc_shared_library")

cc_shared_library(
    name = "hello_activator",
    srcs = ["hello_activator.c"],
    deps = [
        # Your Celix framework target, e.g.:
        # "@celix//:framework",
    ],
)

celix_bundle(
    name = "hello_bundle",
    activator = ":hello_activator",
    symbolic_name = "com.example.hello",
    version = "1.0.0",
    private_libs = [":other_lib"],   # optional extra .so/.dylib files
    resources = [":resource_files"], # optional filegroup
    description = "Hello world bundle",  # optional, emitted when non-empty
    group = "com.example",               # optional, emitted when non-empty
    filename = "hello",                  # optional output zip base name (defaults to name)
)
```

Minimal C activator (using Celix’s convenience macro):

```c
// hello_activator.c
#include <stdio.h>
#include <celix_bundle_activator.h>

typedef struct activator_data {
    /* empty */
} activator_data_t;

static celix_status_t activator_start(activator_data_t *data, celix_bundle_context_t *ctx) {
    printf("Hello from bundle id %li\n", celix_bundleContext_getBundleId(ctx));
    return CELIX_SUCCESS;
}

static celix_status_t activator_stop(activator_data_t *data, celix_bundle_context_t *ctx) {
    printf("Goodbye from bundle id %li\n", celix_bundleContext_getBundleId(ctx));
    return CELIX_SUCCESS;
}

CELIX_GEN_BUNDLE_ACTIVATOR(activator_data_t, activator_start, activator_stop)
```

### Convenience macros

For the common case (a single activator source file), use `celix_c_bundle` (C) or
`celix_cpp_bundle` (C++) instead of managing the `cc_shared_library` yourself. The macro
creates the intermediate `cc_library` and `cc_shared_library` targets for you:

```python
# BUILD.bazel
load("@rules_celix//celix:defs.bzl", "celix_cpp_bundle")

celix_cpp_bundle(
    name = "hello_bundle",
    symbolic_name = "com.example.hello",
    srcs = ["hello_activator.cc"],
    copts = ["-std=c++17"],
    deps = [
        # Your Celix framework target, e.g.:
        # "@celix//:framework",
    ],
    version = "1.0.0",
    bundle_name = "Hello bundle",
)
```

The C variant is identical but with `celix_c_bundle` and C sources. Both macros forward
`deps`, `copts`, `linkopts`, and `includes` to the generated `cc_library`, and accept all of
`celix_bundle`'s packaging attributes (`private_libs`, `resources`, `headers`,
`description`, `group`, `filename`, …). At least one entry in `srcs` is required.

When you need fine-grained control over the shared library (custom `hdrs`, `defines`,
`alwayslink`, or a multi-library setup), use the explicit `cc_shared_library` +
`celix_bundle` walkthrough above — that remains the advanced / explicit-activator path.

### 3. Build

```bash
./bazelw build //:hello_bundle
# → bazel-bin/hello_bundle.zip   (valid Celix bundle)
```

You can install the resulting zip into a Celix container (built with Celix’s CMake tooling or a future `celix_container` rule) and start it via the Celix shell.

### Additional attributes

Besides `activator` and `symbolic_name`, `celix_bundle` accepts:

| Attribute       | Description                                                                  |
|-----------------|------------------------------------------------------------------------------|
| `private_libs`  | Extra private shared libraries bundled into the zip root (mode 0755). Each entry may be a `cc_shared_library` target or a plain `.so`/`.dylib`/`.dll` file. Emitted in the `Private-Library` manifest header. |
| `resources`     | Files (e.g. a `filegroup`) bundled preserving their package-relative path, so subdirectories are supported (mode 0644). |
| `headers`       | Custom manifest headers. Emitted verbatim as `Key: value` lines (properties) or as top-level JSON string fields (3.x manifest). |
| `description`   | `Bundle-Description` header (properties) / `CELIX_BUNDLE_DESCRIPTION` (3.x). Only emitted when non-empty. |
| `group`         | `Bundle-Group` header (properties) / `CELIX_BUNDLE_GROUP` (3.x). Only emitted when non-empty. |
| `filename`      | Override the output zip base name (a trailing `.zip` is normalized away). Defaults to the target name. |
| `no_activator`  | When `True`, ships a bundle with no activator library and makes `activator` optional (default `False`). |

For example, a bundle with no activator (e.g. a shared resource library):

```python
celix_bundle(
    name = "shared_config_bundle",
    symbolic_name = "com.example.config",
    no_activator = True,
    resources = [":config_files"],
)
```

## What the rule produces

A Celix bundle zip with at least:

```
META-INF/                  (explicit directory entry Celix's extractor requires)
META-INF/MANIFEST.MF       (Celix 1.x / 2.x — OSGi properties)
  or
META-INF/MANIFEST.json     (Celix 3.x — JSON format)
libhello_activator.so   (or .dylib)          (omitted with no_activator = True)
lib<private_lib>.so     (optional private libraries, at bundle root)
<resource short_path>   (optional resources, path preserved)
```

The manifest format is determined by the Celix runtime version targeted by the `celix` attribute:

* **Celix 1.x / 2.x** (default): `META-INF/MANIFEST.MF` with OSGi-style headers (`Bundle-SymbolicName`, `Bundle-Version`, `Bundle-Activator`/`Private-Library`, etc.).
* **Celix 3.x**: `META-INF/MANIFEST.json` with `CELIX_BUNDLE_*` headers (`CELIX_BUNDLE_SYMBOLIC_NAME`, `CELIX_BUNDLE_VERSION`, `CELIX_BUNDLE_ACTIVATOR`, etc.).

The packaging step ensures the manifest is the first file entry in the zip (preceded by its explicit parent-directory entry; Celix requires both).

## Assemble a container

A Celix container is a launcher executable plus a `bundles/` directory.
The `celix_container` rule assembles the deployable **contents** as a runnable
container: each bundle zip is laid out at `bundles/<symbolic_name>.zip`, exactly
where Celix expects it at runtime, next to a generated `config.properties` and a
copy of the shared runner binary that embeds the Celix framework:

```python
# BUILD.bazel
load("@rules_celix//celix:defs.bzl", "celix_bundle", "celix_container")

celix_bundle(
    name = "hello_bundle",
    activator = ":hello_lib",
    symbolic_name = "org.example.hello",
)

celix_bundle(
    name = "config_bundle",
    no_activator = True,
    symbolic_name = "org.example.config",
)

celix_container(
    name = "hello_container",
    bundles = {
        1: [":hello_bundle"],
        2: [":config_bundle"],
    },
    install_only = [...],   # optional: installed, never started
)
```

The macro generates:

- `:<name>` — the runnable container: a launcher + runfiles carrying a copy of the shared runner binary (`@rules_celix//tools:container_runner`), the generated `config.properties`, and the bundle zips.
- `:<name>_config` — the generated `config.properties` (deterministic: `CELIX_BUNDLES_PATH`, `CELIX_FRAMEWORK_CACHE_DIR`, `CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true`, `CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL`, plus `CELIX_AUTO_START_<level>` / `CELIX_AUTO_INSTALL` for the bundles).
- `:<name>_start_sh` — an `sh_binary` wrapper for running (or copying) the container tree outside Bazel.

The runner binary is built once in the rules_celix repository (where `@celix` resolves and the framework is embedded) and copied per container into the package dir as `<name>_runner` so `celix_container` needs no consumer-side `@celix`.
You still need Celix itself for the **bundles'** activators (the `:hello_lib` above links the framework headers/library).
To get a working framework target without declaring your own `@celix`, depend on `@rules_celix//third_party/celix:framework` (an alias to `@celix//:framework`), or declare `@celix` in your own `MODULE.bazel` and pass `@celix//:framework` directly.

Run it with:

```bash
./bazelw run //:hello_container
```

The runner boots the framework, logs `rules_celix container runner started`, and stays up until it receives a stop signal or `STOP_RUNNER=1` appears in the active `config.properties` (see `examples/hello_container`'s README).
The cache lives in `/tmp` (`CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true`), so repeated runs stay clean and never write into the runfiles tree.

Container outputs are package-relative and real files (deterministic byte copies of the bundle zips, plus the copied runner binary, not symlinks), nested under the container's runtime directory `<name>_runtime/` so the tree can be copied verbatim next to a Celix executable.
Each bundle is laid out by its `Bundle-SymbolicName` (the stable container identity), not the bundle's target or `filename` attribute.
Duplicate symbolic names within one container are rejected at analysis.

### Autostart / start levels (max 7)

Celix auto-starts bundles from the generated config in Karaf style:

- `bundles` maps each bundle to a start level `0..6` (`CELIX_AUTO_START_0` … `CELIX_AUTO_START_6`).  The framework installs all bundles first, then starts them in ascending level order, preserving declaration order within a level; on shutdown they are stopped in reverse order.  Levels outside `0..6` are rejected at analysis.
- `install_only = [...]` bundles are installed but never started (emitted under `CELIX_AUTO_INSTALL`, processed after the start set).
- A bundle listed in both a start level and `install_only` is started: AUTO_START wins (with a warning); it is excluded from `CELIX_AUTO_INSTALL`.
- A bundle must not be listed under two different levels (rejected at load time).
- `CELIX_AUTO_START_*` / `CELIX_AUTO_INSTALL` values are space-separated paths, so bundle symbolic names must not contain spaces (rejected at analysis).

See [`examples/hello_container`](examples/hello_container) for a runnable container that auto-starts the C hello bundle (level 1) and installs the C++ one without starting it (a pre-existing C++ activator limitation keeps C++ bundles out of auto-start for now).

## Public API (current)

| Target / symbol       | Description                                      |
|-----------------------|--------------------------------------------------|
| `celix_bundle`        | Core rule / macro that builds a bundle zip from an existing `cc_shared_library` (explicit-activator path) |
| `celix_c_bundle`      | Convenience macro: compile a C activator + build a bundle in one call |
| `celix_cpp_bundle`    | Convenience macro: compile a C++ activator + build a bundle in one call |
| `celix_container`     | Assembles a runnable Celix container from `celix_bundle` targets (`bazel run` boots the embedded framework via the shared runner copy); `bundles = {int level 0..6: [labels]}` + optional `install_only` auto-start/install the bundles |
| `celix_runtime`       | Declares a Celix runtime version contract        |
| `CelixBundleInfo`     | Provider carrying zip path, symbolic name, version, and activator |
| `CelixContainerInfo`  | Provider carrying the container's runner, bundle zips, and config file |
| `CelixRuntimeInfo`    | Provider carrying the targeted Celix runtime version |

All symbols above are loaded from a single file, `@rules_celix//celix:defs.bzl`.

```python
load("@rules_celix//celix:defs.bzl", "celix_bundle", "celix_c_bundle", "celix_cpp_bundle", "celix_container", "celix_runtime", "CelixBundleInfo", "CelixContainerInfo", "CelixRuntimeInfo")
```

See [`celix/defs.bzl`](celix/defs.bzl) for the authoritative surface.
Additional helpers (richer `celix_container` options) are planned.

### Targeting Celix 3.x

By default, `celix_bundle` targets the Celix 2.x runtime (`//celix:default_runtime`) and produces OSGi properties-style manifests. To target Celix 3.x with JSON manifests:

```python
load("@rules_celix//celix:defs.bzl", "celix_bundle", "celix_runtime")

celix_runtime(
    name = "celix_v3",
    celix_version = "3.0.0",
)

celix_bundle(
    name = "my_bundle",
    activator = ":my_lib",
    symbolic_name = "com.example.my",
    celix = ":celix_v3",
)
```

## Project layout

```
rules_celix/
├── MODULE.bazel
├── celix/                  # public rules & providers
│   ├── defs.bzl
│   ├── bundle.bzl
│   ├── runtime.bzl
│   ├── providers.bzl
│   └── internal/
├── examples/               # runnable samples
├── tests/                  # analysis & integration tests
└── .bcr/                   # templates for future BCR submission
```

## Development

```bash
# Format
./bazelw run @buildifier_prebuilt//:buildifier -- -r .

# Test
./bazelw test //...

# Build examples
./bazelw build //examples/...
```

## Generating API documentation

This repository uses [rules_stardoc](https://github.com/bazelbuild/rules_stardoc) to generate
HTML API reference documentation from source docstrings.

To generate the docs locally:

```bash
./bazelw build //celix:celix_stardoc
```

The generated HTML reference will be available at:
`.bazel-bin/celix/celix_api.html`

## Tentative roadmap (high level)

| Version | Status       | Focus                                                    |
|---------|--------------|----------------------------------------------------------|
| 0.1     | Done         | Packaging rule only (existing `cc_shared_library` → zip) |
| 0.2     | Done         | Convenience macros (`celix_c_bundle`/`celix_cpp_bundle`) + real-Celix C & C++ examples |
| 0.3     | In progress   | `celix_container` runnable: hermetic runner binary, generated config, runfiles layout |
| 0.4     | Planned      | Version compatibility tests                              |
| 1.0     | Planned      | Stable API, BCR publication                              |

## Contributing

Issues and pull requests are welcome. Please run `./bazelw run @buildifier_prebuilt//:buildifier -- -r .` and the test suite before submitting. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Apache License 2.0 — same as Apache Celix.

## Related projects

- [Apache Celix](https://celix.apache.org/)
- [rules_pkg](https://github.com/bazelbuild/rules_pkg)
- [rules_foreign_cc](https://github.com/bazel-contrib/rules_foreign_cc) (useful for building Celix itself from source)
