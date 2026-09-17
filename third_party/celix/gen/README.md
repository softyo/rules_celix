# Generated Celix headers (reference copies)

Celix's CMake normally generates these headers at configure time from templates:
`celix_framework_export.h` and `celix_utils_export.h` come from
`generate_export_header`, and `celix_err_constants.h` from a
`configure_file(celix_err_constants.h.in)`.

In the native Bazel build these are provided as static, hand-authored copies
(the framework is compiled statically, so all export macros are empty). The
operative copies are injected into the `@celix` source tree by
`third_party/celix/generated_headers.patch` (defined in
`third_party/celix/upstream.bzl`); the files under this directory are the
check-in references for that patch and for human inspection.
