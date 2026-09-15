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
before the manifest, producing an invalid Celix bundle.  rules_pkg is
therefore deliberately NOT a dependency of this ruleset; this tool replaces
it for the packaging step.

We use a small custom tool instead so we can explicitly control entry order
while still producing a deterministic (fixed-timestamp) zip.  The timestamp
used (315532800 = 1980-01-01) is the same ZIP epoch used by rules_pkg and
the broader reproducible-builds community.

Usage:
    celix_zip.py \
        --manifest <manifest_path> \
        --manifest-path <manifest_archive_path> \
        --output <output_zip_path> \
        [--add <src> --dest <archive_path> --mode <octal_mode>] ...
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


def _value(args, i, flag):
    """Return the value following a flag, dying on a missing value."""
    if i + 1 >= len(args):
        die("Missing value for %s" % flag)
    return args[i + 1]


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


def _parse_args(args):
    """Parse the --manifest/--manifest-path/--output and repeated --add flags.

    Returns:
        tuple (manifest_path, manifest_archive_path, output_zip_path, entries)
        where entries is a list of (src, dest, mode_int).
    """
    manifest_path = None
    manifest_archive_path = None
    output_zip_path = None
    entries = []

    i = 0
    while i < len(args):
        a = args[i]
        if a == "--manifest":
            manifest_path = _value(args, i, a)
            i += 2
        elif a == "--manifest-path":
            manifest_archive_path = _value(args, i, a)
            i += 2
        elif a == "--output":
            output_zip_path = _value(args, i, a)
            i += 2
        elif a == "--add":
            if i + 5 >= len(args) or args[i + 2] != "--dest" or args[i + 4] != "--mode":
                die("Expected '--add <src> --dest <dest> --mode <mode>'")
            src = args[i + 1]
            dest = args[i + 3]
            mode_str = args[i + 5]
            try:
                mode = int(mode_str, 8)
            except ValueError:
                die("Invalid octal mode '%s' for entry '%s'" % (mode_str, dest))
            entries.append((src, dest, mode))
            i += 6
        else:
            die("Unknown argument: %s" % a)

    if manifest_path is None:
        die("Missing required --manifest argument")
    if manifest_archive_path is None:
        die("Missing required --manifest-path argument")
    if output_zip_path is None:
        die("Missing required --output argument")

    return manifest_path, manifest_archive_path, output_zip_path, entries


def _check_collisions(manifest_archive_path, entries):
    """Fail if any two entries would map to the same archive path.

    Duplicate archive paths would silently overwrite earlier entries when
    written to a zipfile, yielding ambiguous, non-deterministic output, so they
    are rejected outright.
    """
    seen = set([manifest_archive_path])
    for (_, dest, _) in entries:
        if dest in seen:
            die("Duplicate archive entry path: %s" % dest)
        seen.add(dest)


def main():
    manifest_path, manifest_archive_path, output_zip_path, entries = _parse_args(sys.argv[1:])

    if not os.path.isfile(manifest_path):
        die("Manifest file not found: %s" % manifest_path)
    for (src, _, _) in entries:
        if not os.path.isfile(src):
            die("Entry file not found: %s" % src)

    _check_collisions(manifest_archive_path, entries)

    try:
        with zipfile.ZipFile(output_zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            # Celix requires the manifest to be the first entry.
            # zipfile.ZipFile writes entries in order of addition, so this
            # deterministic ordering is guaranteed.
            _add_file(zf, manifest_path, manifest_archive_path, 0o644)

            # Then write the rest in the exact order given.
            for (src, dest, mode) in entries:
                _add_file(zf, src, dest, mode)
    except zipfile.BadZipFile as e:
        die("Failed to create zip archive: %s" % e)
    except OSError as e:
        die("I/O error while creating zip: %s" % e)


if __name__ == "__main__":
    main()
