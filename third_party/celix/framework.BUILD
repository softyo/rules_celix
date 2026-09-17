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

package(default_visibility = ["//visibility:public"])

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
    hdrs = glob([
        "libs/utils/include/**/*.h",
        "libs/utils/include_deprecated/**/*.h",
        "libs/utils/src/**/*.h",
    ]),
    includes = [
        "libs/utils/include",
        "libs/utils/include_deprecated",
        "libs/utils/src",
    ],
    deps = ["@libzip"],
)

cc_library(
    name = "framework",
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
    hdrs = glob([
        "libs/framework/include/**/*.h",
        "libs/framework/include_deprecated/**/*.h",
        "libs/framework/src/**/*.h",
    ]),
    includes = [
        "libs/framework/include",
        "libs/framework/include_deprecated",
        "libs/framework/src",
    ],
    deps = [
        ":utils",
        "@rules_celix//third_party/celix/uuid:uuid",
    ],
    linkopts = select({
        "@platforms//os:macos": ["-lpthread"],
        "//conditions:default": ["-ldl", "-lpthread"],
    }),
)
