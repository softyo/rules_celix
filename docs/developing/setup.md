# Development setup

How to get a `rules_celix` development environment up and running.

## Requirements

- A standard C/C++ toolchain (`gcc` or `clang`) for `rules_cc` compilation.
- **No pre-installed Bazel.** The repository ships [`bazelw`](../../bazelw) (Linux / macOS) and [`bazelw.bat`](../../bazelw.bat) (Windows) wrapper scripts.
  They download [Bazelisk](https://github.com/bazelbuild/bazelisk) and use the Bazel version pinned in [`.bazelversion`](../../.bazelversion).
  Run `./bazelw` instead of `bazel` everywhere.
- Build-tool dependencies (`rules_cc`, `rules_pkg`, `rules_testing`, …) are declared in [`MODULE.bazel`](../../MODULE.bazel) and resolved by bzlmod.

## Commands

Format all Starlark files:

```bash
./bazelw run @buildifier_prebuilt//:buildifier -- -r .
```

Run the full test suite:

```bash
./bazelw test //...
```

Build the examples:

```bash
./bazelw build //examples/...
```

Run the runnable container example (starts the real Celix framework):

```bash
./bazelw run //examples/hello_container
```

## Generating API documentation

This repository uses [rules_stardoc](https://github.com/bazelbuild/rules_stardoc) to generate HTML API reference documentation from source docstrings.

To generate the docs locally:

```bash
./bazelw build //celix:celix_stardoc
```

The generated HTML reference will be available at:
`.bazel-bin/celix/celix_api.html`

## Before submitting

Run `./bazelw run @buildifier_prebuilt//:buildifier -- -r .` and the test suite before opening a pull request.
The full pre-submission checklist lives in [CONTRIBUTING.md](../../CONTRIBUTING.md).
