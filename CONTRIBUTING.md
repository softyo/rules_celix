# Contributing to rules_celix

Thank you for your interest in contributing to **rules_celix**!

We welcome contributions in the form of bug reports, feature requests, documentation improvements, and code patches.

## Getting Started

1. **Read the [README.md](README.md)** to understand the project's goals, current status, and how to use the ruleset.
2. **Set up your environment**:
   - No pre-installed Bazel is required. Use the provided `./bazelw` (Linux/macOS) or `bazelw.bat` (Windows) wrapper scripts, which automatically download and use the correct version of Bazelisk/Bazel.
   - Ensure you have a standard C/C++ toolchain available (e.g., `gcc` or `clang`), as this ruleset relies on `rules_cc`.

## Reporting Bugs and Requesting Features

When you click **New Issue** on our GitHub repository, you will be presented with two structured templates:

- **🐛 Bug Report**: For unexpected behavior, errors, or build failures.
- **✨ Enhancement Request**: For new features, improvements, or API suggestions.

Please fill out the form as completely as possible. For bug reports, providing your Bazel version, OS, and minimal reproduction steps is incredibly helpful. Before submitting, please check existing issues to avoid duplicates.

## Development Workflow

### Formatting

All Starlark (`.bzl`) files must be formatted with **buildifier**. The repository includes a hermetic buildifier dependency.

To format the entire repository:
```bash
./bazelw run @buildifier_prebuilt//:buildifier -- -r .
```

### Testing

Run the full test suite before submitting changes:
```bash
./bazelw test //...
```

### Pre-Submission Checklist

Before opening a Pull Request, please ensure:
- [ ] All Starlark files are formatted with `buildifier`.
- [ ] `./bazelw test //...` passes.
- [ ] All commits are signed off (`git commit -s`). CI will verify this automatically.
- [ ] If you changed public APIs, the `README.md` documentation is updated.
- [ ] If you changed rule behavior, relevant examples (`examples/`) and tests (`tests/`) are updated.
- [ ] Your commit messages are clear and reference any related issues.

## Code Style

- Follow the official [Starlark Style Guide](https://github.com/bazelbuild/starlark-style-guide).
- Use `load("@rules_celix//celix:defs.bzl", ...)` as the primary load path for public APIs.
- Keep implementation details under `celix/internal/` and do not expose them in `defs.bzl`.
- Add docstrings to all public rules, macros, and providers.

## Pull Request Guidelines

- Keep PRs focused and reasonably sized.
- Link to any related GitHub Issues.
- The project is currently **pre-1.0**. While we aim for API stability, minor breaking changes may occur before v1.0. Clearly note any breaking changes in your PR description.

## Licensing & Contributions

### Apache 2.0 License

All code in this repository is licensed under the [Apache License, Version 2.0](LICENSE).

### No CLA Required

This project **does not** require you to sign a separate Contributor License Agreement (CLA).

### Sign-Off Your Commits

To certify that you have the right to submit your code under the Apache 2.0 license, please **sign off** on your commits:

```txt
Signed-off-by: Joe Smith <joe.smith@email.com>
```

This follows the standard Developer Certificate of Origin (DCO) process. The rules are pretty simple: if you can certify the below (from [developercertificate.org](http://developercertificate.org/)):

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
1 Letterman Drive
Suite D4700
San Francisco, CA, 94129

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

Then you can commit your code. Use your real name (sorry, no pseudonyms or anonymous contributions.)

If you set your `user.name` and `user.email` git configs, you can sign your commit automatically with `git commit -s`:

```bash
git commit -s -m "Your commit message"
```

By doing this, you certify that you wrote the code or have the right to submit it under the open source license.

Thank you for helping make `rules_celix` better!
