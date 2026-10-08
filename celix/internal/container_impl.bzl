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

"""Implementation of the celix_container config and runfiles rules."""

load("//celix:providers.bzl", "CelixBundleInfo", "CelixContainerInfo")
load(
    "//celix/internal:container.bzl",
    "bundle_zip_archive_path",
    "container_runner_file_name",
    "container_runtime_dir",
    "format_config_properties",
    "validate_autostart_level",
)

# The single shared runner binary, built once in rules_celix's repo (where
# @celix resolves) and copied into every container by the rule below.
_RUNNER_LABEL = "@rules_celix//tools:container_runner"

def _container_dir(ctx):
    """Return the container's runtime directory (package-relative, no trailing slash).

    All container outputs (config.properties, bundles/) nest under this
    directory so multiple containers can coexist in one Bazel package and the
    runnable target itself (a file named after the target) cannot collide with
    it.  Under `bazel run` the process CWD is the package dir and the launcher
    passes this directory to the runner.
    """
    return container_runtime_dir(ctx.label.name)

def _celix_container_config_impl_fn(ctx):
    """Generate the container's `config.properties` from provider data.

    The config content depends on `CelixBundleInfo` (each bundle's symbolic
    name derives its archive path), so it is produced by a rule at analysis
    time rather than by the macro's `write_file`.  The config rule validates
    the start levels, emits `CELIX_AUTO_START_<level>` for every non-empty
    level in ascending order and `CELIX_AUTO_INSTALL` for the surviving
    `install_only` bundles, and writes the file at
    `<container_name>_runtime/config.properties`.
    """
    level_labels = {str(target.label): True for target in ctx.attr.bundle_levels.keys()}
    seen = {}
    label_by_sym = {}

    def _collect(target):
        info = target[CelixBundleInfo]
        sym_name = info.symbolic_name
        if sym_name in seen:
            fail(
                "celix_container: duplicate bundle symbolic name '%s' " % sym_name +
                "(already provided by '%s') in '%s'" % (seen[sym_name], ctx.label),
            )
        seen[sym_name] = str(target.label)
        label_by_sym[str(target.label)] = info

    autostart_levels = {}
    for target, level_str in ctx.attr.bundle_levels.items():
        info = target[CelixBundleInfo]
        if info.uses_cpp and info.link_mode == "static" and info.activator != None:
            fail(
                "celix_container: bundle '%s' has a C++ activator linked with " % target.label +
                "framework = \"static\" and cannot be auto-started: the bundle " +
                "embeds its own copy of the Celix framework, which crashes in " +
                "celix::impl::createActivator when started inside the runner's " +
                "framework instance. Set framework = \"runtime\" on the bundle " +
                "or move it to install_only.",
            )

        # Parse the stringified level defensively: only a plain integer token
        # is accepted, so non-int keys ("3.5", "foo", "") and out-of-range
        # values (7, -1) all fail the range check below with one clear message.
        is_int = level_str != ""
        for i in range(len(level_str)):
            if level_str[i] not in "0123456789":
                is_int = False
                break
        level = int(level_str) if is_int else -1
        validate_autostart_level(level)
        _collect(target)
        autostart_levels.setdefault(level, []).append(
            bundle_zip_archive_path(label_by_sym[str(target.label)].symbolic_name),
        )

    install_only_paths = []
    for target in ctx.attr.install_only:
        # A bundle listed in both a start level and install_only: AUTO_START
        # wins; it is excluded from AUTO_INSTALL and from the runfiles rule's
        # copy list (the macro already dropped it there).
        if str(target.label) in level_labels:
            print(
                "celix_container: bundle '%s' is listed in both a start level " % target.label +
                "and install_only; AUTO_START wins and it is not added to " +
                "CELIX_AUTO_INSTALL",
            )
            continue
        _collect(target)
        install_only_paths.append(bundle_zip_archive_path(label_by_sym[str(target.label)].symbolic_name))

    config_out = ctx.actions.declare_file(
        "%s/config.properties" % container_runtime_dir(ctx.attr.container_name),
    )
    ctx.actions.write(
        output = config_out,
        content = format_config_properties(autostart_levels, install_only_paths),
    )

    return [DefaultInfo(files = depset([config_out]))]

def _declared_bundle_path(ctx, sym_name):
    """Package-relative path for a bundle copy (used for declare_file).

    Nests under the container directory so multiple containers can coexist in
    one package and `bazel run` passes this directory to the runner.
    """
    return "%s/%s" % (_container_dir(ctx), bundle_zip_archive_path(sym_name))

def _celix_container_runfiles_impl_fn(ctx):
    """Assemble a runnable Celix container from its bundles.

    Each bundle's zip is materialized as a real, standalone file at
    `bundles/<symbolic_name>.zip` via a single hermetic invocation of the
    celix_zip --copy tool (bytes preserved verbatim, so determinism is
    inherited from the bundle zips).

    The shared runner binary (building once per repo, not per container) is
    copied into the package dir as `<name>_runner`. The target is executable:
    it declares a small launcher script (the rule's own output, written by
    `ctx.actions.write`) that `cd`s to the container's package dir and then
    execs the copied runner with the container's directory as argument, so the
    runner boots the embedded Celix framework from the generated
    `config.properties` and finds `bundles/` relative to it.  The runfiles
    carry the runner copy, the config, and every bundle zip so the whole set is
    built and materialized by a single `bazel run //path:name`.
    """
    copies = []
    outputs = []
    seen = {}
    for target in ctx.attr.bundles:
        info = target[CelixBundleInfo]
        sym_name = info.symbolic_name
        if sym_name in seen:
            fail(
                "celix_container: duplicate bundle symbolic name '%s' " % sym_name +
                "(already provided by '%s') in '%s'" % (seen[sym_name], ctx.label),
            )
        seen[sym_name] = str(target.label)

        out = ctx.actions.declare_file(_declared_bundle_path(ctx, sym_name))
        copies.append((info.bundle, out))
        outputs.append(out)

    if outputs:
        args = ctx.actions.args()
        for (src, out) in copies:
            args.add("--copy")
            args.add(src.path)
            args.add(out.path)

        ctx.actions.run(
            inputs = [src for (src, _) in copies],
            outputs = outputs,
            executable = ctx.executable._zip_tool,
            arguments = [args],
            mnemonic = "CelixContainerZip",
            progress_message = "Assembling Celix container %{output}",
        )

    config = ctx.file.runner_config

    # Copy the shared runner binary into this container's package dir so the
    # runtime tree is self-contained (the launcher, runfiles, and CelixContainerInfo
    # all reference this copy).  A dedicated hermetic tool is used instead of
    # `cp` in run_shell or `celix_zip --copy`: the latter validates bundle zips
    # (the runner is a plain ELF binary) and shell copies depend on host PATH.
    runner = ctx.actions.declare_file(container_runner_file_name(ctx.label.name))
    ctx.actions.run(
        outputs = [runner],
        inputs = [ctx.file._runner],
        executable = ctx.executable._copy_tool,
        arguments = [ctx.file._runner.path, runner.path],
        mnemonic = "CelixContainerCopyRunner",
        progress_message = "Copying container runner %{output}",
    )

    # The runfiles rule is executable.  Since DefaultInfo(executable = ...)
    # must be a file produced by this rule, we generate a tiny launcher script
    # that cd's to the package dir (where the runner copy, config.properties
    # and bundles/ live as real files under `bazel run`) and execs the runner,
    # passing the container directory so the runner resolves config.properties
    # and bundles/ against it.
    launcher = ctx.outputs.executable
    launcher_content = (
        "#!/usr/bin/env bash\n" +
        'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n' +
        'cd "$SCRIPT_DIR"\n' +
        'exec ./%s "%s" "$@"\n' % (runner.basename, _container_dir(ctx))
    )
    ctx.actions.write(
        output = launcher,
        content = launcher_content,
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = [runner, config] + outputs,
    )

    return [
        DefaultInfo(
            executable = launcher,
            files = depset([launcher] + [runner] + outputs + [config]),
            runfiles = runfiles,
        ),
        CelixContainerInfo(
            runner = runner,
            bundles = outputs,
            config = config,
        ),
    ]

_celix_container_config_rule = rule(
    implementation = _celix_container_config_impl_fn,
    attrs = {
        "bundle_levels": attr.label_keyed_string_dict(
            mandatory = True,
            providers = [CelixBundleInfo],
            doc = "Internal: map of celix_bundle target to its start level, as " +
                  "a string in \"0\"..\"6\".  The rule parses and validates the " +
                  "level at analysis time.",
        ),
        "install_only": attr.label_list(
            mandatory = True,
            providers = [CelixBundleInfo],
            doc = "Internal: celix_bundle targets to install without starting " +
                  "(emitted under CELIX_AUTO_INSTALL).",
        ),
        "container_name": attr.string(
            mandatory = True,
            doc = "Internal: the celix_container target name, used to derive " +
                  "the <name>_runtime output path (this rule's own label is " +
                  "<name>_config).",
        ),
    },
    doc = "Generates the container's config.properties from CelixBundleInfo, " +
          "emitting CELIX_AUTO_START_<level> for every non-empty start level " +
          "(ascending) and CELIX_AUTO_INSTALL for the install-only bundles.",
)

_celix_container_runfiles_rule = rule(
    implementation = _celix_container_runfiles_impl_fn,
    executable = True,
    attrs = {
        "_zip_tool": attr.label(
            cfg = "exec",
            default = "//tools:celix_zip",
            executable = True,
            doc = "Internal: hermetic zip packaging tool.",
        ),
        "bundles": attr.label_list(
            mandatory = True,
            providers = [CelixBundleInfo],
            doc = "Flattened, ordered list of celix_bundle targets to assemble " +
                  "into the container: start-level bundles first (in the " +
                  "celix_container macro's bundles dict declaration order), " +
                  "then install-only bundles.  Each bundle's zip is laid out at " +
                  "bundles/<symbolic_name>.zip under the container directory, " +
                  "preserving this order.",
        ),
        "_copy_tool": attr.label(
            cfg = "exec",
            default = "//tools:file_copy",
            executable = True,
            doc = "Internal: hermetic byte-copy tool for the runner copy.",
        ),
        "_runner": attr.label(
            allow_single_file = True,
            default = _RUNNER_LABEL,
            doc = "Internal: the shared container runner binary (built once in " +
                  "rules_celix's repo, embedding the Celix framework) which the " +
                  "rule copies into the package dir as <name>_runner.  Target " +
                  "config (no cfg), matching the host-built binary; `bazel run` " +
                  "requires host==target.",
        ),
        "runner_config": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Internal: label of the generated config.properties.",
        ),
    },
    doc = "Assembles a runnable Celix container from celix_bundle targets.  " +
          "Produces each bundle zip as a real standalone file under " +
          "bundles/<symbolic_name>.zip (deterministic byte copies, not symlinks) " +
          "and wires a launcher + runfiles so `bazel run` starts the embedded " +
          "Celix framework using the generated config.properties, which " +
          "auto-starts the bundles by level (CELIX_AUTO_START_*).",
)

# Exported for the macro in celix/container.bzl
celix_container_runfiles_impl = _celix_container_runfiles_rule
celix_container_config_impl = _celix_container_config_rule
