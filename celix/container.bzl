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

"""celix_container macro — assembles a runnable Celix container.

Lays each bundle zip out at `bundles/<symbolic_name>.zip`, generates the
framework `config.properties` (with `CELIX_AUTO_START_<level>` /
`CELIX_AUTO_INSTALL` keys so the framework auto-starts the bundles in Karaf
style), and wires everything so `bazel run` boots the Celix framework from the
generated configuration.

The macro generates these targets:

- `:<name>_runner` — the container's own runner `cc_binary`, built in the
  consumer package from `@rules_celix//tools:container_runner.c` and linked
  against the container's framework package (`framework_package`'s
  `:framework_static` target) with `--export-dynamic` so dlopened bundles'
  `celix_*` symbols bind against this single framework instance at run time.
- `:<name>` — the runnable container: `DefaultInfo(executable = <launcher>, ...)`
  whose runfiles carry that per-container runner `cc_binary`, the generated
  `config.properties`, and the bundle zips.
  `bazel run //path:<name>` boots the framework; see `tools/container_runner.c`
  and the integration smoke test for the stop protocol.
- `:<name>_config` — the generated `config.properties` (a text file under the
  container's runtime directory `<name>_runtime/`), with `CELIX_AUTO_START_*`
  and `CELIX_AUTO_INSTALL` keys derived from the bundles at analysis time.
- `:<name>_start_sh` — an `sh_binary` wrapper that `cd`s to its own directory
  and execs the container runner with the runtime directory (useful from a
  copied container tree; a future tarball step reuses it).
- `:<name>_tar_stage` / `:<name>_tarball` (when `tarball = True`, the default)
  — a `pkg_tar` and a user-facing filegroup whose default output is the
  deterministic distributable `<name>.tgz`.  The tarball extracts to the
  container layout (`<name>/start.sh`, `<name>/<name>_runner`,
  `<name>/<name>_runtime/...`) and runs on a host without Bazel:
  `tar -xzf <name>.tgz && cd <name> && ./start.sh`.

Example:

    load("@rules_celix//celix:defs.bzl", "celix_bundle", "celix_container")

    celix_bundle(
        name = "hello_bundle",
        activator = ":hello_lib",
        symbolic_name = "org.example.hello",
    )

    celix_bundle(
        name = "config_bundle",
        no_activator = True,
        symbolic_name = "org.example.config",
    )

    celix_container(
        name = "hello_container",
        bundles = {
            1: [":hello_bundle"],
        },
        install_only = [":config_bundle"],
    )

Run it with:

    bazel run //path:hello_container

The framework installs all bundles first, then starts them in ascending start
level order (0..6).  `install_only` bundles are installed but never started.
A bundle listed in both a start level and `install_only` is started: AUTO_START
wins (with a warning).

Auto-starting a C++ bundle requires `framework = "runtime"` (the default) so
the bundle's `celix_*` symbols bind against the single framework instance the
runner embeds and exports. A C++ bundle built with `framework = "static"`
(which embeds its own framework copy into the activator .so) is rejected at
analysis time if listed in `bundles` (start levels); move it to `install_only`
or set `framework = "runtime"`. C bundles are unaffected — static mode keeps
working because plain C symbols do not duplicate C++ program state.

The container's runner framework is `framework_package` (default
`@rules_celix//third_party/celix`). Every bundle's framework must match it and
each other: the config rule enforces the uniformity at analysis time, so all
bundles and the runner share one framework instance.
"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_cc//cc:defs.bzl", _cc_binary = "cc_binary")
load("//celix/internal:container.bzl", "container_runner_file_name", "container_runtime_dir")
load(
    "//celix/internal:container_impl.bzl",
    _celix_container_config_impl = "celix_container_config_impl",
    _celix_container_runfiles_impl = "celix_container_runfiles_impl",
)
load("//celix/internal:container_tar.bzl", _celix_container_tarball = "celix_container_tarball")

def celix_container(name, bundles = {}, install_only = [], tarball = True, framework_package = None, **kwargs):
    """Macro that assembles a runnable Celix container from level-ordered Celix bundles.

    Args:
        name (str): Unique target name for the resulting runnable container.
        bundles (dict of int to list of Label): Start levels 0..6, each mapping
            to the ordered list of `celix_bundle` targets to auto-start at that
            level.  The framework installs all bundles first, then starts them
            in ascending level order (declaration order preserved within a
            level) and stops them in reverse.  A bundle must not be listed
            under two different levels.  Each bundle is laid out at
            `bundles/<symbolic_name>.zip` under the container's runtime
            directory, so symbolic names must be unique within a container and
            must not contain spaces.
        install_only (list of Label): Bundles to install but never start
            (emitted under `CELIX_AUTO_INSTALL`).  A bundle that is also listed
            in `bundles` is auto-started instead (AUTO_START wins, with a
            warning).  Install-only bundles are never started, so a C++ bundle
            built with `framework = "static"` may safely live here.
        tarball (bool): Whether to additionally generate the distributable
            `:<name>_tarball` / `<name>.tgz` target (default True).  Set
            `tarball = False` to skip the tarball step when only `bazel run`
            is needed (no rules_pkg dependency is pulled in).
        framework_package (str): Package label string (repo name, optionally
            followed by a package path) of the Celix framework package the
            runner links against.  The referenced package must expose
            `:framework` (headers-only) and `:framework_static` (full static
            archive).  Defaults to None, meaning
            `@rules_celix//third_party/celix`.  Every bundle in the container
            must link against the same framework package, which the config
            rule's uniformity check enforces at analysis time: use the same
            value here as the bundles' `framework_package` / `celix` runtime's
            `framework`.
        **kwargs: Additional attributes forwarded to the generated rules.
    """
    if type(bundles) != "dict":
        fail(
            "celix_container: 'bundles' must be a dict {int level 0..6: [labels]}; " +
            "got a like-list — use install_only=[] for install-only bundles.",
        )

    # The macro cannot read providers, so the runner's framework package is an
    # explicit parameter (defaulting to the canonical package) used for the
    # runner's link and passed to the config rule, which compares every
    # bundle's framework against it at analysis time.
    runner_framework_label = framework_package if framework_package != None else "@rules_celix//third_party/celix"

    # Flatten start-level bundles into declaration order, rejecting a label
    # listed under two different levels (silent last-wins is forbidden).
    bundle_levels = {}
    bundles_list = []
    for level, labels in bundles.items():
        for label in labels:
            if label in bundle_levels:
                fail(
                    "celix_container: bundle '%s' is listed under two different " +
                    "start levels (%s and %s) in '%s'" %
                    (label, bundle_levels[label], level, name),
                )
            bundle_levels[label] = str(level)
            if label not in bundles_list:
                bundles_list.append(label)

    install_only_survivors = []
    for label in install_only:
        if label in bundle_levels:
            # AUTO_START wins: excluded from CELIX_AUTO_INSTALL (the config
            # rule prints the warning) and from the copy list.
            continue
        if label not in install_only_survivors:
            install_only_survivors.append(label)

    bundles_list += install_only_survivors

    _config_name = name + "_config"
    _start_sh_name = name + "_start_sh"
    _start_sh_src = name + "_start"
    _runner_name = container_runner_file_name(name)

    # The container's own runner, built per container in the consumer package
    # from the shared (framework-agnostic) source and linked against the
    # container's framework package.  Only a select set of kwargs makes sense
    # for a cc_binary; forward the safe cc-agnostic subset (a caller-supplied
    # visibility wins over the public default), then pass the remaining kwargs
    # to the rule targets below (which reject cc-only attrs).
    _cc_binary_kwargs = {
        "visibility": ["//visibility:public"],
    }
    if "testonly" in kwargs:
        _cc_binary_kwargs["testonly"] = kwargs["testonly"]
    if "tags" in kwargs:
        _cc_binary_kwargs["tags"] = kwargs["tags"]
    if "visibility" in kwargs:
        _cc_binary_kwargs["visibility"] = kwargs["visibility"]
    _cc_binary(
        name = _runner_name,
        srcs = ["@rules_celix//tools:container_runner.c"],
        deps = ["%s:framework_static" % runner_framework_label],
        linkopts = select({
            "@platforms//os:macos": ["-Wl,-export_dynamic"],
            "//conditions:default": ["-Wl,--export-dynamic"],
        }),
        **_cc_binary_kwargs
    )

    _celix_container_config_impl(
        name = _config_name,
        bundle_levels = bundle_levels,
        install_only = install_only,
        container_name = name,
        framework = runner_framework_label,
        **kwargs
    )

    write_file(
        name = _start_sh_src,
        out = "%s.sh" % name,
        content = [
            "#!/usr/bin/env bash",
            'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"',
            'cd "$SCRIPT_DIR"',
            'exec ./%s "%s" "$@"' % (_runner_name, container_runtime_dir(name)),
        ],
        is_executable = True,
        **kwargs
    )

    _celix_container_runfiles_impl(
        name = name,
        bundles = bundles_list,
        runner_config = ":" + _config_name,
        runner = ":" + _runner_name,
        **kwargs
    )

    native.sh_binary(
        name = _start_sh_name,
        srcs = [":%s.sh" % name],
        data = [":%s" % name],
        **kwargs
    )

    if tarball:
        _celix_container_tarball(
            name = name,
            container_name = name,
            runfiles_label = ":" + name,
            start_sh_label = ":" + _start_sh_src,
            **kwargs
        )
