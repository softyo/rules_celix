# Bundles

This page is the reference for the `celix_bundle` rule and the `celix_c_bundle` / `celix_cpp_bundle` convenience macros.

## The `celix_bundle` rule

`celix_bundle` takes an existing `cc_shared_library` (the **activator**) plus packaging metadata and produces a valid Celix bundle zip. The explicit-activator form gives you full control over the shared library:

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
)
```

### Attributes

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
| `framework`     | Convenience-macro only. How the activator links the Celix framework: `"runtime"` (default) or `"static"`. `"runtime"` is headers-only and resolves against the container runner's embedded framework at dlopen. `"static"` embeds the framework archive. A static-mode C++ bundle is not auto-startable inside a `celix_container`. |
| `celix`         | The `celix_runtime` target declaring the manifest format to emit. Defaults to `//celix:default_runtime` (Celix 2.x). See [Targeting Celix 3.x](#targeting-celix-3x). |

### A bundle with no activator

A bundle with no activator (e.g. a shared resource library):

```python
celix_bundle(
    name = "shared_config_bundle",
    symbolic_name = "com.example.config",
    no_activator = True,
    resources = [":config_files"],
)
```

## Convenience macros

For the common case (a single activator source file), use `celix_c_bundle` (C) or `celix_cpp_bundle` (C++) instead of managing the `cc_shared_library` yourself.
The macro creates the intermediate `cc_library` and `cc_shared_library` targets for you:

```python
# BUILD.bazel
load("@rules_celix//celix:defs.bzl", "celix_cpp_bundle")

celix_cpp_bundle(
    name = "hello_bundle",
    symbolic_name = "com.example.hello",
    srcs = ["hello_activator.cc"],
    copts = ["-std=c++17"],
    version = "1.0.0",
    bundle_name = "Hello bundle",
)
```

The convenience macros add the framework target automatically via their `framework` parameter (default `"runtime"`).
You usually don't list a framework target in `deps`.
Add other libraries there only.

The C variant is identical but with `celix_c_bundle` and C sources.
Both macros forward `deps`, `copts`, `linkopts`, and `includes` to the generated `cc_library`, and accept all of `celix_bundle`'s packaging attributes (`private_libs`, `resources`, `headers`, `description`, `group`, `filename`, …).
At least one entry in `srcs` is required.

When you need fine-grained control over the shared library (custom `hdrs`, `defines`, `alwayslink`, or a multi-library setup), use the explicit `cc_shared_library` + `celix_bundle` walkthrough above.
That remains the advanced / explicit-activator path.

### The `framework` parameter

Both macros accept a `framework` parameter that controls how the activator links the Celix framework:

- `framework = "runtime"` (default): the activator is linked against the framework's **headers only** (`@celix//:framework` is a headers-only target since v0.3.0).
  Every `celix_*` symbol stays unresolved in the bundle's `.so`/`.dylib` and binds against the single framework instance a `celix_container` runner embeds and exports at dlopen time.
  This single-instance resolution is what lets **C++ bundles auto-start** inside a container.
  The old default (embedding a second framework copy into the activator) ODR-crashed in `celix::impl::createActivator`.
  On macOS, the activator link passes `-Wl,-undefined,dynamic_lookup` (the standard plugin flag) so `ld64` accepts the unresolved symbols.
  They are left to be resolved by `dyld` against the runner at `dlopen` time.
  Linux's GNU ld allows them by default.
- `framework = "static"`: the framework archive is embedded into the activator `.so` for fully self-contained bundles (usable outside a runner).
  A static-mode **C++** bundle cannot be auto-started by a `celix_container`.
  The container rejects it at analysis.
  Use `install_only` or `framework = "runtime"` for that.

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

- **Celix 1.x / 2.x** (default): `META-INF/MANIFEST.MF` with OSGi-style headers (`Bundle-SymbolicName`, `Bundle-Version`, `Bundle-Activator`/`Private-Library`, etc.).
- **Celix 3.x**: `META-INF/MANIFEST.json` with `CELIX_BUNDLE_*` headers (`CELIX_BUNDLE_SYMBOLIC_NAME`, `CELIX_BUNDLE_VERSION`, `CELIX_BUNDLE_ACTIVATOR`, etc.).

The packaging step ensures the manifest is the first file entry in the zip.
It is preceded by its explicit parent-directory entry (Celix requires both).
Why this ordering matters, and how it is enforced, is covered in [implementation-notes](../developing/implementation-notes.md#manifest-first-zip-assembly).

## Targeting Celix 3.x

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

## Next steps

- [containers.md](containers.md): assemble bundles into a runnable container with auto-start levels
- [quickstart.md](quickstart.md): the minimal walkthrough
