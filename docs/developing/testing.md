# Testing

How `rules_celix` is tested, and how to write tests for it.

## Expectations

- Analysis tests for provider content, output files, and attribute validation.
- Golden / string tests for generated manifests.
- At least one end-to-end example that produces a loadable zip.
  A full Celix runtime test is optional.
  The container rule covers it.
- `bazel test //...` must pass on the supported platforms.

## Test layout

```
tests/
├── BUILD.bazel                       # assembles analysistest targets from the _test.bzl files
├── celix_bundle_test.bzl             # analysis tests for celix_bundle (outputs, providers, validation)
├── celix_convenience_test.bzl        # analysis tests for the celix_c_bundle / celix_cpp_bundle macros
├── celix_runtime_test.bzl            # analysis tests for celix_runtime
├── container_test.bzl                # analysis tests for celix_container (layout, start levels, guards)
├── manifest_test.bzl                 # golden/string tests for generated manifests
├── testdata/                         # fixture bundles, activators, configs, start-order apps
└── integration/                      # end-to-end py_test suite that boots real Celix
    ├── validate_bundle.py            # validates a bundle zip at build time (--format properties|json)
    ├── validate_container.py         # validates a container's bundle layout
    ├── validate_start_level_config.py# asserts the exact config.properties body
    ├── runner_smoke_test.py          # boots a container's runner hermetically, asserts sentinel + STOP_RUNNER exit
    ├── runner_start_order_test.py    # asserts level-1 starts before level-2 in a real container
    ├── runner_cxx_start_test.py      # asserts a C++ bundle auto-starts without the ODR crash (#13)
    └── container_tarball_test.py     # extracts the .tgz and boots it via ./start.sh without Bazel
```

## Test types

- **Analysis tests** (`*_test.bzl` + `rules_testing`'s `analysis_test`): assert provider content, output file names, and load/analysis-time validation.
  Examples of validation checks: start levels outside 0..6 rejected, duplicate symbolic names rejected, static-mode C++ bundles rejected at start levels.
- **Golden / string tests** (`manifest_test.bzl`): assert exact manifest bodies and manifest-first zip ordering.
- **Integration tests** (`tests/integration/`, `py_test`): boot the real Celix framework via the container runner.
  They assert start order and clean shutdown.
  They exercise the distributable tarball end to end.
  They also assert that real bundle zips are valid.

## Style rules

- Starlark formatted with **buildifier**.
- **Never hardcode shared-library extensions** (`.so`, `.dylib`, `.dll`) in tests, scripts, or docs.
  Bazel output names are platform-dependent.
  `cc_shared_library` produces `lib*.dylib` on macOS, `lib*.so` on Linux.
  Use `select({...})` on `@platforms//os:osx` (etc.) with the extension embedded in the value, or accept any known extension in comparisons.
  The `validate_bundle_full_test` macOS regression (hardcoded `libdummy_lib.so` for the activator) is the canonical example to avoid repeating.
- Prefer `load("@rules_celix//celix:defs.bzl", ...)` as the only public load path.
- Keep private implementation under `celix/internal/` and do not re-export it from `defs.bzl`.
- Document every public attribute with a docstring suitable for Stardoc.
