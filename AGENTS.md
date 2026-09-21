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

- v0.1.0 released (tagged `v0.1.0`)
- v0.2.0 in progress: `celix_c_bundle` / `celix_cpp_bundle` convenience macros, hermitically-built real-Celix C and C++ examples (`examples/hello_c`, `examples/hello_cxx`), and the `celix/internal/cc.bzl` shared-library refactor
- Not published to the Bazel Central Registry (BCR) — deferred to v1.0
- API may change without notice until 1.0

## Milestones

| Milestone | Status      | Description |
|-----------|-------------|-------------|
| **0.1**   | Done        | Core `celix_bundle` rule: take an existing `cc_shared_library` (activator) + metadata → valid Celix zip. Manifest generation + deterministic packaging (manifest first entry). `CelixBundleInfo` provider. Support for `private_libs` and `resources`. Basic tests + one C example. |
| **0.2**   | In progress | `celix_c_bundle` / `celix_cpp_bundle` convenience macros (`srcs`-only, no explicit `activator` — that stayed `celix_bundle`'s job), real-Celix C and C++ examples, and the shared-library refactor in `celix/internal/cc.bzl`.
| **0.3**   | Planned     | Basic `celix_container`-style rule or documented pattern for a runnable launcher that embeds a set of bundles. |
| **0.4**   | Planned     | Version compatibility tests |
| **1.0**   | Planned     | API freeze, comprehensive docs/stardoc, CI matrix (Linux + macOS), BCR submission via `.bcr/` templates. |

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
│   ├── runtime.bzl           # Celix runtime version contract
│   ├── providers.bzl         # CelixBundleInfo and related providers
│   └── internal/             # implementation details — do not load from outside
│       ├── bundle_impl.bzl
│       ├── cc.bzl            # shared-library helpers (create_activator_shared_library, …)
│       ├── manifest.bzl      # MANIFEST.MF generation logic
│       └── zip.bzl           # packaging helpers (manifest-first zip via tools/celix_zip.py)
├── third_party/              # hermetic native builds (Celix, libzip, zlib, uuid)
├── examples/                 # runnable, tested samples (hello_c, hello_cxx, …)
├── tests/                    # analysistest + integration tests
├── tools/                    # hermetic helper binaries (celix_zip.py packaging tool)
└── .bcr/                     # BCR submission templates (metadata, source, presubmit)
```

### Where to change what

| Task                              | Primary location              |
|-----------------------------------|-------------------------------|
| Public rule attributes / docs     | `celix/bundle.bzl`, `celix/defs.bzl` |
| Convenience macros (`celix_c_bundle` / `celix_cpp_bundle`) | `celix/bundle.bzl` (note: these are `srcs`-only; the explicit `activator` forward path is `celix_bundle`'s job) |
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
4. **Celix is a peer, not a dependency of the ruleset** — users supply Celix headers/libraries; the ruleset only produces the bundle artifact.
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

- Analysis tests for provider content, output files, and attribute validation.
- Golden / string tests for generated manifests.
- At least one end-to-end example that produces a loadable zip (full Celix runtime test is optional until a container rule exists).
- `bazel test //...` must pass on the supported platforms.

## Style & tooling

- Starlark formatted with **buildifier**.
- Prefer `load("@rules_celix//celix:defs.bzl", ...)` as the only public load path.
- Keep private implementation under `celix/internal/` and do not re-export it from `defs.bzl`.
- Document every public attribute with a docstring suitable for Stardoc.

## Release / BCR notes

- Version tags: `v0.1.0`, `v0.2.0`, …
- Use the templates under `.bcr/` and the [publish-to-bcr](https://github.com/bazel-contrib/publish-to-bcr) workflow when ready.
- Until BCR publication, consumers use `local_path_override` or `git_override` (documented in README.md).

## When implementing changes

1. Prefer extending the existing `celix_bundle` path over adding parallel rules.
2. Update examples and tests in the same change.
3. Keep the README “Quick start” and API table in sync with reality.
4. If the public attribute set changes, note it clearly — the project is still pre-1.0.

## Contact / ownership

This is an independent OSS ruleset aimed at Celix + Bazel users.
Alignment with upstream Apache Celix is desirable but not required for early milestones.
