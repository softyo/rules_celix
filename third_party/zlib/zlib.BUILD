# Native Bazel build for zlib 1.3.
#
# This file is used as the `build_file` overlay for the `@zlib` http_archive
# (see third_party/celix/upstream.bzl). The zlib release tarball ships a
# pre-generated zconf.h, so no configure step is required for a native build.

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "zlib",
    srcs = [
        "adler32.c",
        "compress.c",
        "crc32.c",
        "deflate.c",
        "gzclose.c",
        "gzlib.c",
        "gzread.c",
        "gzwrite.c",
        "infback.c",
        "inffast.c",
        "inflate.c",
        "inftrees.c",
        "trees.c",
        "uncompr.c",
        "zutil.c",
    ],
    hdrs = [
        "crc32.h",
        "deflate.h",
        "gzguts.h",
        "inffast.h",
        "inffixed.h",
        "inflate.h",
        "inftrees.h",
        "trees.h",
        "zconf.h",
        "zlib.h",
        "zutil.h",
    ],
    includes = ["."],
    copts = [
        "-DZLIB_CONST",
    ] + select({
        # zconf.h only includes <unistd.h> / <stdlib.h> when Z_HAVE_UNISTD_H is
        # defined; upstream derives this from its configure/CMake check. gz*.c
        # call read()/close()/open() directly, so the flag is required on the
        # POSIX platforms (Apple clang errors on implicit declarations).
        "@platforms//os:linux": ["-DZ_HAVE_UNISTD_H"],
        "@platforms//os:macos": ["-DZ_HAVE_UNISTD_H"],
        "//conditions:default": [],
    }),
)
