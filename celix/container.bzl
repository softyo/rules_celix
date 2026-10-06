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
framework `config.properties`, and wires everything so `bazel run` boots the
embedded Celix framework from the generated configuration.

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
  container's runtime directory `<name>_runtime/`).
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

    celix_container(
        name = "hello_container",
        bundles = [":hello_bundle"],
    )

Run it with:

    bazel run //path:hello_container

The container's bundles are not installed or started by the framework yet:
bundle start levels arrive in a later step.
"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//celix/internal:container.bzl", "container_runner_file_name", "container_runtime_dir", "format_config_properties")
load("//celix/internal:container_impl.bzl", _celix_container_runfiles_impl = "celix_container_runfiles_impl")

def celix_container(name, bundles, **kwargs):
    """Macro that assembles a runnable Celix container from a list of Celix bundles.

    Args:
        name (str): Unique target name for the resulting runnable container.
        bundles (list of Label): Ordered list of `celix_bundle` targets to assemble.
            Each bundle is laid out at `bundles/<symbolic_name>.zip` under the
            container's runtime directory, so symbolic names must be unique
            within a container. Bundle start levels are not yet supported and
            will arrive in a later step.
        **kwargs: Additional attributes forwarded to the generated rules.
    """
    _config_name = name + "_config"
    _start_sh_name = name + "_start_sh"
    _start_sh_src = name + "_start"
    _runner_name = container_runner_file_name(name)

    write_file(
        name = _config_name,
        out = "%s/config.properties" % container_runtime_dir(name),
        content = [format_config_properties()],
        newline = "unix",
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
        bundles = bundles,
        runner_config = ":" + _config_name,
        **kwargs
    )

    native.sh_binary(
        name = _start_sh_name,
        srcs = [":%s.sh" % name],
        data = [":%s" % name],
        **kwargs
    )
