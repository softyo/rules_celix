# rules_celix

[![CI](https://github.com/softyo/rules_celix/actions/workflows/ci.yml/badge.svg)](https://github.com/softyo/rules_celix/actions/workflows/ci.yml)

An OSS Bazel ruleset to support building [Apache Celix](https://celix.apache.org/) bundles and applications.

Celix is an OSGi-inspired framework for C and C++.
A Celix bundle is a zip archive containing a `META-INF/MANIFEST.MF`, one or more shared libraries, and optional resources.
This ruleset lets you produce valid Celix bundles from a fully hermetic Bazel build without invoking Celix’s CMake helpers.

## Status

**v0.3.0 released**: runnable `celix_container`, C++ framework-resolution fix, deterministic distributable tarball.
Not yet on the [Bazel Central Registry (BCR)](https://registry.bazel.build/) (BCR publication is planned for v1.0).
Use `local_path_override` or `git_override`.
See the [roadmap](docs/developing/roadmap.md) for full status and milestone details.

## Versioning: bottom line (to rephrase in v0.5.0)

This section records the framework versioning strategy agreed during the
bring-your-own-Celix milestone (0.4) planning. It is a temporary reminder and
will be rephrased when the version-compatibility tests land (v0.5.0).

- `rules_celix` declares its `celix` dependency floor at the minimum version it
  tests, currently 2.4.0, not an arbitrarily low value like 2.0.0.
- The `celix` Bazel module (the `celix-bazel` repo) releases one module version
  per Apache Celix upstream release, by necessity, but never in lockstep with
  `rules_celix`.
- Once `rules_celix` depends on the `celix` module instead of pinning its own
  fetch, one `rules_celix` release covers all supported Celix versions.
- The consumer selects the Celix version through `bazel_dep` and Bazel's minimal
  version selection (MVS); the higher declared version wins.
- The version-permutation burden moves into CI as version-compatibility tests
  (milestone 0.5), not into parallel `rules_celix` releases.
- Keep the `celix` module's `compatibility_level` and public target names stable
  for the single-release model to hold.
- Raise the floor deliberately, and only when support for older Celix versions
  is dropped.

## Quick start

Add the ruleset to your `MODULE.bazel` (local checkout or git pin):

```python
bazel_dep(name = "rules_celix", version = "0.3.0")
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

The ruleset fetches and builds its own Apache Celix 2.4.0 (`celix_deps` in `MODULE.bazel`), so the convenience macros and the runnable `celix_container` need no consumer-supplied Celix.
Use the explicit `activator` path of `celix_bundle`, or supply your own `@celix`, only when you need a different framework or build it yourself (see [`rules_foreign_cc`](https://github.com/bazel-contrib/rules_foreign_cc)).

Build your first bundle:

```python
# BUILD.bazel
load("@rules_celix//celix:defs.bzl", "celix_c_bundle")

celix_c_bundle(
    name = "hello_bundle",
    symbolic_name = "com.example.hello",
    version = "1.0.0",
    srcs = ["hello_activator.c"],
)
```

```bash
./bazelw build //:hello_bundle
# → bazel-bin/hello_bundle.zip   (valid Celix bundle)
```

Full walkthrough: [docs/using/quickstart.md](docs/using/quickstart.md).

## Documentation

- **For consumers**: [docs/using/](docs/using/). Quickstart, bundles, containers, and API reference ([quickstart](docs/using/quickstart.md), [bundles](docs/using/bundles.md), [containers](docs/using/containers.md), [API reference](docs/using/api.md)).
- **For contributors**: [docs/developing/](docs/developing/). Setup, roadmap, implementation notes, testing, and releasing ([setup](docs/developing/setup.md), [roadmap](docs/developing/roadmap.md), [implementation notes](docs/developing/implementation-notes.md), [testing](docs/developing/testing.md), [releasing](docs/developing/releasing.md)).
- Start at the [docs index](docs/README.md).

## Contributing

Issues and pull requests are welcome.
Please run `./bazelw run @buildifier_prebuilt//:buildifier -- -r .` and the test suite before submitting.
See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

Apache License 2.0, same as Apache Celix.

## Related projects

- [Apache Celix](https://celix.apache.org/)
- [rules_pkg](https://github.com/bazelbuild/rules_pkg)
- [rules_foreign_cc](https://github.com/bazel-contrib/rules_foreign_cc) (useful for building Celix itself from source)
