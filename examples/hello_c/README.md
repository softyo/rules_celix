# hello_c — minimal Celix bundle example

This example demonstrates how to create a Celix bundle from a C activator
using the `celix_bundle` rule.

## Prerequisites

You need Apache Celix headers and the Celix framework library available in
your build. This repository does not vendor Celix — you must provide it.

Common approaches:
- Build Celix from source using [`rules_foreign_cc`](https://github.com/bazel-contrib/rules_foreign_cc)
- Use a pre-built sysroot or tarball via `http_archive`
- Vendor the Celix source tree as a `cc_library` pointing at `libcelix`

## How to use in your project

1. Add `rules_celix` to your `MODULE.bazel` as described in the
   [root README](../../README.md).

2. Create a `cc_shared_library` for your activator (as shown in this
   example's `BUILD.bazel`).

3. Update the `deps` in `cc_shared_library` to point to your real Celix
   framework target, for example:

   ```python
   deps = ["@celix//:framework"],
   ```

4. Build the bundle:

   ```
   bazel build //path/to:hello_bundle
   ```

## What the bundle contains

```
META-INF/MANIFEST.MF        # OSGi/Celix manifest headers
libhello_activator.so       # (or .dylib on macOS)
```

## Note

This example is **documentation-oriented**: it shows the exact pattern a
user would follow, but a working build requires the Celix framework to be
resolved. In the repository's test suite, most tests use the analysis-test
approach rather than full runtime, avoiding this dependency.
