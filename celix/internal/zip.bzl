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

"""Zip assembly helpers for Celix bundle packaging."""

def create_bundle_zip(ctx, library, manifest, zip_tool):
    """Create the final bundle zip with MANIFEST.MF as the first entry.

    Uses a hermetic py_binary tool (//tools:celix_zip) so the packaging step
    is fully hermetic and does not depend on system Python or fragile
    toolchain resolution.  The zip layout follows Celix conventions:
        META-INF/MANIFEST.MF
        <library basename>

    Args:
        ctx: Rule context.
        library: File: the shared library to include.
        manifest: File: the generated MANIFEST.MF.
        zip_tool: File: the resolved //tools:celix_zip py3_binary.

    Returns:
        File: the output .zip bundle.
    """
    zip_file = ctx.actions.declare_file("%s.zip" % ctx.label.name)

    ctx.actions.run(
        inputs = [library, manifest],
        outputs = [zip_file],
        executable = zip_tool,
        arguments = [
            manifest.path,
            library.path,
            zip_file.path,
        ],
        mnemonic = "CelixBundleZip",
        progress_message = "Packaging Celix bundle %{output}",
    )

    return zip_file
