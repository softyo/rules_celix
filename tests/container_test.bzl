# Copyright 2026 SOFTYONARY SL
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Analysis tests for the celix_container rule."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//celix:defs.bzl", "celix_container")
load("//celix:providers.bzl", "CelixContainerInfo")
load("//celix/internal:container.bzl", "format_config_properties")

def _format_config_golden_impl(ctx):
    """Golden test for the generated framework config body."""
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        "CELIX_BUNDLES_PATH=bundles\n" +
        "CELIX_FRAMEWORK_CACHE_DIR=.cache\n" +
        "CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true\n" +
        "CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info\n",
        format_config_properties(),
    )
    return unittest.end(env)

_format_config_golden_test = unittest.make(_format_config_golden_impl)

def _format_config_empty_golden_impl(ctx):
    """An empty container emits exactly the four static lines (no autostart keys)."""
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        "CELIX_BUNDLES_PATH=bundles\n" +
        "CELIX_FRAMEWORK_CACHE_DIR=.cache\n" +
        "CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true\n" +
        "CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info\n",
        format_config_properties({}, []),
    )
    return unittest.end(env)

_format_config_empty_golden_test = unittest.make(_format_config_empty_golden_impl)

def _format_config_start_levels_golden_impl(ctx):
    """Mixed golden: two start levels plus install_only, in ascending level order."""
    env = unittest.begin(ctx)
    asserts.equals(
        env,
        "CELIX_BUNDLES_PATH=bundles\n" +
        "CELIX_FRAMEWORK_CACHE_DIR=.cache\n" +
        "CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true\n" +
        "CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info\n" +
        "CELIX_AUTO_START_1=bundles/com.example.test.zip\n" +
        "CELIX_AUTO_START_2=bundles/com.example.no_activator.zip\n" +
        "CELIX_AUTO_INSTALL=bundles/com.example.full.zip\n",
        format_config_properties(
            {1: ["bundles/com.example.test.zip"], 2: ["bundles/com.example.no_activator.zip"]},
            ["bundles/com.example.full.zip"],
        ),
    )
    return unittest.end(env)

_format_config_start_levels_golden_test = unittest.make(_format_config_start_levels_golden_impl)

def _test_container_provider(name):
    """Verify a container exposes CelixContainerInfo with runner/config and ordered bundle copies.

    The runner is a copy of the shared @rules_celix//tools:container_runner
    binary (built once per repo, not compiled per container), declared in the
    package dir as <name>_runner.
    """

    def _impl(env, target):
        env.expect.that_target(target).has_provider(CelixContainerInfo)

        info = target[CelixContainerInfo]

        # runner/config are generated Files.
        env.expect.that_bool(info.runner != None).equals(True)
        env.expect.that_bool(info.config != None).equals(True)
        env.expect.that_str(info.runner.basename).contains("runner")
        env.expect.that_str(info.config.basename).equals("config.properties")

        # Order follows the flattened bundles dict: level declaration order.
        env.expect.that_collection(info.bundles).has_size(2)
        first = info.bundles[0].path
        second = info.bundles[1].path
        env.expect.that_str(first).contains("celix_container_test_provider_subject_runtime/bundles/com.example.test.zip")
        env.expect.that_str(second).contains("celix_container_test_provider_subject_runtime/bundles/com.example.no_activator.zip")

        # Outputs are the same real files the provider carries.
        env.expect.that_target(target).default_outputs().contains(
            info.bundles[0],
        )

        # The target is runnable and its runfiles carry the layout.
        env.expect.that_target(target).executable().short_path_equals(
            "tests/celix_container_test_provider_subject",
        )
        env.expect.that_target(target).runfiles().contains_at_least([
            "_main/tests/celix_container_test_provider_subject_runner",
            "_main/tests/celix_container_test_provider_subject_runtime/config.properties",
            "_main/tests/celix_container_test_provider_subject_runtime/bundles/com.example.test.zip",
            "_main/tests/celix_container_test_provider_subject_runtime/bundles/com.example.no_activator.zip",
        ])

    celix_container(
        name = name + "_subject",
        bundles = {
            1: ["//tests/testdata:test_bundle"],
            2: ["//tests/testdata:test_bundle_no_activator"],
        },
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_container_renamed(name):
    """Verify symbolic name wins over the bundle 'filename' attribute."""

    def _impl(env, target):
        info = target[CelixContainerInfo]

        env.expect.that_collection(info.bundles).has_size(1)
        path = info.bundles[0].path
        env.expect.that_str(path).contains("celix_container_test_renamed_subject_runtime/bundles/com.example.full.zip")
        env.expect.that_bool("custom_zip_name.zip" in path).equals(False)

    celix_container(
        name = name + "_subject",
        bundles = {0: ["//tests/testdata:test_bundle_full"]},
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_container_non_bundle_fails(name):
    """Verify a non-bundle input (cc_shared_library) fails analysis cleanly."""

    def _impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(
            matching.contains("CelixBundleInfo"),
        )

    celix_container(
        name = name + "_subject",
        bundles = {0: ["//tests/testdata:dummy_lib"]},
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
        expect_failure = True,
    )

def _test_container_duplicate_symbolic_name_fails(name):
    """Verify duplicate symbolic names within a container fail at analysis."""

    def _impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(
            matching.contains("duplicate bundle symbolic name"),
        )

    celix_container(
        name = name + "_subject",
        bundles = {
            0: ["//tests/testdata:test_bundle", "//tests/testdata:test_bundle_dup"],
        },
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
        expect_failure = True,
    )

def _test_container_install_only(name):
    """Verify start-level bundles come before install-only bundles."""

    def _impl(env, target):
        info = target[CelixContainerInfo]
        env.expect.that_collection(info.bundles).has_size(2)
        first = info.bundles[0].path
        second = info.bundles[1].path
        env.expect.that_str(first).contains("celix_container_test_install_only_subject_runtime/bundles/com.example.test.zip")
        env.expect.that_str(second).contains("celix_container_test_install_only_subject_runtime/bundles/com.example.no_activator.zip")

        # The config output path nests under the container runtime directory.
        env.expect.that_str(info.config.path).contains("celix_container_test_install_only_subject_runtime/config.properties")

    celix_container(
        name = name + "_subject",
        bundles = {1: ["//tests/testdata:test_bundle"]},
        install_only = ["//tests/testdata:test_bundle_no_activator"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_container_level_out_of_range_fails(name):
    """Verify a start level above 6 fails analysis."""

    def _impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(
            matching.contains("level"),
        )

    celix_container(
        name = name + "_subject",
        bundles = {7: ["//tests/testdata:test_bundle"]},
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
        expect_failure = True,
    )

def _test_container_negative_level_fails(name):
    """Verify a negative start level fails analysis."""

    def _impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(
            matching.contains("level"),
        )

    celix_container(
        name = name + "_subject",
        bundles = {-1: ["//tests/testdata:test_bundle"]},
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
        expect_failure = True,
    )

def _test_container_space_in_bundle_name_fails(name):
    """Verify a bundle whose symbolic name contains a space fails analysis."""

    def _impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(
            matching.contains("space"),
        )

    celix_container(
        name = name + "_subject",
        bundles = {0: ["//tests/testdata:test_bundle_space_name"]},
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
        expect_failure = True,
    )

def _test_container_install_only_overlap_wins(name):
    """Verify a bundle in both a level and install_only is AUTO_START: present in
    the runfiles copy list and absent from install_only duplicates."""

    def _impl(env, target):
        info = target[CelixContainerInfo]
        env.expect.that_collection(info.bundles).has_size(1)
        env.expect.that_str(info.bundles[0].path).contains("com.example.test.zip")

    celix_container(
        name = name + "_subject",
        bundles = {1: ["//tests/testdata:test_bundle"]},
        install_only = ["//tests/testdata:test_bundle"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def celix_container_analysis_test_suite(name):
    """Convenience macro that creates all celix_container analysis tests."""
    unittest.suite(
        name + "_format_config",
        _format_config_golden_test,
        _format_config_empty_golden_test,
        _format_config_start_levels_golden_test,
    )
    _test_container_provider(name = name + "_provider")
    _test_container_renamed(name = name + "_renamed")
    _test_container_non_bundle_fails(name = name + "_non_bundle_fails")
    _test_container_duplicate_symbolic_name_fails(name = name + "_duplicate_symbolic_name_fails")
    _test_container_install_only(name = name + "_install_only")
    _test_container_level_out_of_range_fails(name = name + "_level_out_of_range_fails")
    _test_container_negative_level_fails(name = name + "_negative_level_fails")
    _test_container_space_in_bundle_name_fails(name = name + "_space_in_bundle_name_fails")
    _test_container_install_only_overlap_wins(name = name + "_install_only_overlap_wins")
