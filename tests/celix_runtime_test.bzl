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

"""Analysis tests for the celix_runtime rule."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//celix:defs.bzl", "celix_runtime")
load("//celix:providers.bzl", "CelixRuntimeInfo")

def _test_runtime_info_provider(name):
    """Verify that a celix_runtime target exposes the expected CelixRuntimeInfo."""

    def _impl(env, target):
        env.expect.that_target(target).has_provider(CelixRuntimeInfo)

        info = target[CelixRuntimeInfo]
        env.expect.that_str(info.celix_version).equals("3.0.0")

    celix_runtime(
        name = name + "_subject",
        celix_version = "3.0.0",
        tags = ["manual"],
    )

    analysis_test(
        name = name,
        target = name + "_subject",
        impl = _impl,
    )

def celix_runtime_analysis_test_suite(name):
    """Convenience macro that creates all celix_runtime analysis tests."""
    _test_runtime_info_provider(name = name + "_provider")
