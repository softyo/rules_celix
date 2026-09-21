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

def get_manifest_format(celix_version_str):
    """Return 'properties' for Celix < 3.0.0, 'json' for >= 3.0.0."""
    if _parse_version(celix_version_str) >= _VERSION_TO_MANIFEST_FORMAT:
        return "json"
    return "properties"

def get_manifest_version(celix_version_str):
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

def generate_manifest(ctx, private_lib_names = []):
    """Generate the appropriate manifest file for the given rule context.

    Args:
        ctx: Rule context. Must have .attr.celix (CelixRuntimeInfo provider).
        private_lib_names: list of strings — basenames of private libraries,
            used for the Private-Library header.

    Returns:
        struct with fields:
            file: File — the generated manifest (MF or JSON).
            archive_path: string — path inside the zip.
            format: string — 'properties' or 'json'.
    """
    celix_version = ctx.attr.celix[CelixRuntimeInfo].celix_version
    fmt = get_manifest_format(celix_version)

    bundle_name = ctx.attr.bundle_name if getattr(ctx.attr, "bundle_name", None) else ctx.attr.symbolic_name

    if fmt == "json":
        return _generate_manifest_json(ctx, celix_version, bundle_name, private_lib_names)
    return _generate_manifest_properties(ctx, bundle_name, private_lib_names)

def _generate_manifest_properties(ctx, bundle_name, private_lib_names):
    """Generate a META-INF/MANIFEST.MF file with OSGi-style headers."""
    archive_path = "META-INF/MANIFEST.MF"
    manifest = ctx.actions.declare_file("%s.MANIFEST.MF" % ctx.label.name)
    ctx.actions.write(
        output = manifest,
        content = format_manifest_properties(
            symbolic_name = ctx.attr.symbolic_name,
            version = ctx.attr.version,
            bundle_name = bundle_name,
            description = ctx.attr.description,
            group = ctx.attr.group,
            private_lib_names = private_lib_names,
            headers = ctx.attr.headers,
        ),
    )
    return struct(file = manifest, archive_path = archive_path, format = "properties")

def _generate_manifest_json(ctx, celix_version, bundle_name, private_lib_names):
    """Generate a META-INF/MANIFEST.json file with CELIX_BUNDLE_* headers."""
    archive_path = "META-INF/MANIFEST.json"
    manifest = ctx.actions.declare_file("%s.MANIFEST.json" % ctx.label.name)
    manifest_version = get_manifest_version(celix_version)
    ctx.actions.write(
        output = manifest,
        content = format_manifest_json(
            symbolic_name = ctx.attr.symbolic_name,
            version = ctx.attr.version,
            bundle_name = bundle_name,
            manifest_version = manifest_version,
            description = ctx.attr.description,
            group = ctx.attr.group,
            private_lib_names = private_lib_names,
            headers = ctx.attr.headers,
        ),
    )
    return struct(file = manifest, archive_path = archive_path, format = "json")

def _wrap_value_lines(key, value, wrap_col = 72):
    """Wrap a header value to stay within OSGi's 72-column limit.

    The first line keeps the 'Key: ' prefix; continuation lines begin with a
    single space (as the OSGi manifest spec requires). Returns a list of lines.

    Args:
        key: string — the header key (used only for the prefix width).
        value: string — the header value.
        wrap_col: int — maximum line width (default 72 per the spec).

    Returns:
        list of strings: the fully-wrapped header lines.
    """
    if value == "":
        return ["%s:" % key]

    first_prefix = len(key) + 2  # "Key: "
    first_width = wrap_col - first_prefix
    if first_width <= 0:
        # Key is too wide to pack on the first line; emit the value on a
        # continuation line.
        rest = _wrap_into_lines(value, wrap_col - 1, wrap_col - 1)
        return ["%s:" % key] + [" " + l for l in rest]

    lines = _wrap_into_lines(value, first_width, wrap_col - 1)
    out = ["%s: %s" % (key, lines[0])]
    out.extend([" " + l for l in lines[1:]])
    return out

def _wrap_into_lines(remaining, width, continuation_width):
    """Split a header value into wrapped line chunks.

    Starlark forbids recursion and `while` loops, so the chunking runs as a
    bounded iteration over `range`. The first chunk uses `width`; subsequent
    chunks use `continuation_width`, preserving OSGi's 72-column shape.

    Args:
        remaining: string — the value portion still to place.
        width: int — characters available for the current line (already
            accounts for any leading-space column on continuation lines).
        continuation_width: int — characters available for each subsequent line.

    Returns:
        list of strings: value chunks, one per emitted line.
    """
    lines = []
    if remaining == "":
        return lines
    lines.append(remaining[:width])
    remaining = remaining[width:]
    count = len(remaining)
    if count == 0:
        return lines
    chunks = (count - 1) // continuation_width + 1
    for _ in range(chunks):
        lines.append(remaining[:continuation_width])
        remaining = remaining[continuation_width:]
    return lines

def format_manifest_properties(symbolic_name, version, bundle_name, description, group, private_lib_names, headers):
    """Format manifest headers into the MANIFEST.MF text (OSGi properties).

    Args:
        symbolic_name: Bundle-SymbolicName.
        version: Bundle-Version.
        bundle_name: Bundle-Name (human readable).
        description: Bundle-Description (emitted only when non-empty).
        group: Bundle-Group (emitted only when non-empty).
        private_lib_names: list of basenames for the Private-Library header.
        headers: dict of custom header key/value pairs.

    Returns:
        string: MANIFEST.MF content.
    """
    body = [
        "Manifest-Version: 1.0",
        "Bundle-Name: %s" % bundle_name,
        "Bundle-SymbolicName: %s" % symbolic_name,
        "Bundle-Version: %s" % version,
    ]
    if description:
        body.extend(_wrap_value_lines("Bundle-Description", description))
    if group:
        body.extend(_wrap_value_lines("Bundle-Group", group))
    if private_lib_names:
        body.extend(_wrap_value_lines("Private-Library", " ".join(private_lib_names)))
    for key in headers:
        body.extend(_wrap_value_lines(key, headers[key]))
    return "\n".join(body) + "\n"

def _json_string(value):
    """Serialize a string as a JSON string literal.

    Applies minimal escaping for quotes, backslashes and whitespace. Control
    characters that cannot be safely represented are rejected.

    Args:
        value: string to serialize.

    Returns:
        string: a JSON string literal (including surrounding quotes).
    """
    out = '"'
    for ch in value.elems():
        if ch == '"':
            out += '\\"'
        elif ch == "\\":
            out += "\\\\"
        elif ch == "\n":
            out += "\\n"
        elif ch == "\r":
            out += "\\r"
        elif ch == "\t":
            out += "\\t"
        elif ch < " ":
            fail("Cannot serialize control character in JSON manifest header value")
        else:
            out += ch
    return out + '"'

def format_manifest_json(symbolic_name, version, bundle_name, manifest_version, description, group, private_lib_names, headers):
    """Format manifest headers into the MANIFEST.json text (Celix 3.x JSON).

    Builds an ordered list of (key, value) pairs and joins them once, avoiding
    fragile trailing-comma handling.

    Args:
        symbolic_name: Bundle symbolic name.
        version: Bundle version.
        bundle_name: Bundle display name.
        manifest_version: CELIX_BUNDLE_MANIFEST_VERSION value.
        description: Bundle description (emitted only when non-empty).
        group: Bundle group (emitted only when non-empty).
        private_lib_names: list of basenames for the private-libraries header.
        headers: dict of custom header key/value pairs.

    Returns:
        string: MANIFEST.json content.
    """
    pairs = [
        ("CELIX_BUNDLE_SYMBOLIC_NAME", symbolic_name),
        ("CELIX_BUNDLE_NAME", bundle_name),
        ("CELIX_BUNDLE_VERSION", version),
    ]
    if manifest_version:
        pairs.append(("CELIX_BUNDLE_MANIFEST_VERSION", manifest_version))
    if description:
        pairs.append(("CELIX_BUNDLE_DESCRIPTION", description))
    if group:
        pairs.append(("CELIX_BUNDLE_GROUP", group))
    if private_lib_names:
        pairs.append(("CELIX_BUNDLE_PRIVATE_LIBRARIES", " ".join(private_lib_names)))
    for key in headers:
        pairs.append((key, headers[key]))

    lines = ["{"]
    for i in range(len(pairs)):
        key, value = pairs[i]
        comma = "," if i < len(pairs) - 1 else ""
        lines.append("  %s: %s%s" % (_json_string(key), _json_string(value), comma))
    lines.append("}")
    return "\n".join(lines) + "\n"
