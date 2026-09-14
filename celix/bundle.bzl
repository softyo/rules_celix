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

Bundles may also carry private libraries, resources, custom manifest headers, and metadata:

    celix_bundle(
        name = "hello_bundle",
        activator = ":hello_lib",
        symbolic_name = "org.example.hello",
        private_libs = [":helper_lib"],
        resources = [":resource_files"],
        description = "Example bundle",
        group = "org.example",
        filename = "hello",
    )
"""

load("//celix/internal:bundle_impl.bzl", _celix_bundle_impl = "celix_bundle_impl")

def celix_bundle(
        name,
        symbolic_name,
        activator = None,
        version = "0.0.0",
        bundle_name = "",
        celix = "@rules_celix//celix:default_runtime",
        private_libs = [],
        resources = [],
        headers = {},
        description = "",
        group = "",
        filename = "",
        no_activator = False,
        **kwargs):
    """Macro that creates a Celix bundle (zip) from a C/C++ shared library.

    Args:
        name (str): Unique target name for the resulting bundle.
        symbolic_name (str): OSGi `Bundle-SymbolicName` header value.
        activator (Label, optional): Label of a `cc_shared_library` target containing the
            bundle activator. Required unless `no_activator = True`; ignored when
            `no_activator = True`.
        version (str): Bundle version. Defaults to `"0.0.0"`.
        bundle_name (str): Bundle display name. Defaults to symbolic_name if unset.
        celix (Label): Celix runtime target defining manifest format and conventions.
            Defaults to `@rules_celix//celix:default_runtime` (Celix 2.x OSGi properties).
            Use `celix_runtime(name="v3", celix_version="3.0.0")` for the JSON format.
        private_libs (list of Label): Additional private shared libraries to bundle into the
            zip root. Each may be a `cc_shared_library` target or a plain `.so`/`.dylib`/`.dll`
            file (e.g. from a `filegroup`).
        resources (list of Label): Additional resource files (e.g. a `filegroup`) to bundle,
            preserving their package-relative path so subdirectories are supported.
        headers (dict of str to str): Custom manifest headers. Emitted verbatim as `Key: value`
            lines in the properties manifest, and as top-level string fields in the JSON manifest.
        description (str): OSGi `Bundle-Description` header. Only emitted when non-empty.
        group (str): OSGi `Bundle-Group` header. Only emitted when non-empty.
        filename (str): Output zip base name. Defaults to the target `name`. A trailing `.zip`
            is normalized away before `.zip` is appended.
        no_activator (bool): When True, produce a bundle with no activator library and make
            `activator` optional. Defaults to False.
        **kwargs: Additional attributes forwarded to the underlying rule.
    """
    _celix_bundle_impl(
        name = name,
        activator = activator,
        symbolic_name = symbolic_name,
        version = version,
        bundle_name = bundle_name,
        celix = celix,
        private_libs = private_libs,
        resources = resources,
        headers = headers,
        description = description,
        group = group,
        filename = filename,
        no_activator = no_activator,
        **kwargs
    )
