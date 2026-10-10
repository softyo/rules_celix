# Containers

A Celix container is a launcher executable plus a `bundles/` directory.
The `celix_container` rule assembles the deployable **contents** as a runnable container.
Each bundle zip is laid out at `bundles/<symbolic_name>.zip`, exactly where Celix expects it at runtime.
Next to it sits a generated `config.properties` and a copy of the shared runner binary that embeds the Celix framework.

## Example

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

## Generated targets

The macro generates:

- `:<name>`. The runnable container: a launcher + runfiles carrying a copy of the shared runner binary (`@rules_celix//tools:container_runner`), the generated `config.properties`, and the bundle zips.
- `:<name>_config`. The generated `config.properties` (deterministic: `CELIX_BUNDLES_PATH`, `CELIX_FRAMEWORK_CACHE_DIR`, `CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true`, `CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL`, plus `CELIX_AUTO_START_<level>` / `CELIX_AUTO_INSTALL` for the bundles).
- `:<name>_start_sh`. An `sh_binary` wrapper for running (or copying) the container tree outside Bazel.
- `:<name>_tar_stage` / `:<name>_tarball` (when `tarball = True`, the default).
  The `pkg_tar` and a user-facing filegroup whose single default output is the distributable `<name>.tgz`.

The runner binary is built once in the rules_celix repository.
`@celix` resolves and the framework is embedded there.
It is copied per container into the package dir as `<name>_runner`.
This keeps `celix_container` free of consumer-side `@celix`.
The runner links the framework statically (`@celix//:framework_static`) and exports its `celix_*` symbols globally with `--export-dynamic`.
Bundle activators linked headers-only (`framework = "runtime"`) resolve their `celix_*` references against that single embedded instance at dlopen time.
That is the mechanism that fixes the C++ ODR crash.
You still need Celix itself for the **bundles'** activators (the `:hello_lib` above links the framework headers).
To get a working framework target without declaring your own `@celix`, depend on `@rules_celix//third_party/celix:framework` (an alias to `@celix//:framework`).
Or declare `@celix` in your own `MODULE.bazel` and pass `@celix//:framework_static` when you need the framework compiled into your artifact.
Pass `@celix//:framework` for the headers-only activator link.
Prefer the `framework = "runtime"` convenience macros, which handle this for you.

## Running

```bash
./bazelw run //:hello_container
```

The runner starts the framework, logs `rules_celix container runner started`, and stays up until it receives a stop signal or `STOP_RUNNER=1` appears in the active `config.properties` (see `examples/hello_container`'s README).
The cache lives in `/tmp` (`CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true`), so repeated runs stay clean and never write into the runfiles tree.

Container outputs are package-relative and real files (deterministic byte copies of the bundle zips, plus the copied runner binary, not symlinks).
They are nested under the container's runtime directory `<name>_runtime/` so the tree can be copied verbatim next to a Celix executable.
Each bundle is laid out by its `Bundle-SymbolicName` (the stable container identity), not the bundle's target or `filename` attribute.
Duplicate symbolic names within one container are rejected at analysis.

## Distributable tarball

`celix_container` builds a deterministic, self-contained `<name>.tgz` by default (`tarball = True`).
Build it explicitly with:

```bash
bazel build //path:name_tarball
# → bazel-bin/path/name.tgz
```

The tarball extracts to the container's deployable layout and runs on a host **without Bazel or Celix installed** (the runner statically embeds the framework):

```
name.tgz
└── name/
    ├── start.sh                # = the generated <name>_start launcher
    ├── name_runner             # the runner copy (embeds the Celix framework)
    └── name_runtime/
        ├── config.properties
        └── bundles/<symbolic_name>.zip
```

```bash
tar -xzf name.tgz
cd name
./start.sh                      # boots the framework; Ctrl-C or STOP_RUNNER=1
```

The archive is deterministic (fixed 2000-01-01 mtimes, fixed `0.0` owner, sorted entries, no absolute bazel-out paths), so identical inputs produce identical bytes.
`start.sh` here is this container's *single-container* launcher.
It is the same script `bazel run` uses, and it is distinct from the multi-container `start.sh`/`stop.sh`/`common.sh` trio of Celix's deprecated `add_celix_runtime` orchestrator.

Set `tarball = False` on `celix_container(...)` to skip the tarball step entirely.
No `rules_pkg` dependency is added.
Use this when only `bazel run` is needed.

> **Per-platform tarballs**: the bundles and the runner are host-platform binaries, so a tarball is platform-specific (Linux ↔ macOS), exactly like the `bazel run` artifact.

## Autostart / start levels (max 7)

Celix auto-starts bundles from the generated config in Karaf style:

- `bundles` maps each bundle to a start level `0..6` (`CELIX_AUTO_START_0` … `CELIX_AUTO_START_6`).
  The framework installs all bundles first, then starts them in ascending level order, preserving declaration order within a level.
  On shutdown they are stopped in reverse order.
  Levels outside `0..6` are rejected at analysis.
- `install_only = [...]` bundles are installed but never started.
  They are emitted under `CELIX_AUTO_INSTALL`, processed after the start set.
- A bundle listed in both a start level and `install_only` is started: AUTO_START wins (with a warning).
  It is excluded from `CELIX_AUTO_INSTALL`.
- A bundle must not be listed under two different levels (rejected at load time).
- `CELIX_AUTO_START_*` / `CELIX_AUTO_INSTALL` values are space-separated paths, so bundle symbolic names must not contain spaces (rejected at analysis).
- Auto-starting a **C++ bundle** requires `framework = "runtime"` (the default for the convenience macros).
  A C++ bundle built with `framework = "static"` embeds its own framework copy and is rejected at analysis if listed in `bundles`.
  It would crash in `celix::impl::createActivator` when started inside the runner's framework instance.
  Move it to `install_only` or switch it to `framework = "runtime"`.
  C bundles are unaffected, static mode keeps working for them.

See [`examples/hello_container`](../../examples/hello_container) for a runnable container.
It auto-starts the C hello bundle (level 1) and the C++ hello bundle (level 2).

## Runner design (condensed)

The runner is a **single shared** `cc_binary` built once in the rules_celix repository.
`@celix` resolves and the framework is embedded there.
It is copied per container via `ctx.actions.copy`.
This keeps `celix_container` free of consumer-side `@celix` and guarantees one framework instance per process.
For the in-depth design (why real file copies rather than symlinks, how the config is generated, why `pkg_tar` is used for the tarball), see [implementation-notes](../developing/implementation-notes.md#runner-and-container-layout-design).
Also see the [hello_container example README](../../examples/hello_container/README.md).

## Next steps

- [quickstart.md](quickstart.md): build your first bundle
- [api.md](api.md): the full public API surface
