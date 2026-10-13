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

"""Unit tests for celix_zip's nested-resource directory entry emission.

A resource mapped to a nested destination (e.g. tests/testdata/configs/nested.txt)
is uninstallable by Celix's bundle extractor unless every ancestor directory
(tests/, tests/testdata/, tests/testdata/configs/) is present as an explicit
directory entry.  These tests pin that behaviour on the tool side: the assembly
path emits the parent directories, and the shared validator rejects bundles
whose file entries lack them.
"""

import os
import sys
import tempfile
import zipfile

from tools import celix_zip

NESTED_DIRS = [
    "tests/",
    "tests/testdata/",
    "tests/testdata/configs/",
]


def fail(msg):
    """Print a failure message and exit non-zero."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def assemble_bundle(output_zip, manifest_text, resources):
    """Drive celix_zip's real assembly path to build a bundle zip.

    Args:
        output_zip: path of the zip to produce.
        manifest_text: manifest content to write.
        resources: list of (archive_path, content) resource files.
    """
    with tempfile.TemporaryDirectory() as tmp:
        manifest = os.path.join(tmp, "MANIFEST.MF")
        with open(manifest, "w") as fh:
            fh.write(manifest_text)

        args = [
            "--manifest",
            manifest,
            "--manifest-path",
            "META-INF/MANIFEST.MF",
            "--output",
            output_zip,
        ]
        for (archive_path, content) in resources:
            src = os.path.join(tmp, os.path.basename(archive_path))
            with open(src, "w") as fh:
                fh.write(content)
            args += [
                "--add",
                src,
                "--dest",
                archive_path,
                "--mode",
                "0644",
            ]

        old_argv = sys.argv
        sys.argv = ["celix_zip"] + args
        try:
            celix_zip.main()
        finally:
            sys.argv = old_argv


def test_nested_resources_emit_parent_directory_entries():
    with tempfile.TemporaryDirectory() as tmp:
        output_zip = os.path.join(tmp, "nested.zip")
        assemble_bundle(
            output_zip,
            "Manifest-Version: 1.0\n"
            "Bundle-SymbolicName: com.example.nested\n"
            "Bundle-Version: 1.0.0\n",
            [
                ("tests/testdata/config.txt", "config\n"),
                ("tests/testdata/configs/nested.txt", "nested\n"),
            ],
        )

        error = celix_zip.validate_bundle_zip(output_zip)
        if error:
            fail("Assembled bundle with nested resources should be valid, got: %s" % error)

        with zipfile.ZipFile(output_zip) as zf:
            names = zf.namelist()
            for directory in NESTED_DIRS:
                if directory not in names:
                    fail("Bundle zip is missing directory entry '%s'; got entries: %s" % (directory, names))

            file_entries = [e for e in zf.infolist() if not e.filename.endswith("/")]
            if file_entries[0].filename != "META-INF/MANIFEST.MF":
                fail("Manifest must stay the first file entry, got '%s'" % file_entries[0].filename)


def test_missing_parent_directories_are_rejected():
    with tempfile.TemporaryDirectory() as tmp:
        output_zip = os.path.join(tmp, "missing_dirs.zip")
        with zipfile.ZipFile(output_zip, "w") as zf:
            for name in ("META-INF/", "tests/", "tests/testdata/"):
                info = zipfile.ZipInfo(name)
                info.date_time = celix_zip.ZIP_EPOCH
                info.create_system = 3
                info.external_attr = (0o755 | 0o040000) << 16
                zf.writestr(info, "")
            info = zipfile.ZipInfo("META-INF/MANIFEST.MF")
            info.date_time = celix_zip.ZIP_EPOCH
            info.external_attr = 0o644 << 16
            zf.writestr(info, "Manifest-Version: 1.0\n")
            info = zipfile.ZipInfo("tests/testdata/configs/nested.txt")
            info.date_time = celix_zip.ZIP_EPOCH
            info.external_attr = 0o644 << 16
            zf.writestr(info, "nested\n")

        error = celix_zip.validate_bundle_zip(output_zip)
        if error is None:
            fail("Zip with nested file but no parent directory entries must be rejected")
        if "tests/testdata/configs/" not in error:
            fail("Rejection must name the missing directory, got: %s" % error)


if __name__ == "__main__":
    test_nested_resources_emit_parent_directory_entries()
    test_missing_parent_directories_are_rejected()
    print("PASS: celix_zip nested-resource directory entry tests.")