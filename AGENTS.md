# AGENTS.md — rules_celix

Guidance for AI agents and automated contributors working on this repository.

## Project goal

Provide a small, hermetic, bzlmod-first Bazel ruleset that turns C/C++ shared libraries (and optional resources) into valid **Apache Celix bundles** (zip + `META-INF/MANIFEST.MF`) without requiring Celix’s CMake packaging helpers.

Celix is an OSGi-inspired modular framework for C and C++.
Bundles are the unit of deployment.
This ruleset focuses only on **packaging**; it does not vendor or build the Celix framework itself.

## Non-goals (current)

- Building or distributing Apache Celix itself
- A full replacement for Celix’s CMake ecosystem (`add_celix_container`, feature descriptors, etc.) beyond basic packaging
- Supporting Bazel WORKSPACE-only mode as a first-class citizen (bzlmod is primary)

## Current status

Snapshot; the canonical, always-current status and milestone details live in [`docs/developing/roadmap.md`](docs/developing/roadmap.md):

- v0.1.0 and v0.2.0 released; v0.3.0 in progress (`celix_container` runnable, C++ framework-resolution fix, distributable tarball)
- Not published to the Bazel Central Registry (BCR) — deferred to v1.0
- API may change without notice until 1.0

## Milestones

Single-source table lives in [`docs/developing/roadmap.md`](docs/developing/roadmap.md) (keep it in sync there):

| Milestone | Status       | Summary |
|-----------|--------------|---------|
| **0.1**   | Done         | Core `celix_bundle` rule, deterministic manifest-first zip, `CelixBundleInfo`, private_libs + resources |
| **0.2**   | Done         | `celix_c_bundle` / `celix_cpp_bundle` convenience macros, real-Celix examples, `celix/internal/cc.bzl` refactor |
| **0.3**   | In progress  | `celix_container` runnable (issues #8/#9/#13/#10): hermetic runner, config.properties, start-level autostart, C++ framework resolution, distributable tarball |
| **0.4**   | Planned      | Version compatibility tests |
| **1.0**   | Planned      | API freeze, comprehensive docs/stardoc, CI matrix (Linux + macOS), BCR submission via `.bcr/` templates |

## Repository map

```
rules_celix/
├── MODULE.bazel              # module definition & deps (rules_cc, skylib)
├── README.md                 # human-facing documentation
├── AGENTS.md                 # this file
├── LICENSE                   # Apache-2.0
├── celix/                    # *** public API lives here ***
│   ├── BUILD.bazel
│   ├── defs.bzl              # re-exports (load this from user BUILD files)
│   ├── bundle.bzl            # celix_bundle rule / macro entry point
│   ├── container.bzl         # celix_container macro entry point
│   ├── runtime.bzl           # Celix runtime version contract
│   ├── providers.bzl         # CelixBundleInfo/CelixContainerInfo and related providers
│   └── internal/             # implementation details — do not load from outside
│       ├── bundle_impl.bzl
│       ├── cc.bzl            # shared-library helpers (create_activator_shared_library, …)
│       ├── container.bzl     # container layout helpers (bundle_zip_archive_path, …)
│       ├── container_impl.bzl # celix_container rule impl (copy-assembly loop)
│       ├── manifest.bzl      # MANIFEST.MF generation logic
│       └── zip.bzl           # packaging helpers (manifest-first zip via tools/celix_zip.py)
├── third_party/              # hermetic native builds (Celix, libzip, zlib, uuid)
├── examples/                 # runnable, tested samples (hello_c, hello_cxx, …)
├── tests/                    # analysistest + integration tests
├── tools/                    # hermetic helper binaries (celix_zip.py packaging tool)
├── docs/                     # consumer docs (using/) + contributor docs (developing/) — index in docs/README.md
└── .bcr/                     # BCR submission templates (metadata, source, presubmit)
```

### Where to change what

Also canonical in [docs/developing/implementation-notes.md](docs/developing/implementation-notes.md) (expanded repository map + design principles).

| Task                              | Primary location              |
|-----------------------------------|-------------------------------|
| Public rule attributes / docs     | `celix/bundle.bzl`, `celix/defs.bzl` |
| Convenience macros (`celix_c_bundle` / `celix_cpp_bundle`) | `celix/bundle.bzl` (note: these are `srcs`-only; the explicit `activator` forward path is `celix_bundle`'s job) |
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

## Design principles (do not violate lightly)

1. **Hermetic by default** — no reliance on system `cmake`, `jar`, or a pre-installed Celix for the packaging step itself.
2. **Thin public surface** — prefer a small `celix_bundle` (+ later `celix_container`) over many specialised rules.
3. **Reuse existing rules** — whenever possible: compilation via `rules_cc`; avoid reinventing zip or C/C++ toolchains. Note: zip assembly intentionally uses the small custom tool in `tools/celix_zip.py` instead of `rules_pkg`'s `pkg_zip` (entry sorting would break Celix's manifest-first requirement — see the tool's header).
4. **Celix is a peer, not a dependency of the ruleset** — users supply Celix headers/libraries; the ruleset only produces the bundle artifact. The one exception is the runnable `celix_container`: its runner is built inside rules_celix with the framework compiled in (the container is the one place the ruleset ships the framework), kept behind `@rules_celix//third_party/celix:framework`.
5. **Deterministic output** — same inputs → bit-identical (or at least semantically identical) zip; `META-INF/MANIFEST.MF` must be the first entry.
6. **bzlmod-first** — `MODULE.bazel` is authoritative; keep any WORKSPACE support minimal and transitional.

## Manifest expectations (Celix)

A minimal useful `MANIFEST.MF` contains headers such as:

- `Manifest-Version: 1.0`
- `Bundle-SymbolicName`
- `Bundle-Version`
- `Bundle-Name` (optional but useful)
- Activator / library entries (`Bundle-Activator` or the Celix-specific private-library style)

Exact header set should follow current Celix documentation and the behaviour of Celix’s own `BundlePackaging.cmake`.
When in doubt, inspect a bundle produced by official Celix CMake and match it.

## Testing expectations

See [`docs/developing/testing.md`](docs/developing/testing.md) for the detailed test layout (analysis, golden/manifest, integration), test types, and the shared-library-extension style rule. In short:

- Analysis tests for provider content, output files, and attribute validation.
- Golden / string tests for generated manifests.
- At least one end-to-end example that produces a loadable zip (full Celix runtime test is optional; the container rule covers it).
- `bazel test //...` must pass on the supported platforms.

## Style & tooling

- Starlark formatted with **buildifier**.
- **Never hardcode shared-library extensions** (`.so`, `.dylib`, `.dll`) in tests, scripts, or docs.
  Bazel output names are platform-dependent (`cc_shared_library` produces `lib*.dylib` on macOS, `lib*.so` on Linux).
  Use `select({...})` on `@platforms//os:osx` (etc.) with the extension embedded in the value, or accept any known extension in comparisons.
  The `validate_bundle_full_test` macOS regression (hardcoded `libdummy_lib.so` for the activator) is the canonical example to avoid repeating.
- Prefer `load("@rules_celix//celix:defs.bzl", ...)` as the only public load path.
- Keep private implementation under `celix/internal/` and do not re-export it from `defs.bzl`.
- Document every public attribute with a docstring suitable for Stardoc.

## Markdown style

- One sentence per line in paragraphs.
- Do not use em dashes or en dashes in your response. Use commas or parentheses instead.

## Release / BCR notes

- Version tags: `v0.1.0`, `v0.2.0`, …
- Use the templates under `.bcr/` and the [publish-to-bcr](https://github.com/bazel-contrib/publish-to-bcr) workflow when ready.
- Until BCR publication, consumers use `local_path_override` or `git_override` (documented in [docs/using/quickstart.md](docs/using/quickstart.md), canonical at [docs/using/](docs/using/)).

## When implementing changes

1. Prefer extending the existing `celix_bundle` path over adding parallel rules.
2. Update examples and tests in the same change.
3. Keep `docs/using/` (quickstart, bundles, containers, api) in sync with reality.
4. If the public attribute set changes, note it clearly — the project is still pre-1.0.

## Contact / ownership

This is an independent OSS ruleset aimed at Celix + Bazel users.
Alignment with upstream Apache Celix is desirable but not required for early milestones.
