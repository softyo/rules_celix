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
generated framework configuration file (including the `CELIX_AUTO_START_*` and
`CELIX_AUTO_INSTALL` keys that make the framework auto-install and auto-start
the container's bundles).  They are kept free of rule/ctx logic so future
container steps (runner, tarball assembly) can reuse them unchanged.
"""

# The framework reads `CELIX_AUTO_START_<level>` (0..6) in ascending order: it
# installs all listed bundles first, then starts them in the same order.  The
# keys are fixed by Celix; see libs/framework/include/celix_constants.h.
AUTO_START_MIN_LEVEL = 0
AUTO_START_MAX_LEVEL = 6
AUTO_START_KEYS = ["CELIX_AUTO_START_%d" % i for i in range(AUTO_START_MIN_LEVEL, AUTO_START_MAX_LEVEL + 1)]
AUTO_INSTALL_KEY = "CELIX_AUTO_INSTALL"

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

def start_sh_file_name(name):
    """Return the tarball's launcher file name for the given target name.

    The tarball reuses the container's generated start script (a content copy
    of `:<name>_start`) as `start.sh`, the issue-specified single-container
    launcher: it `cd`s to its own directory and execs `<name>_runner` against
    `<name>_runtime`.  The name is deliberately plain `start.sh` (not
    `<name>.sh`) — the nested `<name>/` tarball root already prevents
    collisions between containers.

    Args:
        name: string, the celix_container target name.

    Returns:
        string: `"start.sh"`.
    """
    return "start.sh"

def tarball_file_name(name):
    """Return the distributable tarball file name for the given target name.

    Args:
        name: string, the celix_container target name.

    Returns:
        string: `"<name>.tgz"`.
    """
    return name + ".tgz"

def validate_autostart_level(level):
    """Fail unless `level` is one of the seven fixed Celix start levels.

    Celix only supports the start levels 0..6 (`CELIX_AUTO_START_0` ..
    `CELIX_AUTO_START_6`); anything else would be silently ignored by the
    framework, so it is rejected here instead.

    Args:
        level: int, the start level to validate.

    Raises:
        fail() if the level is outside the supported 0..6 range.
    """
    if level < AUTO_START_MIN_LEVEL or level > AUTO_START_MAX_LEVEL:
        fail(
            "celix_container: invalid bundle start level %d — Celix only " +
            "supports the seven fixed levels %d..%d" %
            (level, AUTO_START_MIN_LEVEL, AUTO_START_MAX_LEVEL),
        )

def format_config_properties(autostart_levels = {}, install_only = []):
    """Return the generated Celix framework configuration file body.

    The emitted keys are deterministic: the four static framework keys are
    followed by `CELIX_AUTO_START_<level>` lines (ascending level order, only
    for levels with at least one bundle — `CELIX_AUTO_START_0` is omitted when
    empty) and finally `CELIX_AUTO_INSTALL` when `install_only` is non-empty:

        CELIX_BUNDLES_PATH=bundles
        CELIX_FRAMEWORK_CACHE_DIR=.cache
        CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true
        CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info
        CELIX_AUTO_START_1=bundles/org.example.hello.zip
        CELIX_AUTO_INSTALL=bundles/org.example.config.zip

    - `CELIX_BUNDLES_PATH` and `CELIX_FRAMEWORK_CACHE_DIR` are Celix's own
      defaults; they are emitted explicitly and relatively so the config is
      self-documenting and stays hermetic under `bazel run`.
    - `CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true` keeps repeated runs clean: the
      framework cache lives in /tmp and is deleted on destroy, never touching
      the runfiles tree.
    - Celix reads `CELIX_AUTO_START_0..6` in ascending order: all listed
      bundles are installed first, then started in that same order, preserving
      declaration order within a level.  `CELIX_AUTO_INSTALL` is processed
      after the start set and only installs (never starts).  Paths are
      space-separated, so bundle symbolic names must not contain spaces (see
      `bundle_zip_archive_path()`).

    Args:
        autostart_levels: dict of int to list of str — one archive path entry
            per bundle per start level, keyed by level 0..6.  Only non-empty
            levels are emitted, in ascending level order.
        install_only: list of str — archive paths of bundles to install but
            never start; emitted under `CELIX_AUTO_INSTALL` only when non-empty.

    Returns:
        string: the config file body, static lines first, then the ordered
            autostart/install section, with a single trailing `\n`.
    """
    body = (
        "CELIX_BUNDLES_PATH=bundles\n" +
        "CELIX_FRAMEWORK_CACHE_DIR=.cache\n" +
        "CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true\n" +
        "CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info\n"
    )
    for level in range(AUTO_START_MIN_LEVEL, AUTO_START_MAX_LEVEL + 1):
        validate_autostart_level(level)
        if level in autostart_levels:
            paths = autostart_levels[level]
            if paths:
                body += "%s=%s\n" % (AUTO_START_KEYS[level], " ".join(paths))
    if install_only:
        body += "%s=%s\n" % (AUTO_INSTALL_KEY, " ".join(install_only))
    return body

def bundle_zip_archive_path(symbolic_name):
    """Return the container archive path for a bundle zip.

    Celix loads bundle zips as plain files from the `bundles/` directory next

        bundles/<symbolic_name>.zip

    Args:
        symbolic_name: string, the Bundle-SymbolicName of the bundle.  Must be
            non-empty, a safe single path component (no '/', '\\', '.', '..',
            or space) so the derived path cannot escape the bundles directory
            and stays valid as a single space-separated entry in the
            `CELIX_AUTO_START_*` / `CELIX_AUTO_INSTALL` config values.

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
    if " " in symbolic_name:
        fail(
            "celix_container: bundle symbolic name '%s' must not contain " +
            "spaces — 'CELIX_AUTO_START_*' / 'CELIX_AUTO_INSTALL' config " +
            "values are space-separated paths" % symbolic_name,
        )
    return "bundles/%s.zip" % symbolic_name
