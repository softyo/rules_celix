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

"""Hermetic byte-for-byte file copy tool.

Copies files without any host shell dependency, so Bazel actions stay hermetic
and deterministic across the supported platforms (Linux / macOS).  The tool
copies file contents plus mode bits (`shutil.copy2`), so copied executables
stay executable.  It deliberately performs no format-specific validation,
because callers have their own contracts (e.g. `celix_zip.py --copy` validates
bundle zips; this tool serves copies of plain binaries like the container
runner).

Usage:

    file_copy.py <src> <dest> [<src> <dest>] ...
"""

import os
import shutil
import sys


def die(msg):
    """Print an error message and exit non-zero."""
    print("ERROR: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    args = sys.argv[1:]
    if not args or len(args) % 2 != 0:
        die("Usage: file_copy.py <src> <dest> [<src> <dest>] ...")

    for i in range(0, len(args), 2):
        src = args[i]
        dest = args[i + 1]
        if not os.path.isfile(src):
            die("Copy source not found: %s" % src)
        try:
            shutil.copy2(src, dest)
        except OSError as e:
            die("Failed to copy '%s' to '%s': %s" % (src, dest, e))


if __name__ == "__main__":
    main()