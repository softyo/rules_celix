# Native Bazel build for the Apache Celix 2.4.0 framework.
#
# This file is used as the `build_file` overlay for the `@celix` http_archive
# (see third_party/celix/upstream.bzl). It maps the framework and its `libs/utils`
# dependency as plain cc_library static archives so that a bundle activator's
# cc_shared_library can link libcelix statically into its own .so/.dylib.
#
# Only the framework core + the example's needs are built. celix_launcher.c is
# intentionally omitted because it drags in libcurl (GUARDed by CELIX_NO_CURLINIT);
# optional subsystems (DFI, remote services, HTTP admin, ...) are not mapped.
#
# The generated headers that Celix's CMake would produce (celix_framework_export.h,
# celix_utils_export.h, celix_err_constants.h) are hand-authored in rules_celix
# under third_party/celix/gen/ and injected into this tree by the
# `generated_headers.patch` applied in third_party/celix/upstream.bzl.
#
# Framework link mode (issue #13):
#
# - `:framework` is the **headers-only** public target for bundle activators.
#   It ships the same include tree as the compiled framework but contributes no
#   compiled objects, so an activator linked against it leaves every `celix_*`
#   symbol unresolved. Inside a `celix_container`, the container runner exports
#   its own embedded static copy of the framework (`--export-dynamic`), and the
#   activator's unresolved `celix_*` bind against that single instance at
#   dlopen time. This single-instance property is what keeps a C++ activator
#   from embedding a second framework copy (which ODR-crashes inside
#   `celix::impl::createActivator` — see the fix plan for issue #13).
# - `:framework_static` is the embeddable archive (the former `:framework` body):
#   fully self-contained bundles (.so with the framework compiled in), for use
#   outside a container runner (or as the `framework = "static"` opt-in knob).
#
# `alwayslink = True` on `:framework_static` and `:utils` keeps every framework
# object inside the container runner's archive so the runner's dynamic symbol
# table exports the complete `celix_*`/`celix_utils_*` surface for dlopened
# bundles.

package(default_visibility = ["//visibility:public"])

_UTILS_HDRS = glob([
    "libs/utils/include/**/*.h",
    "libs/utils/include_deprecated/**/*.h",
    "libs/utils/src/**/*.h",
])

_UTILS_INCLUDES = [
    "libs/utils/include",
    "libs/utils/include_deprecated",
    "libs/utils/src",
]

_FRAMEWORK_HDRS = glob([
    "libs/framework/include/**/*.h",
    "libs/framework/include_deprecated/**/*.h",
    "libs/framework/src/**/*.h",
])

_FRAMEWORK_INCLUDES = [
    "libs/framework/include",
    "libs/framework/include_deprecated",
    "libs/framework/src",
]

_FRAMEWORK_LINKOPTS = select({
    "@platforms//os:macos": ["-lpthread"],
    "//conditions:default": [
        "-ldl",
        "-lpthread",
    ],
})

# Compiled `libs/utils` archive. Every object is always linked so the container
# runner (and `framework = "static"` bundles) carry the full utils API surface;
# the dlopened bundle's unresolved `celix_*` / `celix_utils_*` resolve against
# whichever archive owns the definitions at load time.
cc_library(
    name = "utils",
    srcs = [
        "libs/utils/src/array_list.c",
        "libs/utils/src/celix_cleanup.c",
        "libs/utils/src/celix_convert_utils.c",
        "libs/utils/src/celix_err.c",
        "libs/utils/src/celix_errno.c",
        "libs/utils/src/celix_file_utils.c",
        "libs/utils/src/celix_hash_map.c",
        "libs/utils/src/celix_log_level.c",
        "libs/utils/src/celix_log_utils.c",
        "libs/utils/src/celix_threads.c",
        "libs/utils/src/filter.c",
        "libs/utils/src/hash_map.c",
        "libs/utils/src/ip_utils.c",
        "libs/utils/src/linked_list.c",
        "libs/utils/src/linked_list_iterator.c",
        "libs/utils/src/properties.c",
        "libs/utils/src/utils.c",
        "libs/utils/src/version.c",
        "libs/utils/src/version_range.c",
    ],
    hdrs = _UTILS_HDRS,
    includes = _UTILS_INCLUDES,
    deps = ["@libzip"],
    alwayslink = True,
)

# Headers-only view of `libs/utils` for `:framework` (the runtime link mode):
# activators get the utils public include tree without drawing utils objects
# into their own .so (those stay unresolved and bind against the runner).
cc_library(
    name = "utils_headers",
    hdrs = _UTILS_HDRS,
    includes = _UTILS_INCLUDES,
)

# Headers-only framework target — the activation default (`framework = "runtime"`).
# No `srcs`: a compiled object here would embed a second framework instance and
# reintroduce the C++ ODR crash as soon as the bundle is dlopened. The `deps` on
# `:utils_headers` only forwards the utils header tree, nothing to link.
cc_library(
    name = "framework",
    hdrs = _FRAMEWORK_HDRS,
    includes = _FRAMEWORK_INCLUDES,
    deps = [":utils_headers"],
)

# The embeddable framework archive (`framework = "static"` mode, and what the
# `celix_container` runner links). Same sources/deps/linkopts as the pre-#13
# `:framework`, renamed so the public `:framework` name can carry the
# headers-only variant. `alwayslink` guarantees the runner's archive contains
# every object, so `--export-dynamic` exports all `celix_*` entry points.
cc_library(
    name = "framework_static",
    srcs = [
        "libs/framework/src/bundle.c",
        "libs/framework/src/bundle_archive.c",
        "libs/framework/src/bundle_context.c",
        "libs/framework/src/bundle_revision.c",
        "libs/framework/src/capability.c",
        "libs/framework/src/celix_bundle_cache.c",
        "libs/framework/src/celix_bundle_state.c",
        "libs/framework/src/celix_framework_bundle.c",
        "libs/framework/src/celix_framework_factory.c",
        "libs/framework/src/celix_framework_utils.c",
        "libs/framework/src/celix_libloader.c",
        "libs/framework/src/celix_log.c",
        "libs/framework/src/celix_scheduled_event.c",
        "libs/framework/src/dm_component_impl.c",
        "libs/framework/src/dm_dependency_manager_impl.c",
        "libs/framework/src/dm_service_dependency.c",
        "libs/framework/src/framework.c",
        "libs/framework/src/framework_bundle_lifecycle_handler.c",
        "libs/framework/src/manifest.c",
        "libs/framework/src/manifest_parser.c",
        "libs/framework/src/module.c",
        "libs/framework/src/requirement.c",
        "libs/framework/src/service_reference.c",
        "libs/framework/src/service_registration.c",
        "libs/framework/src/service_registry.c",
        "libs/framework/src/service_tracker.c",
        "libs/framework/src/service_tracker_customizer.c",
        "libs/framework/src/wire.c",
    ],
    hdrs = _FRAMEWORK_HDRS,
    includes = _FRAMEWORK_INCLUDES,
    linkopts = _FRAMEWORK_LINKOPTS,
    deps = [
        ":utils",
        "@rules_celix//third_party/celix/uuid",
    ],
    alwayslink = True,
)
