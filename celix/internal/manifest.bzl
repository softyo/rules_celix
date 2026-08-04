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

"""MANIFEST.MF / MANIFEST.json generation for Celix bundles.

Manifest format is driven by the Celix runtime version:
  * 1.x / 2.x → META-INF/MANIFEST.MF  (Java-properties style, OSGi headers)
  * 3.x       → META-INF/MANIFEST.json (JSON, CELIX_BUNDLE_* headers)
"""

load("//celix:providers.bzl", "CelixRuntimeInfo")

# Versions >= this threshold use the JSON manifest format.
_VERSION_TO_MANIFEST_FORMAT = (3, 0, 0)

def _parse_version(version_str):
    """Parse a semver string into a tuple of ints, e.g. '2.4.0' → (2, 4, 0).

    Args:
        version_str: Semantic version string.

    Returns:
        tuple of (major, minor, patch) as ints.
    """
    parts_str = version_str.split(".")
    if len(parts_str) < 1:
        fail("Invalid version string: '%s'" % version_str)

    # Manually parse each component; Starlark does not support try/except.
    parts = []
    for p in parts_str:
        if not p.isdigit():
            fail("Invalid version string: '%s'" % version_str)
        parts.append(int(p))

    # Pad to at least 3 components so tuple comparison works.
    if len(parts) == 1:
        parts += [0, 0]
    elif len(parts) == 2:
        parts.append(0)
    return tuple(parts[:3])

def _get_manifest_format(celix_version_str):
    """Return 'properties' for Celix < 3.0.0, 'json' for >= 3.0.0."""
    if _parse_version(celix_version_str) >= _VERSION_TO_MANIFEST_FORMAT:
        return "json"
    return "properties"

def _get_manifest_version(celix_version_str):
    """Return the CELIX_BUNDLE_MANIFEST_VERSION string for the JSON format.

    For Celix 3.0.0, this is '2.0.0' (per the upstream MANIFEST.json.in template).
    This value reflects the manifest format version, not the Celix version.

    Args:
        celix_version_str: The Celix runtime version.

    Returns:
        string or None: manifest format version for JSON, None for properties.
    """
    if _parse_version(celix_version_str) >= (3, 0, 0):
        return "2.0.0"
    return None

def generate_manifest(ctx):
    """Generate the appropriate manifest file for the given rule context.

    Args:
        ctx: Rule context. Must have .attr.celix (CelixRuntimeInfo provider).

    Returns:
        struct with fields:
            file: File — the generated manifest (MF or JSON).
            archive_path: string — path inside the zip.
            format: string — 'properties' or 'json'.
    """
    celix_version = ctx.attr.celix[CelixRuntimeInfo].celix_version
    fmt = _get_manifest_format(celix_version)

    bundle_name = ctx.attr.bundle_name if getattr(ctx.attr, "bundle_name", None) else ctx.attr.symbolic_name

    if fmt == "json":
        return _generate_manifest_json(ctx, celix_version, bundle_name)
    return _generate_manifest_properties(ctx, bundle_name)

def _generate_manifest_properties(ctx, bundle_name):
    """Generate a META-INF/MANIFEST.MF file with OSGi-style headers."""
    archive_path = "META-INF/MANIFEST.MF"
    manifest = ctx.actions.declare_file("%s.MANIFEST.MF" % ctx.label.name)
    ctx.actions.write(
        output = manifest,
        content = _format_manifest_properties(
            symbolic_name = ctx.attr.symbolic_name,
            version = ctx.attr.version,
            bundle_name = bundle_name,
        ),
    )
    return struct(file = manifest, archive_path = archive_path, format = "properties")

def _generate_manifest_json(ctx, celix_version, bundle_name):
    """Generate a META-INF/MANIFEST.json file with CELIX_BUNDLE_* headers."""
    archive_path = "META-INF/MANIFEST.json"
    manifest = ctx.actions.declare_file("%s.MANIFEST.json" % ctx.label.name)
    manifest_version = _get_manifest_version(celix_version)
    ctx.actions.write(
        output = manifest,
        content = _format_manifest_json(
            symbolic_name = ctx.attr.symbolic_name,
            version = ctx.attr.version,
            bundle_name = bundle_name,
            manifest_version = manifest_version,
        ),
    )
    return struct(file = manifest, archive_path = archive_path, format = "json")

def _format_manifest_properties(symbolic_name, version, bundle_name):
    """Format manifest headers into the MANIFEST.MF text (OSGi properties).

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

def _format_manifest_json(symbolic_name, version, bundle_name, manifest_version):
    """Format manifest headers into the MANIFEST.json text (Celix 3.x JSON).

    Args:
        symbolic_name: Bundle symbolic name.
        version: Bundle version.
        bundle_name: Bundle display name.
        manifest_version: CELIX_BUNDLE_MANIFEST_VERSION value.

    Returns:
        string: MANIFEST.json content.
    """

    # Build JSON manually to control key ordering deterministically
    # and avoid depending on the json module at analysis time.
    lines = [
        "{",
        '  "CELIX_BUNDLE_SYMBOLIC_NAME": "{sn}",'.format(sn = symbolic_name),
        '  "CELIX_BUNDLE_NAME": "{name}",'.format(name = bundle_name),
        '  "CELIX_BUNDLE_VERSION": "{ver}",'.format(ver = version),
    ]
    if manifest_version:
        lines.append('  "CELIX_BUNDLE_MANIFEST_VERSION": "{mv}"'.format(mv = manifest_version))
    lines.append("}")
    return "\n".join(lines) + "\n"
