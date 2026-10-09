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

"""Distributable tarball step for celix_container (issue #10).

The runfiles rule materializes the container's runtime layout as individual
generated files (config.properties, bundle zips, the runner copy) under
`<name>_runtime/` in the package dir.  This module packages exactly those
files — plus the container's start script — into a deterministic `<name>.tgz`
whose extraction tree mirrors the `bazel run` layout:

    <name>.tgz
    └── <name>/
        ├── start.sh                # content copy of <name>_start
        ├── <name>_runner           # the runner copy (executable)
        └── <name>_runtime/
            ├── config.properties
            └── bundles/<symbolic_name>.zip

The tarball is a `pkg_tar` (rules_pkg): entries are sorted, mtime is portable
(2000-01-01), owner is fixed, and every destination is a package-root-relative
string derived from `dest_path`, so no absolute bazel-out paths leak into the
archive and identical inputs produce bit-identical bytes.  The manifest-first
zip-ordering constraint that keeps bundle zips on the custom celix_zip tool
does not apply to tar assembly.

Assembly works on the SAME individual files the runfiles rule produces (not a
TreeArtifact snapshot): a Bazel analysis-time check forbids declaring a tree
artifact whose path nests another rule's output files, so the runtime directory
cannot both be a TreeArtifact and carry the `CelixContainerInfo.bundles` File
objects the existing analysis tests assert on.  Packaging the runfiles outputs
directly guarantees the tarball stays byte-for-byte faithful to the
`bazel run` artifact with zero duplicated state.
"""

load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("//celix:providers.bzl", "CelixContainerInfo")
load(
    "//celix/internal:container.bzl",
    "container_runner_file_name",
    "start_sh_file_name",
    "tarball_file_name",
)

def _celix_container_runtime_files_impl(ctx):
    """Expose the runtime layout's constituent files as flat DefaultInfo.

    pkg_tar derives each archive destination from the file's path (stripped of
    the package dir via strip_prefix = "."), so the tar rule needs a target
    whose DefaultInfo.files is exactly {runner, config, bundle zips} — the
    runfiles layout minus the launcher, which must not appear in the tarball.
    The order of `bundles` is preserved from the container (start levels first,
    then install-only), matching CelixContainerInfo.bundles.
    """
    info = ctx.attr.container[CelixContainerInfo]
    return [
        DefaultInfo(files = depset([info.config, info.runner] + info.bundles)),
    ]

_celix_container_runtime_files_rule = rule(
    implementation = _celix_container_runtime_files_impl,
    attrs = {
        "container": attr.label(
            mandatory = True,
            providers = [CelixContainerInfo],
            doc = "Internal: the celix_container runfiles rule target whose " +
                  "runtime layout files are packaged into the tarball.",
        ),
    },
    doc = "Internal: re-exposes the runtime layout files (runner, config, " +
          "bundle zips) of a celix_container as flat DefaultInfo for pkg_tar " +
          "assembly.",
)

def celix_container_tarball(
        name,
        container_name,
        runfiles_label,
        start_sh_label,
        **kwargs):
    """Generate the `:<name>_tarball` distributable artifact for a container.

    Args:
        name: string, the celix_container target name.  Generated targets:
            `:<name>_tar_inputs` (internal gather rule), `:<name>_tar_stage`
            (the pkg_tar) and `:<name>_tarball` (user-facing filegroup whose
            single default output is `<name>.tgz`).
        container_name: string, the celix_container target name; used verbatim
            for the tarball root directory and the `out` file name.
        runfiles_label: Label, the `:<name>` runfiles rule target whose runtime
            layout files (runner + config + bundle zips) are packaged.
        start_sh_label: Label, the generated `:<name>_start` script target; its
            output is copied into the tarball as `start.sh` so the extracted
            tree runs without Bazel.
        **kwargs: forwarded to pkg_tar and the tarball filegroup.
    """
    _celix_container_runtime_files_rule(
        name = name + "_tar_inputs",
        container = runfiles_label,
        **kwargs
    )

    pkg_tar(
        name = name + "_tar_stage",
        srcs = [":" + name + "_tar_inputs"],
        # Strip only the package dir: the srcs' short paths are
        # <pkg>/<name>_runtime/... and <pkg>/<name>_runner, so stripping the
        # package leaves the runtime layout root-relative, then package_dir
        # nests it under <name>/ inside the archive.
        strip_prefix = ".",
        files = {
            start_sh_label: start_sh_file_name(container_name),
        },
        package_dir = container_name,
        mode = "0644",
        modes = {
            start_sh_file_name(container_name): "0755",
            container_runner_file_name(container_name): "0755",
        },
        extension = "tgz",
        out = tarball_file_name(container_name),
        **kwargs
    )

    native.filegroup(
        name = name + "_tarball",
        srcs = [":" + name + "_tar_stage"],
        **kwargs
    )
