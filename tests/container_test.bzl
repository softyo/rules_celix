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

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//celix:defs.bzl", "celix_container")
load("//celix:providers.bzl", "CelixContainerInfo")

def _test_container_provider(name):
    """Verify a container exposes CelixContainerInfo with ordered bundle copies."""

    def _impl(env, target):
        env.expect.that_target(target).has_provider(CelixContainerInfo)

        info = target[CelixContainerInfo]

        # runner/config are not yet generated.
        env.expect.that_bool(info.runner == None).equals(True)
        env.expect.that_bool(info.config == None).equals(True)

        # Order follows the 'bundles' attribute.
        env.expect.that_collection(info.bundles).has_size(2)
        first = info.bundles[0].path
        second = info.bundles[1].path
        env.expect.that_str(first).contains("bundles/com.example.test.zip")
        env.expect.that_str(second).contains("bundles/com.example.no_activator.zip")

        # Outputs are the same real files the provider carries.
        env.expect.that_target(target).default_outputs().contains(
            info.bundles[0],
        )

    celix_container(
        name = name + "_subject",
        bundles = [
            "//tests/testdata:test_bundle",
            "//tests/testdata:test_bundle_no_activator",
        ],
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
        env.expect.that_str(path).contains("bundles/com.example.full.zip")
        env.expect.that_bool("custom_zip_name.zip" in path).equals(False)

    celix_container(
        name = name + "_subject",
        bundles = ["//tests/testdata:test_bundle_full"],
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
        bundles = ["//tests/testdata:dummy_lib"],
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
        bundles = [
            "//tests/testdata:test_bundle",
            "//tests/testdata:test_bundle_dup",
        ],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
        expect_failure = True,
    )

def celix_container_analysis_test_suite(name):
    """Convenience macro that creates all celix_container analysis tests."""
    _test_container_provider(name = name + "_provider")
    _test_container_renamed(name = name + "_renamed")
    _test_container_non_bundle_fails(name = name + "_non_bundle_fails")
    _test_container_duplicate_symbolic_name_fails(name = name + "_duplicate_symbolic_name_fails")
