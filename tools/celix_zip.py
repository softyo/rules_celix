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

Creates a deterministic .zip archive with the manifest as the first *file*
entry (preceded by its explicit parent-directory entry, which Celix's bundle
extractor requires), following Apache Celix bundle conventions.

Why not rules_pkg?
------------------
rules_pkg's pkg_zip is the standard Bazel way to create zip archives, and it
already handles deterministic timestamps.  However, pkg_zip sorts entries
alphabetically by destination path (see _load_manifest in build_zip.py).
Celix requires the manifest to be the *first* file entry in the zip.
Since "M" sorts after "l" (for "lib*.so"), pkg_zip would place the library
before the manifest, producing an invalid Celix bundle.  rules_pkg is
therefore deliberately NOT a dependency of this ruleset; this tool replaces
it for the packaging step.

We use a small custom tool instead so we can explicitly control entry order
while still producing a deterministic (fixed-timestamp) zip.  The timestamp
used (315532800 = 1980-01-01) is the same ZIP epoch used by rules_pkg and
the broader reproducible-builds community.

The tool has two independent modes:

1. Bundle assembly (--manifest mode):
    celix_zip.py \
        --manifest <manifest_path> \
        --manifest-path <manifest_archive_path> \
        --output <output_zip_path> \
        [--add <src> --dest <archive_path> --mode <octal_mode>] ...

2. Copy mode (--copy), used by celix_container to materialize each bundle
   zip as a real standalone file under bundles/.  Bytes are copied verbatim
   (no re-compression), so determinism is inherited from the source bundle;
   every copied file is then verified to be a valid deterministic Celix
   bundle zip (manifest first, entries at the fixed ZIP epoch).
    celix_zip.py --copy <src_zip> <dest_zip> [--copy <src_zip> <dest_zip>] ...

The two modes are mutually exclusive.
"""

import os
import shutil
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


def _add_directory(zf, archive_path, permissions):
    """Add an explicit directory entry to the zip with a deterministic header.

    Celix's bundle extractor (`celix_utils_extractZipInternal`) creates only
    the final extraction directory and then opens each file at
    `<extract>/<entry name>` — it does *not* create intermediate directories
    for entries like `META-INF/MANIFEST.MF`.  The upstream CMake-packaged
    bundles therefore always include an explicit `META-INF/` directory entry,
    and our zips must too, or `fopen` fails with ENOENT when the framework
    installs the bundle.

    Args:
        zf: The open ZipFile (write mode).
        archive_path: Directory path inside the zip, with a trailing '/'.
        permissions: Unix permission bits (stored in the high 16 bits of the
            ZIP external_attr field, with the S_IFDIR type flag set).
    """
    info = zipfile.ZipInfo(archive_path)
    info.date_time = ZIP_EPOCH
    # S_IFDIR (0o040000) marks a directory; makedirs/extract honors it.
    info.create_system = 3
    info.external_attr = (permissions | 0o040000) << 16
    zf.writestr(info, "")


def _manifest_directory(archive_path):
    """Return the directory entry prefix for the given manifest archive path.

    The manifest lives under a directory (e.g. `META-INF/`); Celix requires
    that directory to exist as an explicit zip entry before any file inside it.

    Args:
        archive_path: the manifest's archive path (e.g. `META-INF/MANIFEST.MF`).

    Returns:
        string: the containing directory with a trailing `/`, or "" for a
            top-level manifest.
    """
    idx = archive_path.rfind("/")
    if idx == -1:
        return ""
    return archive_path[:idx + 1]


def _parse_args(args):
    """Parse the --manifest/--manifest-path/--output --add and --copy flags.

    The bundle-assembly flags (--manifest/--manifest-path/--output/--add) and
    the --copy pairs are mutually exclusive modes.

    Returns:
        tuple (manifest_path, manifest_archive_path, output_zip_path, entries,
        copies) where entries is a list of (src, dest, mode_int) and copies is
        a list of (src, dest) file pairs.
    """
    manifest_path = None
    manifest_archive_path = None
    output_zip_path = None
    entries = []
    copies = []

    i = 0
    while i < len(args):
        a = args[i]
        if a == "--copy":
            src = _value(args, i, a)
            dest = _value(args, i + 1, a)
            copies.append((src, dest))
            i += 3
        elif a == "--manifest":
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

    if copies:
        if entries or manifest_path or manifest_archive_path or output_zip_path is not None:
            die("--copy cannot be mixed with --manifest/--manifest-path/--output/--add")
        return None, None, None, [], copies

    if manifest_path is None:
        die("Missing required --manifest argument")
    if manifest_archive_path is None:
        die("Missing required --manifest-path argument")
    if output_zip_path is None:
        die("Missing required --output argument")

    return manifest_path, manifest_archive_path, output_zip_path, entries, []


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


def _check_bundle_zip(path):
    """Verify a copied file is a valid deterministic Celix bundle zip.

    Fails loudly if the file is not a zip, lacks a manifest as the first entry,
    or contains any entry outside the fixed ZIP epoch.  This is the contract
    enforcement for celix_container: it only accepts bundles produced by the
    hermetic celix_zip --manifest path.  Delegates to validate_bundle_zip so
    consumers (e.g. integration tests) share the same contract.
    """
    error = validate_bundle_zip(path)
    if error:
        die(error)


def validate_bundle_zip(path):
    """Return None if path is a valid deterministic Celix bundle zip, else an error string.

    Validates that path is a zip archive whose manifest is the first *file*
    entry (an explicit directory entry for the manifest's parent, e.g.
    `META-INF/`, may precede it) and whose entries all carry the fixed ZIP
    epoch.  This is the shared bundle-validity contract for both the copy
    execution path and consumers such as the container integration tests.

    Args:
        path: string path to the zip file.

    Returns:
        string error message, or None when the file is valid.
    """
    if not os.path.isfile(path):
        return "Copied file not found: %s" % path
    try:
        zf = zipfile.ZipFile(path)
    except zipfile.BadZipFile as e:
        return "Not a valid zip archive: %s (%s)" % (path, e)
    try:
        entries = zf.infolist()
        if not entries:
            return "Empty zip archive: %s" % path

        manifest_names = ("META-INF/MANIFEST.MF", "META-INF/MANIFEST.json")
        file_entries = [e for e in entries if not e.filename.endswith("/")]
        if not file_entries:
            return "Zip archive has no file entries: %s" % path
        first_file = file_entries[0].filename
        if first_file not in manifest_names:
            return "First file entry of %s must be the manifest, got '%s'" % (path, first_file)

        # Celix's extractor creates only the extraction root directory; any
        # manifest under a subdirectory (e.g. META-INF/) needs an explicit
        # directory entry so files inside it can be written.
        parent = first_file.rsplit("/", 1)[0] + "/"
        dir_names = {e.filename for e in entries if e.filename.endswith("/")}
        if parent not in dir_names:
            return "Zip archive %s is missing the required directory entry '%s'" % (path, parent)

        for entry in entries:
            if entry.date_time != ZIP_EPOCH:
                return "Entry '%s' of %s has non-deterministic timestamp %s" % (
                    entry.filename,
                    path,
                    entry.date_time,
                )
    finally:
        zf.close()
    return None


def run_copies(copies):
    """Copy each (src, dest) pair byte-for-byte and verify the result.

    Args:
        copies: list of (src, dest) file pairs.
    """
    for (src, dest) in copies:
        if not os.path.isfile(src):
            die("Copy source not found: %s" % src)
    for (src, dest) in copies:
        try:
            shutil.copyfile(src, dest)
        except OSError as e:
            die("Failed to copy '%s' to '%s': %s" % (src, dest, e))
        _check_bundle_zip(dest)


def main():
    manifest_path, manifest_archive_path, output_zip_path, entries, copies = _parse_args(sys.argv[1:])

    if copies:
        run_copies(copies)
        return

    if not os.path.isfile(manifest_path):
        die("Manifest file not found: %s" % manifest_path)
    for (src, _, _) in entries:
        if not os.path.isfile(src):
            die("Entry file not found: %s" % src)

    _check_collisions(manifest_archive_path, entries)

    try:
        with zipfile.ZipFile(output_zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            # Celix requires the manifest to be the first entry, and the
            # bundle extractor requires its parent directory to exist as an
            # explicit entry.  The directory entry is emitted before the
            # manifest so the manifest keeps its first-file position.
            # zipfile.ZipFile writes entries in order of addition, so this
            # deterministic ordering is guaranteed.
            manifest_dir = _manifest_directory(manifest_archive_path)
            if manifest_dir:
                _add_directory(zf, manifest_dir, 0o755)

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
