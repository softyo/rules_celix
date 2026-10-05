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

"""Implementation of the celix_container rule."""

load("//celix:providers.bzl", "CelixBundleInfo", "CelixContainerInfo")
load("//celix/internal:container.bzl", "bundle_zip_archive_path")

def _celix_container_impl_fn(ctx):
    """Assemble a container's deployable contents from its bundles.

    Each bundle's zip is materialized as a real, standalone file at
    `bundles/<symbolic_name>.zip` via a single hermetic invocation of the
    celix_zip --copy tool (bytes are preserved verbatim, so determinism is
    inherited from the bundle zips).  These are true files, not symlinks, so
    the container tree can be copied verbatim next to a Celix executable.
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

        out = ctx.actions.declare_file(bundle_zip_archive_path(sym_name))
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

    return [
        DefaultInfo(files = depset(outputs)),
        CelixContainerInfo(
            runner = None,
            bundles = outputs,
            config = None,
        ),
    ]

_celix_container_rule = rule(
    implementation = _celix_container_impl_fn,
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
            doc = "Ordinal list of celix_bundle targets to assemble into the " +
                  "container.  Each bundle's zip is laid out at " +
                  "bundles/<symbolic_name>.zip, preserving bundle order.  " +
                  "Bundle start levels are not yet supported and will arrive " +
                  "in a later step.",
        ),
    },
    doc = "Assembles a Celix container's deployable contents from celix_bundle " +
          "targets.  Produces each bundle zip as a real standalone file under " +
          "bundles/<symbolic_name>.zip (deterministic byte copies, not symlinks), " +
          "ready to be copied next to a Celix executable.  The launcher " +
          "executable and framework configuration are not yet generated.",
)

# Exported for the macro in celix/container.bzl
celix_container_impl = _celix_container_rule
