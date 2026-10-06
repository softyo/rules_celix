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
helpers derive those paths, validate the parts that make them up, and format the
generated framework configuration file.  They are kept free of rule/ctx logic so
future container steps (runner, tarball assembly) can reuse them unchanged.
"""

def container_runner_file_name(name):
    """Return the per-container runner file name for the given target name.

    The single source of truth for the runner copy's basename.  Both the rule
    (`declare_file`) and the celix_container macro's `start_sh` launcher use
    it, so the convention lives in exactly one place.

    Args:
        name: string, the celix_container target name.

    Returns:
        string: `"<name>_runner"`.
    """
    return name + "_runner"

def container_runtime_dir(name):
    """Return the container's runtime directory for the given target name.

    All container outputs (config.properties, bundles/) nest under this
    package-relative directory so multiple containers can coexist in one Bazel
    package and the runnable target itself (a file named after the target)
    cannot collide with it.  Under `bazel run` the process CWD is the package
    dir and the generated launcher passes this directory to the runner.

    Args:
        name: string, the celix_container target name.

    Returns:
        string: `"<name>_runtime"`.
    """
    return name + "_runtime"

def format_config_properties():
    """Return the generated Celix framework configuration file body.

    The emitted keys are static and minimal for this milestone:

        CELIX_BUNDLES_PATH=bundles
        CELIX_FRAMEWORK_CACHE_DIR=.cache
        CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true
        CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info

    - `CELIX_BUNDLES_PATH` and `CELIX_FRAMEWORK_CACHE_DIR` are Celix's own
      defaults; they are emitted explicitly and relatively so the config is
      self-documenting and stays hermetic under `bazel run`.
    - `CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true` keeps repeated runs clean: the
      framework cache lives in /tmp and is deleted on destroy, never touching
      the runfiles tree.
    - A later milestone (start-level autostart) extends this body with
      `CELIX_AUTO_START_*` keys; this helper stays the single formatting spot.

    Returns:
        string: the config file body, exactly four `key=value` lines in this
            fixed order with a single trailing `\n`.
    """
    return (
        "CELIX_BUNDLES_PATH=bundles\n" +
        "CELIX_FRAMEWORK_CACHE_DIR=.cache\n" +
        "CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true\n" +
        "CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info\n"
    )

def bundle_zip_archive_path(symbolic_name):
    """Return the container archive path for a bundle zip.

    Celix loads bundle zips as plain files from the `bundles/` directory next

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
