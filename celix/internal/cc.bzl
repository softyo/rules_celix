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

def create_activator_shared_library(name, srcs, deps, copts, linkopts, includes, **kwargs):
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
        **kwargs: Attributes forwarded to both generated targets (tags, visibility, testonly).

    Returns:
        str: the name of the generated cc_shared_library.
    """
    cc_library(
        name = name + "_activator_lib",
        srcs = srcs,
        deps = deps,
        copts = copts,
        linkopts = linkopts,
        includes = includes,
        **kwargs
    )
    cc_shared_library(
        name = name + "_activator",
        deps = [":" + name + "_activator_lib"],
        **kwargs
    )
    return name + "_activator"
