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

"""Shared-library helpers for Celix bundle packaging."""

load("@rules_cc//cc:defs.bzl", "cc_library", "cc_shared_library")

# Linker flags for `framework = "runtime"` activator shared libraries on macOS.
#
# Runtime-mode activators are linked against the headers-only `@celix//:framework`,
# so every `celix_*` / `celix_utils_*` symbol stays unresolved in the bundle's
# `.dylib`. On Linux, GNU ld allows that by default; ld64 (macOS) rejects it
# unless the link uses `-undefined dynamic_lookup`, the canonical plugin pattern:
# the symbols are marked unresolved until dlopen, at which point dyld binds them
# against the container runner's `-export_dynamic` symbol table.
_RUNTIME_MACOS_LINKOPTS = select({
    "@platforms//os:macos": ["-Wl,-undefined,dynamic_lookup"],
    "//conditions:default": [],
})

def get_shared_library_file(library_target):
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

def create_activator_shared_library(name, srcs, deps, copts, linkopts, includes, framework = "runtime", **kwargs):
    """Define the cc_library + cc_shared_library pair backing a bundle macro.

    The cc_library (named `<name>_activator_lib`) compiles `srcs`; the cc_shared_library
    (named `<name>_activator`) produces the loadable `lib<name>_activator.so`/`.dylib`.

    Args:
        name (str): Bundle target name (prefix for the generated targets).
        srcs (list of Label): C/C++ sources of the activator.
        deps (list of Label): cc_library deps.
        copts (list of str): Compiler options forwarded to the cc_library.
        linkopts (list of str): Linker options forwarded to the cc_library.
        includes (list of str): Include paths forwarded to the cc_library.
        framework (str): Celix framework link mode — `"runtime"` (default) keeps
            the activator linked against the headers-only framework so every
            `celix_*` symbol stays unresolved and binds against the container
            runner's exported framework instance at dlopen time (the fix for
            issue #13's C++ ODR crash); on macOS the generated `cc_shared_library`
            is linked with `-Wl,-undefined,dynamic_lookup` so ld64 accepts those
            undefined symbols. `"static"` embeds the framework archive
            for self-contained .so bundles outside a runner.
        **kwargs: Attributes forwarded to both generated targets (tags, visibility, testonly).

    Returns:
        str: the name of the generated cc_shared_library.
    """
    effective_deps = deps
    user_link_flags = []
    if framework == "runtime":
        effective_deps = deps + ["@rules_celix//third_party/celix:framework"]

        # ld64 rejects undefined symbols in a dylib by default; runtime-mode
        # activators rely on them, so allow them on macOS (no-op elsewhere).
        user_link_flags = _RUNTIME_MACOS_LINKOPTS
    elif framework == "static":
        effective_deps = deps + ["@rules_celix//third_party/celix:framework_static"]
    else:
        fail(
            "create_activator_shared_library: invalid framework mode '%s' — " % framework +
            "expected \"runtime\" or \"static\"",
        )

    cc_library(
        name = name + "_activator_lib",
        srcs = srcs,
        deps = effective_deps,
        copts = copts,
        linkopts = linkopts,
        includes = includes,
        **kwargs
    )
    cc_shared_library(
        name = name + "_activator",
        deps = [":" + name + "_activator_lib"],
        user_link_flags = user_link_flags,
        **kwargs
    )
    return name + "_activator"
