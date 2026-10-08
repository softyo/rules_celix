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
        "activator": "File or None: the underlying cc_shared_library .so/.dylib. " +
                     "None when no_activator = True.",
        "private_libs": "list of File: private libraries bundled into the bundle zip root.",
        "link_mode": "string: how the activator resolves the Celix framework: " +
                     "'runtime' (headers-only link; celix_* bind against the " +
                     "container runner's exported framework at dlopen time) or " +
                     "'static' (the framework archive is embedded in the " +
                     "activator .so). None when the bundle has no activator.",
        "uses_cpp": "bool: whether the activator is a C++ bundle (one or more " +
                    ".cc/.cpp/.cxx sources). Only used by the container's " +
                    "auto-start guard for static-mode bundles.",
    },
)

# Provider that carries Celix container metadata and outputs.
CelixContainerInfo = provider(
    doc = "Metadata about a Celix container assembled from celix_bundle targets.",
    fields = {
        "runner": "File: the per-container runner executable (a copy of the " +
                  "shared @rules_celix//tools:container_runner cc_binary, which " +
                  "embeds the Celix framework).",
        "bundles": "list of File: the container's bundle zips under bundles/, " +
                   "flattened in start order: start-level bundles (in the " +
                   "celix_container bundles dict declaration order) followed by " +
                   "install-only bundles.",
        "config": "File: the generated framework configuration file " +
                  "(<name>_runtime/config.properties).",
    },
)

# Provider that describes the targeted Celix runtime version and conventions.
CelixRuntimeInfo = provider(
    doc = "Describes a Celix runtime version and its bundle manifest conventions.",
    fields = {
        "celix_version": "string: Semantic version of the targeted Celix runtime, e.g. '2.4.0' or '3.0.0'.",
    },
)
