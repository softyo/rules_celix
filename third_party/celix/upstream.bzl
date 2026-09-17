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

"""bzlmod module extension that pins the Apache Celix framework and its
hermetic native dependencies (zlib, libzip) as external repositories.

The Celix framework (and its `libs/utils`) hard-requires libzip and libuuid;
libzip in turn needs zlib for DEFLATE support. None of these are vendored in the
Celix tarball, so we fetch and build them natively here. libuuid's tiny surface
(three RFC 4122 routines) is provided by the checked-in `//third_party/celix/uuid`
package rather than a full system libuuid install.

Pinning upstream versions here means a future bump is a single edit: update the
`*_VERSION` / `*_SHA256` / url and the checked-in BUILD/config templates.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# --- Apache Celix framework --------------------------------------------------
# Latest 2.x release tag. A 3.x pin would switch the manifest format to JSON and
# require changing `//celix:default_runtime`, which is out of scope (#4).
CELIX_VERSION = "2.4.0"
CELIX_TAG = "rel/celix-" + CELIX_VERSION
CELIX_URL = "https://github.com/apache/celix/archive/refs/tags/" + CELIX_TAG + ".tar.gz"
CELIX_SHA256 = "6dfe5eeea63d81fe9d1d7832a7ebb1915974ab0f3281422af74ec17d9644e7c0"

# The GitHub tag tarball extracts to `celix-rel-celix-2.4.0/` (tag contains a `/`).
CELIX_STRIP_PREFIX = "celix-rel-celix-2.4.0"

# --- zlib --------------------------------------------------------------------
ZLIB_VERSION = "1.3.1"
ZLIB_URL = "https://github.com/madler/zlib/releases/download/v" + ZLIB_VERSION + "/zlib-" + ZLIB_VERSION + ".tar.gz"
ZLIB_SHA256 = "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"
ZLIB_STRIP_PREFIX = "zlib-" + ZLIB_VERSION

# --- libzip ------------------------------------------------------------------
LIBZIP_VERSION = "1.10.1"
LIBZIP_URL = "https://libzip.org/download/libzip-" + LIBZIP_VERSION + ".tar.gz"
LIBZIP_SHA256 = "9669ae5dfe3ac5b3897536dc8466a874c8cf2c0e3b1fdd08d75b273884299363"
LIBZIP_STRIP_PREFIX = "libzip-" + LIBZIP_VERSION

def _celix_deps_impl(mctx):
    http_archive(
        name = "celix",
        url = CELIX_URL,
        sha256 = CELIX_SHA256,
        strip_prefix = CELIX_STRIP_PREFIX,
        build_file = "//third_party/celix:framework.BUILD",
        # Injects the header files that Celix's CMake normally generates at
        # configure time (export macros + error constants) into the include tree.
        patches = ["//third_party/celix:generated_headers.patch"],
        patch_args = ["-p1"],
    )

    http_archive(
        name = "zlib",
        url = ZLIB_URL,
        sha256 = ZLIB_SHA256,
        strip_prefix = ZLIB_STRIP_PREFIX,
        build_file = "//third_party/zlib:zlib.BUILD",
    )

    http_archive(
        name = "libzip",
        url = LIBZIP_URL,
        sha256 = LIBZIP_SHA256,
        strip_prefix = LIBZIP_STRIP_PREFIX,
        build_file = "//third_party/libzip:libzip.BUILD",
        # Injects the platform config headers (config.h / zipconf.h) that libzip's
        # CMake normally generates into lib/, where zipint.h expects them.
        patches = ["//third_party/libzip:configs.patch"],
        patch_args = ["-p1"],
    )

celix_deps = module_extension(implementation = _celix_deps_impl)
