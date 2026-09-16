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

"""Public API for rules_celix.

Load this file to access all user-facing rules and macros:

    load("@rules_celix//celix:defs.bzl", "celix_bundle")
"""

load(
    ":bundle.bzl",
    _celix_bundle = "celix_bundle",
    _celix_c_bundle = "celix_c_bundle",
    _celix_cpp_bundle = "celix_cpp_bundle",
)
load(":providers.bzl", _CelixBundleInfo = "CelixBundleInfo", _CelixRuntimeInfo = "CelixRuntimeInfo")
load(":runtime.bzl", _celix_runtime = "celix_runtime")

celix_bundle = _celix_bundle
celix_c_bundle = _celix_c_bundle
celix_cpp_bundle = _celix_cpp_bundle
CelixBundleInfo = _CelixBundleInfo
CelixRuntimeInfo = _CelixRuntimeInfo
celix_runtime = _celix_runtime
