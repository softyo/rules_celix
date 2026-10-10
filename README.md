# rules_celix

[![CI](https://github.com/softyo/rules_celix/actions/workflows/ci.yml/badge.svg)](https://github.com/softyo/rules_celix/actions/workflows/ci.yml)

An OSS Bazel ruleset to support building [Apache Celix](https://celix.apache.org/) bundles and applications.

Celix is an OSGi-inspired framework for C and C++.
A Celix bundle is a zip archive containing a `META-INF/MANIFEST.MF`, one or more shared libraries, and optional resources.
This ruleset lets you produce valid Celix bundles from a fully hermetic Bazel build without invoking Celix’s CMake helpers.

## Status

**v0.3.0 (in progress)**: runnable `celix_container`, C++ framework-resolution fix, deterministic distributable tarball.
Not yet on the [Bazel Central Registry (BCR)](https://registry.bazel.build/) (BCR publication is planned for v1.0).
Use `local_path_override` or `git_override`.
See the [roadmap](docs/developing/roadmap.md) for full status and milestone details.

## Quick start

Add the ruleset to your `MODULE.bazel` (local checkout or git pin):

```python
bazel_dep(name = "rules_celix", version = "0.2.0")
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

You must supply Apache Celix headers and libraries yourself.
This ruleset does not vendor Celix (see [`rules_foreign_cc`](https://github.com/bazel-contrib/rules_foreign_cc)).
The runnable `celix_container` is the one exception.
Its runner ships with the framework embedded.

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
