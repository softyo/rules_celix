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

import json
import sys
import zipfile

# The ZIP epoch used by rules_celix's celix_zip (also used by rules_pkg).
# Jan 1, 1980 00:00 UTC — the minimum valid date in the ZIP format.
ZIP_EPOCH = (1980, 1, 1, 0, 0, 0)


def fail(msg):
    """Print a failure message and exit non-zero."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def validate_properties_manifest(zf, entries, expected_name, expected_version, expected_bundle_name,
                                 expected_description, expected_group, expected_private_libs,
                                 expected_headers):
    """Validate an OSGi properties-style META-INF/MANIFEST.MF."""
    first = entries[0].filename
    if first != "META-INF/MANIFEST.MF":
        fail("First zip entry must be 'META-INF/MANIFEST.MF', got '%s'" % first)

    manifest_text = zf.read("META-INF/MANIFEST.MF").decode("utf-8")
    headers = {}
    continuation = None
    for line in manifest_text.splitlines():
        if line.startswith(" "):
            # OSGi continuation line — append to the previous header's value.
            if continuation is not None:
                headers[continuation] += line.strip()
            continue
        if ":" in line:
            key, _, value = line.partition(":")
            headers[key.strip()] = value.strip()
            continuation = key.strip()

    if headers.get("Manifest-Version") != "1.0":
        fail("Manifest-Version should be '1.0', got '%s'" % headers.get("Manifest-Version"))

    if headers.get("Bundle-SymbolicName") != expected_name:
        fail("Bundle-SymbolicName mismatch: expected '%s', got '%s'" %
             (expected_name, headers.get("Bundle-SymbolicName")))

    if headers.get("Bundle-Version") != expected_version:
        fail("Bundle-Version mismatch: expected '%s', got '%s'" %
             (expected_version, headers.get("Bundle-Version")))

    if headers.get("Bundle-Name") != expected_bundle_name:
        fail("Bundle-Name mismatch: expected '%s', got '%s'" %
             (expected_bundle_name, headers.get("Bundle-Name")))

    if expected_description is not None and headers.get("Bundle-Description") != expected_description:
        fail("Bundle-Description mismatch: expected '%s', got '%s'" %
             (expected_description, headers.get("Bundle-Description")))

    if expected_group is not None and headers.get("Bundle-Group") != expected_group:
        fail("Bundle-Group mismatch: expected '%s', got '%s'" %
             (expected_group, headers.get("Bundle-Group")))

    if expected_private_libs:
        joined = " ".join(expected_private_libs)
        if headers.get("Private-Library") != joined:
            fail("Private-Library mismatch: expected '%s', got '%s'" %
                 (joined, headers.get("Private-Library")))

    for key, value in expected_headers.items():
        if headers.get(key) != value:
            fail("Header '%s' mismatch: expected '%s', got '%s'" %
                 (key, value, headers.get(key)))

    return headers


def validate_json_manifest(zf, entries, expected_name, expected_version, expected_bundle_name,
                           expected_description, expected_group, expected_private_libs,
                           expected_headers):
    """Validate a Celix 3.x JSON-style META-INF/MANIFEST.json."""
    first = entries[0].filename
    if first != "META-INF/MANIFEST.json":
        fail("First zip entry must be 'META-INF/MANIFEST.json', got '%s'" % first)

    manifest_text = zf.read("META-INF/MANIFEST.json").decode("utf-8")
    try:
        data = json.loads(manifest_text)
    except json.JSONDecodeError as e:
        fail("Invalid JSON manifest: %s" % e)

    if data.get("CELIX_BUNDLE_SYMBOLIC_NAME") != expected_name:
        fail("CELIX_BUNDLE_SYMBOLIC_NAME mismatch: expected '%s', got '%s'" %
             (expected_name, data.get("CELIX_BUNDLE_SYMBOLIC_NAME")))

    if data.get("CELIX_BUNDLE_VERSION") != expected_version:
        fail("CELIX_BUNDLE_VERSION mismatch: expected '%s', got '%s'" %
             (expected_version, data.get("CELIX_BUNDLE_VERSION")))

    if data.get("CELIX_BUNDLE_NAME") != expected_bundle_name:
        fail("CELIX_BUNDLE_NAME mismatch: expected '%s', got '%s'" %
             (expected_bundle_name, data.get("CELIX_BUNDLE_NAME")))

    if "CELIX_BUNDLE_MANIFEST_VERSION" not in data:
        fail("Missing CELIX_BUNDLE_MANIFEST_VERSION in JSON manifest")

    if expected_description is not None and data.get("CELIX_BUNDLE_DESCRIPTION") != expected_description:
        fail("CELIX_BUNDLE_DESCRIPTION mismatch: expected '%s', got '%s'" %
             (expected_description, data.get("CELIX_BUNDLE_DESCRIPTION")))

    if expected_group is not None and data.get("CELIX_BUNDLE_GROUP") != expected_group:
        fail("CELIX_BUNDLE_GROUP mismatch: expected '%s', got '%s'" %
             (expected_group, data.get("CELIX_BUNDLE_GROUP")))

    if expected_private_libs:
        joined = " ".join(expected_private_libs)
        if data.get("CELIX_BUNDLE_PRIVATE_LIBRARIES") != joined:
            fail("CELIX_BUNDLE_PRIVATE_LIBRARIES mismatch: expected '%s', got '%s'" %
                 (joined, data.get("CELIX_BUNDLE_PRIVATE_LIBRARIES")))

    for key, value in expected_headers.items():
        if data.get(key) != value:
            fail("JSON header '%s' mismatch: expected '%s', got '%s'" %
                 (key, value, data.get(key)))

    return data


def _collect_value(tokens, i):
    """Collect one or more tokens into a single value until the next flag.

    Bazel joins a test's `args` with spaces before invoking the binary, so a
    single arg like "My Test Bundle" arrives as three tokens. This re-joins
    consecutive non-flag tokens so multi-word values (descriptions, header
    values) survive intact.

    Args:
        tokens: list of argument tokens.
        i: index to start collecting from.

    Returns:
        tuple (value, next_index): the collected value string and the index of
        the first token not consumed (or len(tokens)).
    """
    parts = []
    while i < len(tokens) and not tokens[i].startswith("--"):
        parts.append(tokens[i])
        i += 1
    return " ".join(parts), i


def main():
    if len(sys.argv) < 4:
        fail(
            "Usage: validate_bundle.py <bundle.zip> <expected_symbolic_name> "
            "<expected_version> [<expected_bundle_name>] --format <properties|json> "
            "[--description <value>] [--group <value>] "
            "[--private-lib <basename>]... [--resource <archive_path>]... "
            "[--header <key> <value>]... [--no-activator]"
        )

    bundle_path = sys.argv[1]
    expected_name = sys.argv[2]
    expected_version = sys.argv[3]
    rest = sys.argv[4:]

    fmt = "properties"
    positional = []
    expected_description = None
    expected_group = None
    private_libs = []
    resources = []
    expected_headers = {}
    no_activator = False

    i = 0
    while i < len(rest):
        a = rest[i]
        if a == "--format":
            fmt = rest[i + 1] if i + 1 < len(rest) else ""
            i += 2
        elif a == "--description":
            expected_description, i = _collect_value(rest, i + 1)
        elif a == "--group":
            expected_group, i = _collect_value(rest, i + 1)
        elif a == "--private-lib":
            private_libs.append(rest[i + 1] if i + 1 < len(rest) else "")
            i += 2
        elif a == "--resource":
            resources.append(rest[i + 1] if i + 1 < len(rest) else "")
            i += 2
        elif a == "--header":
            key = rest[i + 1] if i + 1 < len(rest) else None
            value, i = _collect_value(rest, i + 2)
            if key is None:
                fail("Missing value for --header")
            expected_headers[key] = value
        elif a == "--no-activator":
            no_activator = True
            i += 1
        elif a.startswith("--"):
            fail("Unknown argument: %s" % a)
        else:
            positional.append(a)
            i += 1

    if fmt not in ("properties", "json"):
        fail("Unknown format '%s'. Expected 'properties' or 'json'." % fmt)

    expected_bundle_name = " ".join(positional) if positional else expected_name

    # 1. Validate it's a valid zip.
    try:
        zf = zipfile.ZipFile(bundle_path, "r")
    except Exception as e:
        fail("Not a valid zip file: %s" % e)

    try:
        entries = zf.infolist()

        if len(entries) < 1:
            fail("Expected at least one entry (the manifest), got %d" % len(entries))

        # 2. Verify all entries use the deterministic ZIP epoch.
        for entry in entries:
            if entry.date_time != ZIP_EPOCH:
                fail(
                    "Entry '%s' has non-deterministic timestamp %s. "
                    "Expected %s (ZIP epoch)." %
                    (entry.filename, entry.date_time, ZIP_EPOCH)
                )

        # 3. Validate manifest content by format.
        if fmt == "json":
            validate_json_manifest(
                zf, entries, expected_name, expected_version, expected_bundle_name,
                expected_description, expected_group, private_libs, expected_headers,
            )
        else:
            validate_properties_manifest(
                zf, entries, expected_name, expected_version, expected_bundle_name,
                expected_description, expected_group, private_libs, expected_headers,
            )

        archive_names = [e.filename for e in entries]

        # 4. Check requested private libraries and resources are present.
        for lib in private_libs:
            if lib not in archive_names:
                fail("Expected private library entry '%s' not found in zip" % lib)
        for res in resources:
            if res not in archive_names:
                fail("Expected resource entry '%s' not found in zip" % res)

        # 5. Validate the shared-library entries.
        if no_activator:
            # Manifests live under META-INF/; there should be no root-level shared library.
            missing_libs = [
                e for e in entries
                if e.filename.startswith("lib") and e.filename.endswith((".so", ".dylib", ".dll"))
            ]
            if missing_libs:
                fail("no_activator bundle must not contain a top-level shared library, got: %s" %
                     [e.filename for e in missing_libs])
        else:
            if len(entries) < 2:
                fail("Expected at least 2 entries (manifest + library), got %d" % len(entries))
            lib_entry = entries[1].filename
            if not lib_entry.endswith((".so", ".dylib", ".dll")):
                fail("Second entry should be a shared library, got '%s'" % lib_entry)
            # Sanity check: the library name should follow the lib*.so convention.
            if not (lib_entry.startswith("lib") and
                    any(lib_entry.endswith(ext) for ext in (".so", ".dylib", ".dll"))):
                print("WARNING: library entry '%s' doesn't follow expected naming convention" % lib_entry,
                      file=sys.stderr)

    finally:
        zf.close()

    print("PASS: Bundle zip is valid, manifest (%s) correct, entries ordered correctly, timestamps deterministic." % fmt)


if __name__ == "__main__":
    main()
