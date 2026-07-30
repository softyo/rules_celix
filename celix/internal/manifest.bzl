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

"""MANIFEST.MF generation for Celix bundles."""

def _write_manifest(ctx, symbolic_name, version, bundle_name):
    manifest = ctx.actions.declare_file("%s.MANIFEST.MF" % ctx.label.name)
    ctx.actions.write(
        output = manifest,
        content = _format_manifest(symbolic_name, version, bundle_name),
    )
    return manifest

def generate_manifest(ctx):
    """Generate a MANIFEST.MF file for the given context.

    Args:
        ctx: The rule context.

    Returns:
        File: the generated MANIFEST.MF.
    """
    bundle_name = ctx.attr.bundle_name if getattr(ctx.attr, "bundle_name", None) else ctx.attr.symbolic_name
    return _write_manifest(
        ctx,
        ctx.attr.symbolic_name,
        ctx.attr.version,
        bundle_name,
    )

def _format_manifest(symbolic_name, version, bundle_name):
    """Format manifest headers into the MANIFEST.MF text.

    Args:
        symbolic_name: Bundle-SymbolicName.
        version: Bundle-Version.
        bundle_name: Bundle-Name (human readable).

    Returns:
        string: MANIFEST.MF content.
    """
    return (
        "Manifest-Version: 1.0\n" +
        "Bundle-Name: {name}\n".format(name = bundle_name) +
        "Bundle-SymbolicName: {sn}\n".format(sn = symbolic_name) +
        "Bundle-Version: {ver}\n".format(ver = version)
    )
