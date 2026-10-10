# Status and roadmap

This document is the single source of truth for `rules_celix` project status and milestones. The README and `AGENTS.md` link here rather than duplicating the details.

## Current status

**v0.1.0 released.**  
**v0.2.0 released.** Adds the `celix_c_bundle` / `celix_cpp_bundle` convenience macros.
A single call also creates the activator shared library.
It adds hermetically built real-Celix C and C++ examples (`examples/hello_c`, `examples/hello_cxx`).
It adds expanded analysis + integration test coverage.
**v0.3.0 (in progress).** Adds the runnable `celix_container` and fixes C++ activator framework resolution.
`@celix//:framework` is now a headers-only target.
The container runner embeds one framework copy and exports its `celix_*` symbols.
Bundle activators (`framework = "runtime"`, the default) bind against that single instance.
This lets C++ bundles auto-start without the ODR crash that occurred when each activator embedded its own framework copy.
Containers also emit a deterministic distributable `.tgz` (`celix_container(tarball = True)`) that runs without Bazel.

The ruleset is not yet on the [Bazel Central Registry (BCR)](https://registry.bazel.build/).
BCR publication is planned for v1.0.
Use it via `local_path_override` or `git_override` (pinned to the `v0.2.0` tag or a commit).
See the [quick start](../using/quickstart.md).

The API may change without notice until 1.0.

## Milestones

| Milestone | Status      | Description |
|-----------|-------------|-------------|
| **0.1**   | Done        | Core `celix_bundle` rule: take an existing `cc_shared_library` (activator) + metadata → valid Celix zip. Manifest generation + deterministic packaging (manifest first entry). `CelixBundleInfo` provider. Support for `private_libs` and `resources`. Basic tests + one C example. |
| **0.2**   | Done        | `celix_c_bundle` / `celix_cpp_bundle` convenience macros. They are `srcs`-only, with no explicit `activator` (that stayed `celix_bundle`'s job). It added real-Celix C and C++ examples and the shared-library refactor in `celix/internal/cc.bzl`. |
| **0.3**   | In progress | `celix_container` runnable (hermetic runner binary, generated config, runfiles layout, start-level autostart, C++ framework resolution fix, distributable tarball). See the milestone issues #8 / #9 / #13 / #10 in [implementation-notes.md](implementation-notes.md). |
| **0.4**   | Planned     | Version compatibility tests |
| **1.0**   | Planned     | API freeze, comprehensive docs/stardoc, CI matrix (Linux + macOS), BCR submission via `.bcr/` templates. |

## Related

- [implementation-notes.md](implementation-notes.md): the technical details behind the v0.3.0 work
