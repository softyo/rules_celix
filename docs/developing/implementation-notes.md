# Implementation notes

Gory internals of `rules_celix` for contributors. If you are a consumer, start at [docs/using/](../using/quickstart.md).

## Repository map

```
rules_celix/
├── MODULE.bazel              # module definition & deps (rules_cc, skylib, rules_pkg, rules_testing, stardoc)
├── README.md                 # short onboarding doc; the docs tree lives in docs/
├── AGENTS.md                 # guidance for AI agents / automated contributors
├── LICENSE                   # Apache-2.0
├── celix/                    # *** public API lives here ***
│   ├── BUILD.bazel           # default_runtime target + celix_stardoc generation
│   ├── defs.bzl              # re-exports (load this from user BUILD files)
│   ├── bundle.bzl            # celix_bundle rule / macro entry point
│   ├── container.bzl         # celix_container macro entry point
│   ├── runtime.bzl           # Celix runtime version contract
│   ├── providers.bzl         # CelixBundleInfo/CelixContainerInfo and related providers
│   └── internal/             # implementation details — do not load from outside
│       ├── bundle_impl.bzl
│       ├── cc.bzl            # shared-library helpers (create_activator_shared_library, …)
│       ├── container.bzl     # container layout helpers (bundle_zip_archive_path, config formatting, …)
│       ├── container_impl.bzl # celix_container rule impl (copy-assembly loop)
│       ├── container_tar.bzl # deterministic <name>.tgz packaging via pkg_tar (issue #10)
│       ├── manifest.bzl      # MANIFEST.MF / MANIFEST.json generation logic
│       └── zip.bzl           # packaging helpers (manifest-first zip via tools/celix_zip.py)
├── third_party/              # hermetic native builds (Celix, libzip, zlib) + checked-in uuid
│   ├── celix/                # frames the Apache Celix build (framework.BUILD, upstream.bzl, uuid/)
│   ├── libzip/               # libzip BUILD overlay + generated config headers (patch)
│   └── zlib/                 # zlib BUILD overlay
├── examples/                 # runnable, tested samples (hello_c, hello_cxx, hello_container)
├── tests/                    # analysistest + integration tests (tests/integration/)
├── tools/                    # hermetic helper binaries (celix_zip.py packaging tool, container_runner.c, file_copy.py)
├── docs/                     # consumer docs (using/) + contributor docs (developing/) — index in docs/README.md
└── .bcr/                     # BCR submission templates (metadata, source, presubmit)
```

## Design principles

These come from `AGENTS.md` and should not be violated lightly:

1. **Hermetic by default**: no reliance on system `cmake`, `jar`, or a pre-installed Celix for the packaging step itself.
2. **Thin public surface**: prefer a small `celix_bundle` (+ `celix_container`) over many specialised rules.
3. **Reuse existing rules**: whenever possible, compilation via `rules_cc`.
   Avoid reinventing zip or C/C++ toolchains.
   Zip assembly intentionally uses the small custom tool in `tools/celix_zip.py` instead of `rules_pkg`'s `pkg_zip`.
   Entry sorting would break Celix's manifest-first requirement (see below).
4. **Celix is a peer, not a dependency of the ruleset**: users supply Celix headers/libraries.
   The ruleset only produces the bundle artifact.
   The one exception is the runnable `celix_container`.
   Its runner is built inside rules_celix with the framework compiled in.
   The container is the one place the ruleset ships the framework, kept behind `@rules_celix//third_party/celix:framework`.
5. **Deterministic output**: same inputs → bit-identical (or at least semantically identical) zip.
   `META-INF/MANIFEST.MF` must be the first entry.
6. **bzlmod-first**: `MODULE.bazel` is authoritative.
   Keep any WORKSPACE support minimal and transitional.

## Where to change what

| Task                              | Primary location              |
|-----------------------------------|-------------------------------|
| Public rule attributes / docs     | `celix/bundle.bzl`, `celix/defs.bzl` |
| Convenience macros (`celix_c_bundle` / `celix_cpp_bundle`) | `celix/bundle.bzl` (note: these are `srcs`-only). The explicit `activator` forward path is `celix_bundle`'s job |
| Container layout / `celix_container` | `celix/container.bzl`, `celix/internal/container.bzl`, `celix/internal/container_impl.bzl` |
| Activator shared-library wiring   | `celix/internal/cc.bzl`       |
| Manifest header generation        | `celix/internal/manifest.bzl` |
| Zip assembly / ordering           | `celix/internal/zip.bzl`      |
| Provider definition               | `celix/providers.bzl`         |
| Hermetic native deps (Celix, libzip, zlib, uuid) | `third_party/`     |
| User-visible examples             | `examples/`                   |
| Rule behaviour tests              | `tests/`                      |
| Module dependencies / versions    | `MODULE.bazel`                |
| BCR readiness                     | `.bcr/`                       |

## Hermetic native dependencies

The packaging step itself has no system dependencies.
The framework and its native prerequisites are fetched and built hermetically:

- **`@celix`**: Apache Celix, pinned via `celix_deps` in [`third_party/celix/upstream.bzl`](../../third_party/celix/upstream.bzl) (2.4.0, tag `rel/celix-2.4.0`).
  The `http_archive` overlays `framework.BUILD` and patches in the headers Celix's CMake normally generates at configure time (`generated_headers.patch`).
- **`@zlib`**: vendored zlib 1.3.1 via `third_party/zlib/zlib.BUILD`.
- **`@libzip`**: vendored libzip 1.10.1 via `third_party/libzip/libzip.BUILD`, with the platform config headers (`config.h` / `zipconf.h`) injected by `configs.patch`.
- **`uuid`**: the Celix 2.4.0 framework hard-requires `libuuid`, but only for three RFC 4122 routines (`uuid_generate`/`uuid_parse`/`uuid_unparse`).
  These are provided by the miniature checked-in library in [`third_party/celix/uuid`](../../third_party/celix/uuid) instead of a system libuuid.

Celix 2.4.0 is the latest 2.x release.
A 3.x pin would switch the manifest format to JSON and require changing `//celix:default_runtime`, which is out of scope.
Pinning the framework is the one place the ruleset *does* ship Celix.
See `docs/using/bundles.md` for the user-facing Celix 2.x vs 3.x story.

## Manifest generation

### Properties manifests (Celix 1.x / 2.x)

A minimal useful `MANIFEST.MF` contains headers such as:

- `Manifest-Version: 1.0`
- `Bundle-SymbolicName`
- `Bundle-Version`
- `Bundle-Name` (optional but useful)
- Activator / library entries (`Bundle-Activator` or the Celix-specific private-library style)

The exact header set follows current Celix documentation and the behaviour of Celix's own `BundlePackaging.cmake`.
When in doubt, inspect a bundle produced by official Celix CMake and match it.

### JSON manifests (Celix 3.x)

Targeting a Celix 3.x runtime (`celix_runtime(celix_version = "3.0.0")`) emits `META-INF/MANIFEST.json`.
It uses `CELIX_BUNDLE_*` top-level fields instead of the OSGi properties lines.

## Manifest-first zip assembly

`tools/celix_zip.py` creates the deterministic bundle zip with the manifest as the first *file* entry.
It is preceded by its explicit parent-directory entry.
Celix's bundle extractor requires both.

**Why not `rules_pkg`?** `pkg_zip` sorts entries alphabetically by destination path (see `_load_manifest` in `build_zip.py`).
Since `M` sorts after `l` (for `lib*.so`), `pkg_zip` would place the library before the manifest, producing an invalid Celix bundle.
The small custom tool replaces `pkg_zip` there, and keeps the fixed ZIP epoch timestamp (315532800 = 1980-01-01) used by rules_pkg and the reproducible-builds community.
The container **tarball** step does use `rules_pkg`'s `pkg_tar`.
Tar entry order is irrelevant to Celix, and `pkg_tar` gives the fixed-mtime/owner determinism needed for the distributable container archive (issue #10).

The tool has two modes:

1. **Bundle assembly** (`--manifest`): builds a bundle zip.
   Manifest entry goes first, then the activator library, private libs, and resources with the requested modes (`0755` for libraries, `0644` for resources).
2. **Copy mode** (`--copy`): used by `celix_container` to materialize each bundle zip as a real standalone file under `bundles/`.
   Bytes are copied verbatim (no re-compression) so determinism is inherited from the source bundle.
   Every copied file is then verified to be a valid deterministic Celix bundle zip (manifest first, entries at the fixed ZIP epoch).

## Framework resolution design (v0.3.0, issues #13)

### Before: each activator embedded its own framework

Originally `@celix//:framework` was a linkable target, so each bundle activator embedded its own static framework copy into its `.so`/`.dylib`.
A C++ bundle auto-started inside a container then carried a *second* copy of the C++ framework runtime behind the runner's instance.
That duplicated C++ program state and caused the ODR crash in `celix::impl::createActivator`.

### Now: one framework instance per process

- `@celix//:framework` is the **headers-only** target for bundle activators.
  `celix_c_bundle` / `celix_cpp_bundle` link activators against it in `framework = "runtime"` mode (the default).
  Every `celix_*` symbol stays unresolved in the bundle's `.so`/`.dylib`.
- `@celix//:framework_static` is the embeddable archive.
  The runner compiles it in (`tools/container_runner.c`) and exports it with `--export-dynamic`.
- At dlopen time, the bundle's unresolved `celix_*` symbols bind against the runner's single exported framework instance.
  There is one copy of all C++ program state, so C++ bundles auto-start cleanly.
- `@rules_celix//third_party/celix:framework` aliases `@celix//:framework`.
  It is for consumers who want the bundled framework without declaring their own `@celix`.

On macOS, runtime-mode activator links pass `-Wl,-undefined,dynamic_lookup` (`_RUNTIME_MACOS_LINKOPTS` in `celix/internal/cc.bzl`).
That is the canonical plugin flag.
`ld64` accepts the undefined symbols at link time, and `dyld` resolves them against the runner's `-export_dynamic` symbol table at `dlopen` time.
Linux's GNU ld allows undefined symbols in shared libraries by default.

`framework = "static"` still embeds the archive into the activator for fully self-contained bundles usable outside a runner.
A static-mode **C++** bundle cannot be auto-started by a `celix_container`.
It would crash in `celix::impl::createActivator`.
The container analysis rejects it when listed in `bundles` (install-only is fine).
C bundles are unaffected.

## Runner and container layout design

The container runner (`tools/container_runner.c`) is deliberate and minimal:

- It is a **single shared** `cc_binary` built once in the rules_celix repository.
  `@celix` resolves and the framework is embedded there.
  It is copied per container via `ctx.actions.copy` into the package dir as `<name>_runner`.
  This keeps `celix_container` free of consumer-side `@celix` and guarantees one framework instance per process.
- The generated launcher passes the runtime directory `<name>_runtime/` as `argv[1]`.
  The runner chdirs into it, so the process working directory *is* the container directory.
  All relative paths (`CELIX_BUNDLES_PATH=bundles`, the framework cache, …) resolve against it.
- The runner does **not** install or start bundles itself.
  The generated `config.properties` carries the `CELIX_AUTO_START_*` / `CELIX_AUTO_INSTALL` keys, and the framework's own autostart machinery does the work.
  The runner is a thin embedding shell.
  It creates the framework and logs the fixed sentinel line `rules_celix container runner started`.
  It blocks until a stop signal (SIGINT/SIGTERM) or `STOP_RUNNER=1` appears in the active config.
  The config is re-checked on a 1s timer.
  The `STOP_RUNNER` re-check lets one `bazel run` invocation cover the whole lifecycle without kill races.
  A missing config file also counts as a stop request, so a torn-down runfiles tree cannot wedge `bazel run`.

Container outputs are **real files, not symlinks**, nested under the package-relative runtime directory `<name>_runtime/` (see `celix/internal/container.bzl`).
They are deterministic byte copies of the bundle zips (via `celix_zip.py --copy`) plus the copied runner binary.
Real files keep the tree copyable verbatim next to a Celix executable and safe to place inside a tarball.
Each bundle is laid out at `bundles/<symbolic_name>.zip`, keyed by the stable `Bundle-SymbolicName`.
The symbolic name must be a safe single path component without `/`, `\`, `.`, `..`, or spaces.
The config values are space-separated.
Duplicate symbolic names are rejected at analysis.

### Determinism

- Bundle zips: fixed ZIP epoch (1980-01-01), manifest first.
- Container copies: verbatim bytes, so determinism is inherited from the source bundle.
- `config.properties`: deterministic static keys, then ascending `CELIX_AUTO_START_<level>` lines.
  Only non-empty levels are emitted.
  `CELIX_AUTO_START_0` is omitted when empty.
  `CELIX_AUTO_INSTALL` follows when non-empty.
- Tarball (`celix/internal/container_tar.bzl`): a `pkg_tar` with portable mtime (2000-01-01), fixed owner, sorted entries, and package-root-relative destinations.
  No absolute bazel-out paths.
  Identical inputs produce bit-identical bytes.

Note on packaging the tarball from the runfiles rule's *individual* files rather than a TreeArtifact.
A Bazel analysis-time check forbids declaring a tree artifact whose path nests another rule's output files.
So `<name>_runtime/` cannot both be a TreeArtifact and carry the `CelixContainerInfo.bundles` File objects the analysis tests assert on.
Packaging the runfiles outputs directly keeps the tarball byte-for-byte faithful to the `bazel run` artifact.

The tarball's `start.sh` is the **single-container** launcher (the same script `bazel run` uses).
It is distinct from the multi-container `start.sh`/`stop.sh`/`common.sh` trio of Celix's deprecated `add_celix_runtime` orchestrator.

## Testing

See [testing.md](testing.md) for the framework, test types, and the canonical macOS `.dylib`/`.so` handling rule.
