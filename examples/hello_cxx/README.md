# hello_cxx — C++ Celix bundle example

This example builds a real Apache Celix bundle from a C++ activator, linking
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

The activator includes the Celix C++ API via the framework's exported includes:

```cpp
#include <celix/BundleActivator.h>   // CELIX_GEN_CXX_BUNDLE_ACTIVATOR
#include <celix/BundleContext.h>     // celix::BundleContext
#include <celix/ServiceRegistration.h>
```

Only the public load path is used in the BUILD file:

```python
load("//celix:defs.bzl", "celix_cpp_bundle")

celix_cpp_bundle(
    name = "hello_bundle",
    symbolic_name = "org.example.hello_cxx",
    srcs = ["src/hello_activator.cc"],
    deps = ["@celix//:framework"],
    copts = ["-std=c++17"],
    version = "1.0.0",
    bundle_name = "Hello CXX Bundle",
)
```

## Building

```
bazel build @celix//:framework
bazel build //examples/hello_cxx:hello_bundle
```

The resulting `bazel-bin/examples/hello_cxx/hello_bundle.zip` is a valid Celix
bundle whose first entry is `META-INF/MANIFEST.MF` (carrying
`Bundle-SymbolicName: org.example.hello_cxx`) followed by
`libhello_bundle_activator.so` (`.dylib` on macOS). Verify with:

```
unzip -l bazel-bin/examples/hello_cxx/hello_bundle.zip
```

The C twin of this example lives at [`examples/hello_c`](../hello_c/).

## How it works

The activator implements `celix::BundleActivator` as an RAII object: the
constructor (which receives a `std::shared_ptr<celix::BundleContext>`) acts as
the bundle `Start` hook and registers a `Greeter` service; the destructor is the
`Stop` hook and releases the service registration. `CELIX_GEN_CXX_BUNDLE_ACTIVATOR`
generates the required C entry points (`celix_bundleActivator_create/start/stop/destroy`)
for the Celix framework to invoke.
