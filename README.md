# rules_celix

[![CI](https://github.com/softyo/rules_celix/actions/workflows/ci.yml/badge.svg)](https://github.com/softyo/rules_celix/actions/workflows/ci.yml)

An OSS Bazel ruleset to support building [Apache Celix](https://celix.apache.org/) bundles and applications.

Celix is an OSGi-inspired framework for C and C++.
A Celix bundle is a zip archive containing a `META-INF/MANIFEST.MF`, one or more shared libraries, and optional resources.
This ruleset lets you produce valid Celix bundles from a fully hermetic Bazel build without invoking Celix’s CMake helpers.

## Status

**Pre-release / experimental.**  
The API is not yet stable. The ruleset is not published to the [Bazel Central Registry (BCR)](https://registry.bazel.build/). Use it via `local_path_override`, `git_override`, or an `archive_override` until a release is available.

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

## Quick start (before BCR publication)

### 1. Add the ruleset to your `MODULE.bazel`

Until the module is on BCR, point at a local checkout or a git commit:

```python
# MODULE.bazel

bazel_dep(name = "rules_celix", version = "0.0.1")
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
    # private_libs = [":other_lib"],   # optional extra .so/.dylib files
    # resources = [":resource_files"], # optional filegroup
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

### 3. Build

```bash
./bazelw build //:hello_bundle
# → bazel-bin/hello_bundle.zip   (valid Celix bundle)
```

You can install the resulting zip into a Celix container (built with Celix’s CMake tooling or a future `celix_container` rule) and start it via the Celix shell.

## What the rule produces

A Celix bundle zip with at least:

```
META-INF/MANIFEST.MF
libhello_activator.so   (or .dylib)
[optional private libraries]
[optional resources]
```

The manifest contains the usual OSGi-style headers (`Bundle-SymbolicName`, `Bundle-Version`, activator / private-library entries, etc.). The packaging step ensures `META-INF/MANIFEST.MF` is the first entry in the zip (Celix prefers this).

## Public API (current)

| Target / symbol       | Description                                      |
|-----------------------|--------------------------------------------------|
| `celix_bundle`        | Core rule / macro that builds a bundle zip       |
| `CelixBundleInfo`     | Provider carrying zip path, symbolic name, version, and activator |

See [`celix/defs.bzl`](celix/defs.bzl) for the authoritative surface. Additional helpers (`celix_container`, richer macros) are planned.

## Project layout

```
rules_celix/
├── MODULE.bazel
├── celix/                  # public rules & providers
│   ├── defs.bzl
│   ├── bundle.bzl
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

| Version | Focus                                                    |
|---------|----------------------------------------------------------|
| 0.1     | Packaging rule only (existing `cc_shared_library` → zip) |
| 0.2     | Convenience macro that also creates the shared library   |
| 0.3     | Basic `celix_container` / launcher support               |
| 0.4     | Version compatibility tests                              |
| 1.0     | Stable API, BCR publication                              |

## Contributing

Issues and pull requests are welcome. Please run `./bazelw run @buildifier_prebuilt//:buildifier -- -r .` and the test suite before submitting. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Apache License 2.0 — same as Apache Celix.

## Related projects

- [Apache Celix](https://celix.apache.org/)
- [rules_pkg](https://github.com/bazelbuild/rules_pkg)
- [rules_foreign_cc](https://github.com/bazel-contrib/rules_foreign_cc) (useful for building Celix itself from source)
