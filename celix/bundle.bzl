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

"""celix_bundle macro — packs a cc_shared_library into a Celix OSGi bundle.

Generates a `.zip` archive containing `META-INF/MANIFEST.MF` and the activator shared library,
ready to be loaded by an Apache Celix container.

Example:

    load("@rules_celix//celix:defs.bzl", "celix_bundle")

    celix_bundle(
        name = "hello_bundle",
        activator = ":hello_lib",
        symbolic_name = "org.example.hello",
    )
"""

load("//celix/internal:bundle_impl.bzl", _celix_bundle_impl = "celix_bundle_impl")

def celix_bundle(
        name,
        activator,
        symbolic_name,
        version = "0.0.0",
        bundle_name = "",
        celix = "@rules_celix//celix:default_runtime",
        **kwargs):
    """Macro that creates a Celix bundle (zip) from a C/C++ shared library.

    Args:
        name (str): Unique target name for the resulting bundle.
        activator (Label): Label of a `cc_shared_library` target containing the bundle activator.
        symbolic_name (str): OSGi `Bundle-SymbolicName` header value.
        version (str): Bundle version. Defaults to `"0.0.0"`.
        bundle_name (str): Bundle display name. Defaults to symbolic_name if unset.
        celix (Label): Celix runtime target defining manifest format and conventions.
            Defaults to `@rules_celix//celix:default_runtime` (Celix 2.x OSGi properties).
            Use `celix_runtime(name="v3", celix_version="3.0.0")` for the JSON format.
        **kwargs: Additional attributes forwarded to the underlying rule.
    """
    _celix_bundle_impl(
        name = name,
        activator = activator,
        symbolic_name = symbolic_name,
        version = version,
        bundle_name = bundle_name,
        celix = celix,
        **kwargs
    )
