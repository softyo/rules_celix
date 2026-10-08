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
style), and wires everything so `bazel run` boots the embedded Celix framework
from the generated configuration.

The macro generates these targets:

- `:<name>` — the runnable container: `DefaultInfo(executable = <launcher>, ...)`
  whose runfiles carry a copy of the shared runner binary (`@rules_celix//tools:container_runner`),
  `config.properties`, and the bundle zips.  The runner is built once in the
  rules_celix repository (where `@celix` resolves and the framework is embedded)
  and copied into the package dir as `<name>_runner` by the rule, so the
  container needs no consumer-side `@celix`.
  `bazel run //path:<name>` boots the framework; see `tools/container_runner.c`
  and the integration smoke test for the stop protocol.
- `:<name>_config` — the generated `config.properties` (a text file under the
  container's runtime directory `<name>_runtime/`), with `CELIX_AUTO_START_*`
  and `CELIX_AUTO_INSTALL` keys derived from the bundles at analysis time.
- `:<name>_start_sh` — an `sh_binary` wrapper that `cd`s to its own directory
  and execs the container runner with the runtime directory (useful from a
  copied container tree; a future tarball step reuses it).

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
"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//celix/internal:container.bzl", "container_runner_file_name", "container_runtime_dir")
load(
    "//celix/internal:container_impl.bzl",
    _celix_container_config_impl = "celix_container_config_impl",
    _celix_container_runfiles_impl = "celix_container_runfiles_impl",
)

def celix_container(name, bundles = {}, install_only = [], **kwargs):
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
        **kwargs: Additional attributes forwarded to the generated rules.
    """
    if type(bundles) != "dict":
        fail(
            "celix_container: 'bundles' must be a dict {int level 0..6: [labels]}; " +
            "got a like-list — use install_only=[] for install-only bundles.",
        )

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

    _celix_container_config_impl(
        name = _config_name,
        bundle_levels = bundle_levels,
        install_only = install_only,
        container_name = name,
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
        **kwargs
    )

    native.sh_binary(
        name = _start_sh_name,
        srcs = [":%s.sh" % name],
        data = [":%s" % name],
        **kwargs
    )
