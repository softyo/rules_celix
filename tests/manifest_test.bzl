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

"""Unit + analysis tests for the manifest generation helpers.

Pure-function cases (golden content, line wrapping, header ordering, format
boundary) run through bazel_skylib's unittest harness. The rejection paths
(control characters in JSON values, malformed version strings) are exercised
with rules_testing analysis tests and expect_failure = True, since skylib's
asserts module has no failure-type assertion.
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//celix/internal:manifest.bzl", "format_manifest_json", "format_manifest_properties", "get_manifest_format", "get_manifest_version")

def _properties_minimal_impl(ctx):
    """Minimal properties manifest: golden body, no optional headers."""
    env = unittest.begin(ctx)
    out = format_manifest_properties(
        symbolic_name = "com.example.test",
        version = "1.2.3",
        bundle_name = "Test Bundle",
        description = "",
        group = "",
        private_lib_names = [],
        headers = {},
    )
    asserts.equals(
        env,
        "Manifest-Version: 1.0\n" +
        "Bundle-Name: Test Bundle\n" +
        "Bundle-SymbolicName: com.example.test\n" +
        "Bundle-Version: 1.2.3\n",
        out,
    )
    asserts.true(env, "Bundle-Description" not in out, "description header emitted when empty")
    asserts.true(env, "Bundle-Group" not in out, "group header emitted when empty")
    asserts.true(env, "Private-Library" not in out, "private-library header emitted when empty")
    return unittest.end(env)

def _properties_wrap_impl(ctx):
    """Wrapping: value longer than 72 columns wraps onto space-prefixed lines."""
    env = unittest.begin(ctx)
    out = format_manifest_properties(
        symbolic_name = "com.example.wrap",
        version = "1.0.0",
        bundle_name = "Wrap",
        description = "C" * 150,
        group = "",
        private_lib_names = [],
        headers = {},
    )
    lines = out.split("\n")

    # 4 base headers + 3 wrapped description lines + trailing empty split.
    asserts.equals(env, 8, len(lines))
    body = lines[:len(lines) - 1]
    for line in body:
        asserts.true(env, len(line) <= 72, "line exceeds 72 columns: %r" % line)

    # "Bundle-Description: " (20 chars) leaves 52 columns on the first line.
    asserts.equals(env, "Bundle-Description: %s" % ("C" * 52), body[4])

    # Continuation lines: one leading space, 71 then 27 columns (52+71+27=150).
    asserts.equals(env, " %s" % ("C" * 71), body[5])
    asserts.equals(env, " %s" % ("C" * 27), body[6])
    return unittest.end(env)

def _properties_private_libs_impl(ctx):
    """Private-Library is space-joined; custom headers keep insertion order."""
    env = unittest.begin(ctx)
    out = format_manifest_properties(
        symbolic_name = "com.example.libs",
        version = "2.0.0",
        bundle_name = "Libs",
        description = "",
        group = "internal.test",
        private_lib_names = ["liba.so", "libb.so"],
        headers = {"A-Custom": "hello", "B-Another": "world"},
    )
    asserts.equals(
        env,
        "Manifest-Version: 1.0\n" +
        "Bundle-Name: Libs\n" +
        "Bundle-SymbolicName: com.example.libs\n" +
        "Bundle-Version: 2.0.0\n" +
        "Bundle-Group: internal.test\n" +
        "Private-Library: liba.so libb.so\n" +
        "A-Custom: hello\n" +
        "B-Another: world\n",
        out,
    )
    return unittest.end(env)

def _json_golden_impl(ctx):
    """JSON golden: ordered object, correct commas (no trailing comma)."""
    env = unittest.begin(ctx)
    out = format_manifest_json(
        symbolic_name = "com.example.json",
        version = "3.1.0",
        bundle_name = "Json Bundle",
        manifest_version = "2.0.0",
        description = "A JSON manifest bundle",
        group = "",
        private_lib_names = [],
        headers = {},
    )
    asserts.equals(
        env,
        "{\n" +
        '  "CELIX_BUNDLE_SYMBOLIC_NAME": "com.example.json",\n' +
        '  "CELIX_BUNDLE_NAME": "Json Bundle",\n' +
        '  "CELIX_BUNDLE_VERSION": "3.1.0",\n' +
        '  "CELIX_BUNDLE_MANIFEST_VERSION": "2.0.0",\n' +
        '  "CELIX_BUNDLE_DESCRIPTION": "A JSON manifest bundle"\n' +
        "}\n",
        out,
    )
    return unittest.end(env)

def _json_escape_impl(ctx):
    """JSON escaping: quotes, backslashes and whitespace are escaped."""
    env = unittest.begin(ctx)
    out = format_manifest_json(
        symbolic_name = "com.example.esc",
        version = "1.0.0",
        bundle_name = "Esc",
        manifest_version = None,
        description = '"' + "\\" + "\n" + "\t" + "\r" + "x",
        group = "",
        private_lib_names = [],
        headers = {},
    )
    asserts.true(env, "CELIX_BUNDLE_MANIFEST_VERSION" not in out, "manifest version emitted for None")
    expected_value = '"' + '\\"' + "\\\\" + "\\n" + "\\t" + "\\r" + "x" + '"'
    asserts.true(env, '  "CELIX_BUNDLE_DESCRIPTION": %s\n' % expected_value in out, "escaped JSON value mismatch")
    return unittest.end(env)

def _format_boundary_impl(ctx):
    """Celix version drives format: properties < 3.0.0, json >= 3.0.0."""
    env = unittest.begin(ctx)
    asserts.equals(env, "properties", get_manifest_format("2.4.0"))
    asserts.equals(env, "json", get_manifest_format("3.0.0"))
    asserts.equals(env, "2.0.0", get_manifest_version("3.0.0"))
    asserts.equals(env, None, get_manifest_version("2.4.0"))
    return unittest.end(env)

_manifest_properties_minimal_test = unittest.make(_properties_minimal_impl)
_manifest_properties_wrap_test = unittest.make(_properties_wrap_impl)
_manifest_properties_private_libs_test = unittest.make(_properties_private_libs_impl)
_manifest_json_golden_test = unittest.make(_json_golden_impl)
_manifest_json_escape_test = unittest.make(_json_escape_impl)
_manifest_format_boundary_test = unittest.make(_format_boundary_impl)

def _manifest_failure_case_impl(ctx):
    """Trigger a manifest helper failure at analysis time for expect_failure tests."""
    if ctx.attr.case == "control_char":
        format_manifest_json(
            symbolic_name = "com.example.bad",
            version = "1.0.0",
            bundle_name = "Bad",
            manifest_version = "2.0.0",
            description = "bad\achar",
            group = "",
            private_lib_names = [],
            headers = {},
        )
    elif ctx.attr.case == "invalid_version":
        get_manifest_format("a.b.c")
    elif ctx.attr.case == "empty_version":
        get_manifest_format("")
    elif ctx.attr.case == "partial_version":
        get_manifest_format("1.x")
    fail("unreachable manifest failure case: %s" % ctx.attr.case)

_manifest_failure_case = rule(
    implementation = _manifest_failure_case_impl,
    attrs = {
        "case": attr.string(
            mandatory = True,
            doc = "Which manifest helper failure to trigger during analysis.",
        ),
    },
)

def _make_rejection_impl(expected):
    """Build an analysis_test impl asserting the expected failure message."""

    def _impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(
            matching.contains(expected),
        )

    return _impl

def manifest_test_suite(name):
    """Create all manifest unit + analysis tests and wrap them in a suite.

    Args:
        name: Name of the wrapping test_suite; also the prefix for the
            individual unit and analysis test targets.
    """
    unittest.suite(
        name + "_unit",
        _manifest_properties_minimal_test,
        _manifest_properties_wrap_test,
        _manifest_properties_private_libs_test,
        _manifest_json_golden_test,
        _manifest_json_escape_test,
        _manifest_format_boundary_test,
    )

    reject_names = []
    for case, expected in [
        ("control_char", "Cannot serialize control character"),
        ("invalid_version", "Invalid version string"),
        ("empty_version", "Invalid version string"),
        ("partial_version", "Invalid version string"),
    ]:
        case_name = name + "_reject_" + case
        reject_names.append(":%s" % case_name)
        _manifest_failure_case(
            name = case_name + "_subject",
            case = case,
            tags = ["manual"],
        )
        analysis_test(
            name = case_name,
            target = case_name + "_subject",
            impl = _make_rejection_impl(expected),
            expect_failure = True,
        )

    native.test_suite(
        name = name,
        tests = [":" + name + "_unit"] + reject_names,
    )
