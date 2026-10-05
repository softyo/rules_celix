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

"""Build-time validation of a celix_container's deployable contents.

Asserts that a container's bundle zips are laid out at
`bundles/<symbolic_name>.zip` and are byte-identical to their source bundle
zips.  The byte-identity check proves the container keeps real standalone
files (a faithful copy) rather than symlinks or a re-zip.  The zip validity
contract (manifest-first, fixed ZIP epoch) is enforced by the celix_zip tool
itself at build time and shared via `validate_bundle_zip`.

Bazel runs this py_test with CWD at the runfiles root, so `$(rootpath ...)`
paths resolve directly, exactly like validate_bundle.py.  The container and
its bundles are expected to share a package (dirname of each source bundle
rootpath), which is where the container's bundles/ directory lands.

Usage:
    validate_container.py --bundle <source_bundle_rootpath> <symbolic_name> ...
"""

import os
import sys

from tools import celix_zip

# The ZIP epoch used by rules_celix's celix_zip (also used by rules_pkg).
# Jan 1, 1980 00:00 UTC — shared with the tool that produces the zips.
ZIP_EPOCH = celix_zip.ZIP_EPOCH


def fail(msg):
    """Print a failure message and exit non-zero."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def check_container_bundle(source_bundle, symbolic_name):
    """Validate one bundle laid out in the container.

    Args:
        source_bundle: the source bundle zip rootpath (resolved relative to the
            runfiles root, which is also the test CWD).
        symbolic_name: the bundle's Bundle-SymbolicName; the container path is
            <package dir>/bundles/<symbolic_name>.zip.
    """
    if not os.path.isfile(source_bundle):
        fail("Source bundle not found: %s" % source_bundle)

    package_dir = os.path.dirname(source_bundle)
    dest = os.path.join(package_dir, "bundles", symbolic_name + ".zip")

    if not os.path.isfile(dest):
        fail("Container is missing expected bundle %s" % dest)

    with open(source_bundle, "rb") as fh:
        source_bytes = fh.read()
    with open(dest, "rb") as fh:
        dest_bytes = fh.read()
    if source_bytes != dest_bytes:
        fail(
            "Container bundle %s is not byte-identical to its source %s "
            "(copy is not a faithful deterministic file)" %
            (dest, source_bundle),
        )

    # The manifest-first + epoch contract is enforced by the hermetic
    # celix_zip --copy tool at build time; re-check here via the shared
    # validator so a drift between the two is caught by this test.
    error = celix_zip.validate_bundle_zip(dest)
    if error:
        fail("Container bundle %s is invalid: %s" % (dest, error))

    print("PASS: container bundle %s is %s (epoch %s)." % (dest, symbolic_name, ZIP_EPOCH))


def main():
    if len(sys.argv) < 2:
        fail(
            "Usage: validate_container.py "
            "--bundle <source_bundle_rootpath> <symbolic_name> ...",
        )

    i = 1
    while i < len(sys.argv):
        a = sys.argv[i]
        if a != "--bundle":
            fail("Unknown argument: %s" % a)
        source = sys.argv[i + 1] if i + 1 < len(sys.argv) else None
        symbolic_name = sys.argv[i + 2] if i + 2 < len(sys.argv) else None
        if source is None or symbolic_name is None:
            fail("Missing value for --bundle")
        check_container_bundle(source, symbolic_name)
        i += 3

    print("PASS: container contents validated.")


if __name__ == "__main__":
    main()