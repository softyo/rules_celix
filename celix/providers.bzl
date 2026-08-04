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

"""Providers for rules_celix."""

# Provider that carries Celix bundle metadata and outputs.
CelixBundleInfo = provider(
    doc = "Metadata about a Celix OSGi bundle.",
    fields = {
        "bundle": "File: the output .zip bundle artifact.",
        "symbolic_name": "string: Bundle-SymbolicName from MANIFEST.MF.",
        "bundle_name": "string: Bundle-Name from MANIFEST.MF.",
        "version": "string: Bundle-Version from MANIFEST.MF.",
        "activator": "File: the underlying cc_shared_library .so/.dylib.",
    },
)

# Provider that describes the targeted Celix runtime version and conventions.
CelixRuntimeInfo = provider(
    doc = "Describes a Celix runtime version and its bundle manifest conventions.",
    fields = {
        "celix_version": "string: Semantic version of the targeted Celix runtime, e.g. '2.4.0' or '3.0.0'.",
    },
)
