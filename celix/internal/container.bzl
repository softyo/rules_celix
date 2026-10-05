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

"""Pure layout helpers for Celix container assembly.

Celix containers expect their deployable bundle zips under a `bundles/`
directory, one zip per bundle, named after the bundle's symbolic name.  These
helpers derive those paths and validate the parts that make them up.  They are
kept free of rule/ctx logic so future container steps (runner, tarball
assembly) can reuse them unchanged.
"""

def bundle_zip_archive_path(symbolic_name):
    """Return the container archive path for a bundle zip.

    Celix loads bundle zips as plain files from the `bundles/` directory next
    to the container executable, so the layout is

        bundles/<symbolic_name>.zip

    Args:
        symbolic_name: string, the Bundle-SymbolicName of the bundle.  Must be
            non-empty and a safe single path component (no '/', '\\', '.', or
            '..') so the derived path cannot escape the bundles directory.

    Returns:
        string: the archive path `bundles/<symbolic_name>.zip`.

    Raises:
        fail() if symbolic_name is empty or would produce an unsafe path.
    """
    if symbolic_name == "":
        fail("celix_container: bundle symbolic name must not be empty")
    if symbolic_name in (".", ".."):
        fail("celix_container: invalid bundle symbolic name '%s'" % symbolic_name)
    if "/" in symbolic_name or "\\" in symbolic_name:
        fail(
            "celix_container: bundle symbolic name '%s' must be a single path " +
            "component (no '/' or '\\\\')" % symbolic_name,
        )
    return "bundles/%s.zip" % symbolic_name
