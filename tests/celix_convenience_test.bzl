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

"""Analysis tests for the celix_c_bundle / celix_cpp_bundle convenience macros."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//celix:defs.bzl", "celix_c_bundle", "celix_cpp_bundle")
load("//celix:providers.bzl", "CelixBundleInfo")

def _test_macro_c_provider(name):
    """Verify a celix_c_bundle subject exposes the expected CelixBundleInfo."""

    def _impl(env, target):
        env.expect.that_target(target).has_provider(CelixBundleInfo)

        info = target[CelixBundleInfo]

        env.expect.that_str(info.symbolic_name).equals("com.example.macro_c")
        env.expect.that_str(info.version).equals("0.0.0")

        env.expect.that_file(info.bundle).path().contains("_subject.zip")

        activator_path = info.activator.short_path
        env.expect.that_bool(activator_path.endswith(".so") or activator_path.endswith(".dylib")).equals(True)

    celix_c_bundle(
        name = name + "_subject",
        symbolic_name = "com.example.macro_c",
        srcs = ["//tests/testdata:dummy_activator.c"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_macro_cpp_provider(name):
    """Verify a celix_cpp_bundle subject keeps an explicit version and C++ linkage."""

    def _impl(env, target):
        env.expect.that_target(target).has_provider(CelixBundleInfo)

        info = target[CelixBundleInfo]

        env.expect.that_str(info.symbolic_name).equals("com.example.macro_cpp")
        env.expect.that_str(info.version).equals("1.2.3")

        activator_path = info.activator.short_path
        env.expect.that_bool(activator_path.endswith(".so") or activator_path.endswith(".dylib")).equals(True)

    celix_cpp_bundle(
        name = name + "_subject",
        symbolic_name = "com.example.macro_cpp",
        srcs = ["//tests/testdata:dummy_activator.cc"],
        version = "1.2.3",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_macro_includes_forwarded(name):
    """Verify an `includes`-bearing convenience macro still yields a valid bundle.

    Note: rules_testing's analysis harness exposes the target under test only via
    providers, so traversing into the macro-generated `cc_library`/`cc_shared_library`
    attributes is impractical here. The authoritative proof of copts/includes/linkopts
    forwarding is the compile-gated `macro_flags_bundle` integration test; this analysis
    test asserts the bundle provider is still produced without analysis errors.
    """

    def _impl(env, target):
        env.expect.that_target(target).has_provider(CelixBundleInfo)

        info = target[CelixBundleInfo]
        env.expect.that_str(info.symbolic_name).equals("com.example.macro_includes")

    celix_c_bundle(
        name = name + "_subject",
        symbolic_name = "com.example.macro_includes",
        srcs = ["//tests/testdata:dummy_activator.c"],
        includes = ["inc"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_macro_missing_srcs_fails(name):
    """Verify that an empty `srcs` list fails analysis with a clear message."""

    def _impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(
            matching.contains("requires at least one source file"),
        )

    celix_c_bundle(
        name = name + "_subject",
        symbolic_name = "com.example.fail",
        srcs = [],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
        expect_failure = True,
    )

def _test_macro_copts_linkopts_accepted(name):
    """Verify copts/linkopts are accepted and a valid bundle is still produced."""

    def _impl(env, target):
        env.expect.that_target(target).has_provider(CelixBundleInfo)

        info = target[CelixBundleInfo]
        env.expect.that_str(info.symbolic_name).equals("com.example.macro_flags")
        env.expect.that_str(info.version).equals("0.0.0")

    celix_c_bundle(
        name = name + "_subject",
        symbolic_name = "com.example.macro_flags",
        srcs = ["//tests/testdata:dummy_activator.c"],
        copts = ["-DENABLED_TEST=1"],
        linkopts = ["-lm"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_macro_provider_fields_defaults(name):
    """Verify CelixBundleInfo exposes the framework link-mode metadata for the
    default (runtime) mode: link_mode = "runtime" and uses_cpp matching the
    source language."""

    def _impl(env, target):
        info = target[CelixBundleInfo]
        env.expect.that_str(info.link_mode).equals("runtime")
        env.expect.that_bool(info.uses_cpp).equals(False)

    celix_c_bundle(
        name = name + "_subject",
        symbolic_name = "com.example.provider_fields",
        srcs = ["//tests/testdata:dummy_activator.c"],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_macro_cpp_provider_fields(name):
    """Verify a celix_cpp_bundle reports link_mode runtime + uses_cpp True, and
    a static-mode bundle reports link_mode "static"."""

    def _impl_runtime(env, target):
        info = target[CelixBundleInfo]
        env.expect.that_str(info.link_mode).equals("runtime")
        env.expect.that_bool(info.uses_cpp).equals(True)

    celix_cpp_bundle(
        name = name + "_subject_runtime",
        symbolic_name = "com.example.provider_fields_cpp",
        srcs = ["//tests/testdata:dummy_activator.cc"],
        tags = ["manual"],
    )

    analysis_test(
        name = name + "_runtime",
        target = name + "_subject_runtime",
        impl = _impl_runtime,
    )

    def _impl_static(env, target):
        info = target[CelixBundleInfo]
        env.expect.that_str(info.link_mode).equals("static")
        env.expect.that_bool(info.uses_cpp).equals(True)

    celix_cpp_bundle(
        name = name + "_subject_static",
        symbolic_name = "com.example.provider_fields_cpp_static",
        srcs = ["//tests/testdata:dummy_activator.cc"],
        framework = "static",
        tags = ["manual"],
    )

    analysis_test(
        name = name + "_static",
        target = name + "_subject_static",
        impl = _impl_static,
    )

def _test_macro_cpp_extension(name, src, sym):
    """Verify a celix_cpp_bundle fed the non-standard C++ extension .C (which
    rules_cc treats as C++) still reports uses_cpp = True with the default
    runtime link_mode, so the container's static-mode guard sees it as C++.

    The other allowlisted extensions (.cu requires a CUDA toolchain, .mm an
    Objective-C++ one) cannot be analyzed on a plain C++ toolchain, so .C is
    the only testable representative here.
    """

    def _impl(env, target):
        info = target[CelixBundleInfo]
        env.expect.that_str(info.link_mode).equals("runtime")
        env.expect.that_bool(info.uses_cpp).equals(True)

    celix_cpp_bundle(
        name = name + "_subject",
        symbolic_name = sym,
        srcs = [src],
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def _test_macro_cpp_extension_static(name):
    """Verify a static-mode celix_cpp_bundle fed a .C source reports
    link_mode = "static" and uses_cpp = True."""

    def _impl(env, target):
        info = target[CelixBundleInfo]
        env.expect.that_str(info.link_mode).equals("static")
        env.expect.that_bool(info.uses_cpp).equals(True)

    celix_cpp_bundle(
        name = name + "_subject",
        symbolic_name = "com.example.macro_cpp_ext_static",
        srcs = ["//tests/testdata:dummy_activator_ext.C"],
        framework = "static",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def celix_convenience_analysis_test_suite(name):
    """Convenience macro that creates all convenience-macro analysis tests."""
    _test_macro_c_provider(name = name + "_provider_c")
    _test_macro_cpp_provider(name = name + "_provider_cpp")
    _test_macro_includes_forwarded(name = name + "_includes")
    _test_macro_missing_srcs_fails(name = name + "_missing_srcs")
    _test_macro_copts_linkopts_accepted(name = name + "_copts_linkopts")
    _test_macro_provider_fields_defaults(name = name + "_provider_fields")
    _test_macro_cpp_provider_fields(name = name + "_cpp_provider_fields")
    _test_macro_cpp_extension(name = name + "_cpp_ext_dot_c_upper", src = "//tests/testdata:dummy_activator_ext.C", sym = "com.example.macro_cpp_ext_c_upper")
    _test_macro_cpp_extension_static(name = name + "_cpp_ext_static")
