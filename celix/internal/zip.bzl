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

def create_bundle_zip(ctx, manifest, manifest_archive_path, file_specs, zip_tool, zip_name):
    """Create the final bundle zip with the manifest as the first entry.

    Uses a hermetic py_binary tool (//tools:celix_zip) so the packaging step
    is fully hermetic and does not depend on system Python or fragile
    toolchain resolution.  The zip layout follows Celix conventions:
        META-INF/MANIFEST.MF  (or META-INF/MANIFEST.json for Celix 3.x)
        <library basename>
        [additional private libraries]
        [resources preserving their short_path]

    Args:
        ctx: Rule context.
        manifest: File: the generated manifest file.
        manifest_archive_path: string: path inside the zip for the manifest.
        file_specs: list of (src_file, dest, mode) entries to package after the manifest.
        zip_tool: File: the resolved //tools:celix_zip py3_binary.
        zip_name: string: output zip file base name (already includes the .zip suffix).

    Returns:
        File: the output .zip bundle.
    """
    zip_file = ctx.actions.declare_file(zip_name)

    args = ctx.actions.args()
    args.add("--manifest", manifest.path)
    args.add("--manifest-path", manifest_archive_path)
    args.add("--output", zip_file.path)
    inputs = [manifest]
    for (src, dest, mode) in file_specs:
        inputs.append(src)
        args.add("--add", src.path)
        args.add("--dest", dest)
        args.add("--mode", "%o" % mode)

    ctx.actions.run(
        inputs = inputs,
        outputs = [zip_file],
        executable = zip_tool,
        arguments = [args],
        mnemonic = "CelixBundleZip",
        progress_message = "Packaging Celix bundle %{output}",
    )

    return zip_file
