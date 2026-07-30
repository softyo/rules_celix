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

import sys
import zipfile

# The ZIP epoch used by rules_celix's celix_zip (also used by rules_pkg).
# Jan 1, 1980 00:00 UTC — the minimum valid date in the ZIP format.
ZIP_EPOCH = (1980, 1, 1, 0, 0, 0)


def fail(msg):
    """Print a failure message and exit non-zero."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 4:
        fail("Usage: validate_bundle.py <bundle.zip> <expected_symbolic_name> <expected_version> [<expected_bundle_name>]")

    bundle_path = sys.argv[1]
    expected_name = sys.argv[2]
    expected_version = sys.argv[3]
    # Join any remaining arguments to reconstruct a potentially multi-word bundle name
    # that may have been split during argument passing (e.g. by shell word-splitting).
    expected_bundle_name = " ".join(sys.argv[4:]) if len(sys.argv) > 4 else expected_name

    # 1. Validate it's a valid zip.
    try:
        zf = zipfile.ZipFile(bundle_path, "r")
    except Exception as e:
        fail("Not a valid zip file: %s" % e)

    try:
        entries = zf.infolist()

        if len(entries) < 2:
            fail("Expected at least 2 entries (MANIFEST.MF + library), got %d" % len(entries))

        # 2. First entry MUST be META-INF/MANIFEST.MF (Celix requirement).
        first = entries[0].filename
        if first != "META-INF/MANIFEST.MF":
            fail("First zip entry must be 'META-INF/MANIFEST.MF', got '%s'" % first)

        # 3. Verify all entries use the deterministic ZIP epoch.
        for entry in entries:
            if entry.date_time != ZIP_EPOCH:
                fail(
                    "Entry '%s' has non-deterministic timestamp %s. "
                    "Expected %s (ZIP epoch)." %
                    (entry.filename, entry.date_time, ZIP_EPOCH)
                )

        # 4. Parse manifest content and verify headers.
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

        # 5. Check library entry exists with a valid shared library extension.
        lib_entry = entries[1].filename
        if not lib_entry.endswith((".so", ".dylib", ".dll")):
            fail("Second entry should be a shared library, got '%s'" % lib_entry)

        # 6. Sanity check: the library name should follow the lib*.so convention.
        if not (lib_entry.startswith("lib") and any(lib_entry.endswith(ext) for ext in (".so", ".dylib", ".dll"))):
            print("WARNING: library entry '%s' doesn't follow expected naming convention" % lib_entry,
                  file=sys.stderr)

    finally:
        zf.close()

    print("PASS: Bundle zip is valid, manifest correct, entries ordered correctly, timestamps deterministic.")


if __name__ == "__main__":
    main()
