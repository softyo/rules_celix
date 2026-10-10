# Quick start

This page takes you from an empty `MODULE.bazel` to a built Celix bundle.
It assumes a Bazel workspace with bzlmod enabled and C/C++ compilation working.

## Requirements

The repository ships [`bazelw`](../../bazelw) (Linux / macOS) and [`bazelw.bat`](../../bazelw.bat) (Windows) wrapper scripts that download [Bazelisk](https://github.com/bazelbuild/bazelisk) and use the Bazel version pinned in [`.bazelversion`](../../.bazelversion).
No pre-installed Bazel is required.
Just run `./bazelw` (or `bazelw` on Windows) instead of `bazel`.

If you prefer a system Bazel, Bazel 7+ with bzlmod is recommended.

Build-tool dependencies (`rules_cc`, `rules_pkg`, etc.) are declared in `MODULE.bazel` and resolved automatically by bzlmod.
You do **not** need to add them to your own module.

The only thing you need to provide yourself:

- **Apache Celix headers / libraries**, available as a Bazel target in your workspace (this ruleset does **not** vendor Celix).
  See [`rules_foreign_cc`](https://github.com/bazel-contrib/rules_foreign_cc) or your own module to fetch it.

Two exceptions apply:

- The **runnable container** (`celix_container`) needs no consumer-side `@celix` at all.
  Its runner is built once inside rules_celix with the framework embedded and copied into the container.
- For bundle-activator consumers who want the same bundled framework, `@rules_celix//third_party/celix:framework` aliases `@celix//:framework`.
  See the `celix_deps` extension block in `MODULE.bazel` / `third_party/celix/upstream.bzl`.
  Users supplying their own `@celix` continue to pass `@celix//:framework` directly.

## 1. Add the ruleset to your `MODULE.bazel`

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
How you fetch it is up to you: `rules_foreign_cc`, a pre-built sysroot, or your own module.

## 2. Write a bundle

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

For the common case (a single activator source file) you can skip the explicit `cc_shared_library` and use a convenience macro instead: see [bundles.md](bundles.md#convenience-macros).

## 3. Build

```bash
./bazelw build //:hello_bundle
# → bazel-bin/hello_bundle.zip   (valid Celix bundle)
```

You can install the resulting zip into a Celix container and start it via the Celix shell.
The container can be built with Celix's CMake tooling or the [celix_container](containers.md) rule.

## Next steps

- [bundles.md](bundles.md): all `celix_bundle` attributes, the convenience macros, and targeting Celix 3.x
- [containers.md](containers.md): assemble bundles into a runnable container
- [api.md](api.md): the full public API surface
