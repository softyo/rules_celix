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

"""Implementation of the celix_bundle rule."""

load("//celix:providers.bzl", "CelixBundleInfo", "CelixRuntimeInfo")
load("//celix/internal:cc.bzl", "get_shared_library_file")
load("//celix/internal:manifest.bzl", "generate_manifest")
load("//celix/internal:zip.bzl", "create_bundle_zip")

def _celix_bundle_impl_fn(ctx):
    no_activator = ctx.attr.no_activator

    if not no_activator and ctx.attr.activator == None:
        fail("celix_bundle requires 'activator' unless no_activator = True")

    # In no_activator mode the activator (if set) is ignored and not shipped.
    activator_file = None
    if not no_activator:
        activator_file = get_shared_library_file(ctx.attr.activator)

    private_lib_files = []
    for lib_target in ctx.attr.private_libs:
        private_lib_files.append(get_shared_library_file(lib_target))

    manifest = generate_manifest(
        ctx,
        private_lib_names = [f.basename for f in private_lib_files],
    )

    # Build the ordered list of (src, dest, mode) entries for the zip.
    file_specs = []
    if activator_file != None:
        file_specs.append((activator_file, activator_file.basename, 0o755))
    for f in private_lib_files:
        file_specs.append((f, f.basename, 0o755))
    for r in ctx.files.resources:
        file_specs.append((r, r.short_path, 0o644))

    # Compute the output zip base name, tolerating a user-supplied .zip suffix.
    zip_name = ctx.attr.filename if ctx.attr.filename else ctx.label.name
    if zip_name.endswith(".zip"):
        zip_name = zip_name[:-len(".zip")]
    zip_name += ".zip"

    zip_file = create_bundle_zip(
        ctx,
        manifest.file,
        manifest.archive_path,
        file_specs,
        ctx.executable._zip_tool,
        zip_name,
    )

    bundle_name = ctx.attr.bundle_name if ctx.attr.bundle_name else ctx.attr.symbolic_name

    return [
        DefaultInfo(files = depset([zip_file])),
        CelixBundleInfo(
            bundle = zip_file,
            symbolic_name = ctx.attr.symbolic_name,
            bundle_name = bundle_name,
            version = ctx.attr.version,
            activator = activator_file,
            private_libs = private_lib_files,
        ),
    ]

_celix_bundle_rule = rule(
    implementation = _celix_bundle_impl_fn,
    attrs = {
        "_zip_tool": attr.label(
            cfg = "exec",
            default = "//tools:celix_zip",
            executable = True,
            doc = "Internal: hermetic zip packaging tool.",
        ),
        "activator": attr.label(
            mandatory = False,
            providers = [CcSharedLibraryInfo],
            doc = "The cc_shared_library containing the activator. Ignored when no_activator = True.",
        ),
        "symbolic_name": attr.string(
            mandatory = True,
            doc = "OSGi Bundle-SymbolicName.",
        ),
        "version": attr.string(
            default = "0.0.0",
            doc = "OSGi Bundle-Version. Defaults to \"0.0.0\".",
        ),
        "bundle_name": attr.string(
            doc = "OSGi Bundle-Name. Human-readable display name. Defaults to symbolic_name if unset.",
        ),
        "celix": attr.label(
            providers = [CelixRuntimeInfo],
            default = "//celix:default_runtime",
            doc = "Celix runtime target defining manifest format and conventions.",
        ),
        "private_libs": attr.label_list(
            allow_files = True,
            doc = "Additional private shared libraries (.so/.dylib/.dll) to bundle. Each entry " +
                  "may be a cc_shared_library target or a plain file/prebuilt library.",
        ),
        "resources": attr.label_list(
            allow_files = True,
            doc = "Additional resource files to bundle, preserving their package-relative path.",
        ),
        "headers": attr.string_dict(
            doc = "Custom manifest headers to emit verbatim (properties) or as top-level JSON " +
                  "fields (3.x manifest).",
        ),
        "description": attr.string(
            default = "",
            doc = "OSGi Bundle-Description. Only emitted when non-empty.",
        ),
        "group": attr.string(
            default = "",
            doc = "OSGi Bundle-Group. Only emitted when non-empty.",
        ),
        "filename": attr.string(
            default = "",
            doc = "Output zip file base name. Defaults to the target name. A trailing .zip is " +
                  "normalized away.",
        ),
        "no_activator": attr.bool(
            default = False,
            doc = "When True, ship a bundle with no activator library, making 'activator' optional.",
        ),
    },
)

# Exported for the macro in celix/bundle.bzl
celix_bundle_impl = _celix_bundle_rule
