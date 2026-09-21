# hello_c — C Celix bundle example

This example builds a real Apache Celix bundle from a C activator, linking
against a **hermetically built** `@celix//:framework` (fetched and compiled
natively by `rules_celix` — no system Celix, no CMake).

This example is part of the CI `build_test` matrix and is built on both
**Linux** (`ubuntu-latest`) and **macOS** (`macos-latest`), so a regression in
the real-Celix path (or in `.dylib` packaging) is caught automatically.

## Pinned Celix version

The framework is pinned to **Apache Celix 2.4.0** (`rel/celix-2.4.0`) via the
`celix_deps` bzlmod module extension in
[`third_party/celix/upstream.bzl`](../../third_party/celix/upstream.bzl). A 3.x
pin would switch Celix to its JSON manifest format, which is out of scope for
this example (see the ruleset's `//celix:default_runtime`).

The Celix 2.4.0 framework hard-requires `libuuid` and `libzip` (+`zlib` for
DEFLATE). These are also fetched and built natively:

- `@zlib` — vendored zlib 1.3.1
- `@libzip` — vendored libzip 1.10.1 (config in `third_party/libzip/`)
- `uuid` — the framework only needs 3 RFC 4122 routines
  (`uuid_generate`/`uuid_parse`/`uuid_unparse`), provided by the miniature
  hermetic library in [`third_party/celix/uuid`](../../third_party/celix/uuid)
  instead of a system libuuid

## Load path

The activator includes the Celix C API via the framework's exported includes:

```c
#include <celix_bundle_activator.h>   // CELIX_GEN_BUNDLE_ACTIVATOR
```

Only the public load path is used in the BUILD file:

```python
load("//celix:defs.bzl", "celix_c_bundle")

celix_c_bundle(
    name = "hello_bundle",
    srcs = ["src/hello_activator.c"],
    deps = ["@celix//:framework"],
    symbolic_name = "org.example.hello",
    version = "1.0.0",
    bundle_name = "Hello World Bundle",
)
```

## Building

```
bazel build @celix//:framework
bazel build //examples/hello_c:hello_bundle
```

The resulting `bazel-bin/examples/hello_c/hello_bundle.zip` is a valid Celix
bundle whose first entry is `META-INF/MANIFEST.MF` (carrying
`Bundle-SymbolicName: org.example.hello`) followed by
`libhello_bundle_activator.so` (`.dylib` on macOS). Verify with:

```
unzip -l bazel-bin/examples/hello_c/hello_bundle.zip
```

## How it works

The activator implements the Celix C bundle-activator contract: `activator_start`
/`activator_stop` callbacks receive the bundle context and print a hello /
goodbye message. `CELIX_GEN_BUNDLE_ACTIVATOR` generates the required C entry
points (`celix_bundleActivator_create/start/stop/destroy`) for the Celix
framework to invoke.

The C++ twin of this example lives at [`examples/hello_cxx`](../hello_cxx/).
