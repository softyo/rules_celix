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
        framework = ctx.attr.framework,
    )]

celix_runtime = rule(
    implementation = _celix_runtime_impl,
    attrs = {
        "celix_version": attr.string(
            mandatory = True,
            doc = "Semantic version of the targeted Celix runtime, e.g. '2.4.0' or '3.0.0'.",
        ),
        "framework": attr.string(
            default = "@rules_celix//third_party/celix",
            doc = "Framework package label string selecting the Celix framework " +
                  "binaries. The referenced package must expose :framework " +
                  "(headers-only) and :framework_static (full static archive).",
        ),
    },
    doc = """Declares a Celix runtime version that bundles can reference.

`celix_version` selects the **manifest format contract only**:
it chooses `META-INF/MANIFEST.MF` (OSGi-style properties, < 3.0.0) or
`META-INF/MANIFEST.json` (Celix-specific JSON, >= 3.0.0).

`framework` selects the framework binaries linked into bundles: a package
label string (repo name, optionally followed by a package path) that must
expose `:framework` (headers-only) and `:framework_static` (full static
archive). It defaults to `@rules_celix//third_party/celix`, the framework
bundle pinned by the ruleset.

The two attributes are orthogonal: `celix_version` never selects binaries and
`framework` never selects a manifest format. A bundle's manifest format adapts
to the runtime's `celix_version`:

* Celix 1.x / 2.x → `META-INF/MANIFEST.MF` with OSGi-style properties headers.
* Celix 3.x → `META-INF/MANIFEST.json` with Celix-specific JSON headers.
""",
)
