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

"""Analysis tests for the celix_bundle rule."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//celix:defs.bzl", "celix_bundle")
load("//celix:providers.bzl", "CelixBundleInfo")

def _test_bundle_info_provider(name):
    """Verify that a celix_bundle target exposes the expected CelixBundleInfo."""

    def _impl(env, target):
        env.expect.that_target(target).has_provider(CelixBundleInfo)

        info = target[CelixBundleInfo]

        # Attributes forwarded correctly
        env.expect.that_str(info.symbolic_name).equals("com.example.test")
        env.expect.that_str(info.version).equals("1.2.3")

        # Output .zip file: the file is named after the celix_bundle target.
        env.expect.that_file(info.bundle).path().contains("_subject.zip")

        # Activator library is exposed correctly
        activator_path = info.activator.short_path
        env.expect.that_bool(activator_path.endswith(".so") or activator_path.endswith(".dylib")).equals(True)

    # The actual target that analysis_test will inspect.
    celix_bundle(
        name = name + "_subject",
        activator = "//tests/testdata:dummy_lib",
        symbolic_name = "com.example.test",
        version = "1.2.3",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_output_filename(name):
    """Verify that the 'filename' attribute overrides the output zip base name."""

    def _impl(env, target):
        info = target[CelixBundleInfo]

        # Suffix normalization strips the supplied .zip then re-adds it.
        env.expect.that_file(info.bundle).path().contains("custom_zip_name.zip")

    celix_bundle(
        name = name + "_subject",
        activator = "//tests/testdata:dummy_lib",
        symbolic_name = "com.example.full",
        filename = "custom_zip_name.zip",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_no_activator(name):
    """Verify that no_activator = True yields a null activator in the provider."""

    def _impl(env, target):
        info = target[CelixBundleInfo]
        env.expect.that_bool(info.activator == None).equals(True)
        env.expect.that_str(info.symbolic_name).equals("com.example.no_act")

    celix_bundle(
        name = name + "_subject",
        symbolic_name = "com.example.no_act",
        no_activator = True,
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_missing_activator_fails(name):
    """Verify that a bundle without an activator (and no_activator = False) fails analysis."""

    def _impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(
            matching.contains("celix_bundle requires 'activator'"),
        )

    celix_bundle(
        name = name + "_subject",
        symbolic_name = "com.example.fail",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
        expect_failure = True,
    )

def celix_bundle_analysis_test_suite(name):
    """Convenience macro that creates all celix_bundle analysis tests."""
    _test_bundle_info_provider(name = name + "_provider")
    _test_output_filename(name = name + "_filename")
    _test_no_activator(name = name + "_no_activator")
    _test_missing_activator_fails(name = name + "_missing_activator")
