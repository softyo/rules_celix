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


def validate_properties_manifest(zf, entries, expected_name, expected_version, expected_bundle_name):
    """Validate an OSGi properties-style META-INF/MANIFEST.MF."""
    first = entries[0].filename
    if first != "META-INF/MANIFEST.MF":
        fail("First zip entry must be 'META-INF/MANIFEST.MF', got '%s'" % first)

    manifest_text = zf.read("META-INF/MANIFEST.MF").decode("utf-8")
    headers = {}
    for line in manifest_text.splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            headers[key.strip()] = value.strip()

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


def validate_json_manifest(zf, entries, expected_name, expected_version, expected_bundle_name):
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


def main():
    if len(sys.argv) < 5:
        fail(
            "Usage: validate_bundle.py <bundle.zip> <expected_symbolic_name> "
            "<expected_version> --format <properties|json> [<expected_bundle_name>]"
        )

    bundle_path = sys.argv[1]
    expected_name = sys.argv[2]
    expected_version = sys.argv[3]

    # Parse --format flag and optional bundle name from remaining args.
    fmt = "properties"  # default
    remaining = sys.argv[4:]
    if "--format" in remaining:
        idx = remaining.index("--format")
        fmt = remaining[idx + 1] if idx + 1 < len(remaining) else fmt
        remaining = remaining[:idx] + remaining[idx + 2:]

    if fmt not in ("properties", "json"):
        fail("Unknown format '%s'. Expected 'properties' or 'json'." % fmt)

    expected_bundle_name = " ".join(remaining) if remaining else expected_name

    # 1. Validate it's a valid zip.
    try:
        zf = zipfile.ZipFile(bundle_path, "r")
    except Exception as e:
        fail("Not a valid zip file: %s" % e)

    try:
        entries = zf.infolist()

        if len(entries) < 2:
            fail("Expected at least 2 entries (manifest + library), got %d" % len(entries))

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
            validate_json_manifest(zf, entries, expected_name, expected_version, expected_bundle_name)
        else:
            validate_properties_manifest(zf, entries, expected_name, expected_version, expected_bundle_name)

        # 4. Check library entry exists with a valid shared library extension.
        lib_entry = entries[1].filename
        if not lib_entry.endswith((".so", ".dylib", ".dll")):
            fail("Second entry should be a shared library, got '%s'" % lib_entry)

        # 5. Sanity check: the library name should follow the lib*.so convention.
        if not (lib_entry.startswith("lib") and any(lib_entry.endswith(ext) for ext in (".so", ".dylib", ".dll"))):
            print("WARNING: library entry '%s' doesn't follow expected naming convention" % lib_entry,
                  file=sys.stderr)

    finally:
        zf.close()

    print("PASS: Bundle zip is valid, manifest (%s) correct, entries ordered correctly, timestamps deterministic." % fmt)


if __name__ == "__main__":
    main()
