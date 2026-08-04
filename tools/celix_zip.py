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

"""Hermetic zip packaging tool for Celix bundles.

Creates a deterministic .zip archive with the manifest as the first entry,
following Apache Celix bundle conventions.

Why not rules_pkg?
------------------
rules_pkg's pkg_zip is the standard Bazel way to create zip archives, and it
already handles deterministic timestamps.  However, pkg_zip sorts entries
alphabetically by destination path (see _load_manifest in build_zip.py).
Celix requires the manifest to be the *first* entry in the zip.
Since "M" sorts after "l" (for "lib*.so"), pkg_zip would place the library
before the manifest, producing an invalid Celix bundle.

We use a small custom tool instead so we can explicitly control entry order
while still producing a deterministic (fixed-timestamp) zip.  The timestamp
used (315532800 = 1980-01-01) is the same ZIP epoch used by rules_pkg and
the broader reproducible-builds community.

Usage:
    celix_zip.py <manifest_path> <library_path> <output_zip_path> <manifest_archive_path>
"""

import os
import sys
import zipfile

# ZIP epoch — the minimum valid date in the ZIP format (Jan 1, 1980 00:00 UTC).
# Using a fixed timestamp guarantees bit-for-bit reproducibility across builds.
# This is the same constant used by rules_pkg's build_zip.py.
ZIP_EPOCH = (1980, 1, 1, 0, 0, 0)


def die(msg):
    """Print an error message and exit non-zero."""
    print("ERROR: " + msg, file=sys.stderr)
    sys.exit(1)


def _add_file(zf, file_path, archive_path, permissions):
    """Add a single file to the zip with a deterministic header.

    Uses ZipInfo to set a fixed timestamp and explicit file permissions so
    the output archive is reproducible regardless of when or where the build
    runs.

    Args:
        zf: The open ZipFile (write mode).
        file_path: Path to the file on disk.
        archive_path: Path to store inside the zip.
        permissions: Unix permission bits (will be stored in the high 16 bits
            of the ZIP external_attr field).
    """
    info = zipfile.ZipInfo(archive_path)
    info.date_time = ZIP_EPOCH
    info.external_attr = permissions << 16
    with open(file_path, "rb") as fh:
        zf.writestr(info, fh.read())


def main():
    if len(sys.argv) != 5:
        die(
            "Usage: celix_zip.py <manifest_path> <library_path> "
            "<output_zip_path> <manifest_archive_path>"
        )

    manifest_path = sys.argv[1]
    library_path = sys.argv[2]
    output_zip_path = sys.argv[3]
    manifest_archive_path = sys.argv[4]  # e.g. "META-INF/MANIFEST.MF" or "META-INF/MANIFEST.json"

    # Validate inputs exist
    if not os.path.isfile(manifest_path):
        die("Manifest file not found: %s" % manifest_path)
    if not os.path.isfile(library_path):
        die("Library file not found: %s" % library_path)

    try:
        with zipfile.ZipFile(output_zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            # Celix requires the manifest to be the first entry.
            # zipfile.ZipFile writes entries in order of addition, so this
            # deterministic ordering is guaranteed.
            _add_file(zf, manifest_path, manifest_archive_path, 0o644)

            # Use os.path.basename to handle both Unix and Windows paths.
            library_name = os.path.basename(library_path)
            _add_file(zf, library_path, library_name, 0o755)
    except zipfile.BadZipFile as e:
        die("Failed to create zip archive: %s" % e)
    except OSError as e:
        die("I/O error while creating zip: %s" % e)


if __name__ == "__main__":
    main()
