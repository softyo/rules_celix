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

"""celix_runtime rule — declares a Celix runtime version contract for bundles."""

load("//celix:providers.bzl", "CelixRuntimeInfo")

def _celix_runtime_impl(ctx):
    return [CelixRuntimeInfo(
        celix_version = ctx.attr.celix_version,
    )]

celix_runtime = rule(
    implementation = _celix_runtime_impl,
    attrs = {
        "celix_version": attr.string(
            mandatory = True,
            doc = "Semantic version of the targeted Celix runtime, e.g. '2.4.0' or '3.0.0'.",
        ),
    },
    doc = """Declares a Celix runtime version that bundles can reference.

When a `celix_bundle` targets this runtime, the bundle's manifest format
and header conventions adapt accordingly:

* Celix 1.x / 2.x → `META-INF/MANIFEST.MF` with OSGi-style properties headers.
* Celix 3.x → `META-INF/MANIFEST.json` with Celix-specific JSON headers.
""",
)
