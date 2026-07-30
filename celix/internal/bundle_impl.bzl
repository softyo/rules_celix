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

load("//celix:providers.bzl", "CelixBundleInfo")
load("//celix/internal:manifest.bzl", "generate_manifest")
load("//celix/internal:zip.bzl", "create_bundle_zip")

def _get_shared_library_file(library_target):
    """Extract the .so/.dylib output from a cc_shared_library target.

    Tries CcSharedLibraryInfo first (Bazel 7+), then falls back to
    searching DefaultInfo.files for the dynamic library artifact.
    """

    # Prefer the dedicated provider when available.
    if CcSharedLibraryInfo in library_target:
        info = library_target[CcSharedLibraryInfo]

        # CcSharedLibraryInfo carries a list of libraries.
        libs = info.libraries_to_link.to_list() if hasattr(info, "libraries_to_link") else []
        if libs:
            return libs[0].dynamic_library

    # Fallback: hunt through DefaultInfo for the .so/.dylib.
    for f in library_target[DefaultInfo].files.to_list():
        if f.extension in ("so", "dylib", "dll"):
            return f

    fail("Could not locate a shared library (.so/.dylib/.dll) in target %s" % library_target.label)

def _celix_bundle_impl_fn(ctx):
    library_file = _get_shared_library_file(ctx.attr.activator)
    manifest = generate_manifest(ctx)
    zip_file = create_bundle_zip(ctx, library_file, manifest, ctx.executable._zip_tool)

    bundle_name = ctx.attr.bundle_name if ctx.attr.bundle_name else ctx.attr.symbolic_name

    return [
        DefaultInfo(files = depset([zip_file])),
        CelixBundleInfo(
            bundle = zip_file,
            symbolic_name = ctx.attr.symbolic_name,
            bundle_name = bundle_name,
            version = ctx.attr.version,
            activator = library_file,
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
            mandatory = True,
            providers = [CcSharedLibraryInfo],
            doc = "The cc_shared_library containing the activator.",
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
    },
)

# Exported for the macro in celix/bundle.bzl
celix_bundle_impl = _celix_bundle_rule
