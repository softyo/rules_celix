# Native Bazel build for libzip 1.10.1.
#
# This file is used as the `build_file` overlay for the `@libzip` http_archive
# (see third_party/celix/upstream.bzl). It builds the core zip reading/writing
# functionality (including DEFLATE via @zlib and traditional PKWARE) while
# excluding optional subsystems that would drag in OpenSSL/GnuTLS/mbedTLS,
# CommonCrypto, bzip2/xz/zstd, and all Windows-only sources.
#
# `config.h` and `zipconf.h` are the hand-authored platform config headers kept
# in this rules_celix package (third_party/libzip/) and injected into lib/ by
# the `configs.patch` applied in third_party/celix/upstream.bzl.

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "libzip",
    srcs = glob(
        ["lib/zip_*.c"],
        exclude = [
            "lib/zip_algorithm_bzip2.c",
            "lib/zip_algorithm_xz.c",
            "lib/zip_algorithm_zstd.c",
            "lib/zip_crypto_commoncrypto.c",
            "lib/zip_crypto_gnutls.c",
            "lib/zip_crypto_mbedtls.c",
            "lib/zip_crypto_openssl.c",
            "lib/zip_crypto_win.c",
            "lib/zip_random_uwp.c",
            "lib/zip_random_win32.c",
            "lib/zip_source_file_win32.c",
            "lib/zip_source_file_win32_ansi.c",
            "lib/zip_source_file_win32_named.c",
            "lib/zip_source_file_win32_utf16.c",
            "lib/zip_source_file_win32_utf8.c",
            "lib/zip_source_winzip_aes_decode.c",
            "lib/zip_source_winzip_aes_encode.c",
            "lib/zip_winzip_aes.c",
        ],
    ),
    hdrs = glob(["lib/*.h"]),
    includes = ["lib"],
    deps = ["@zlib"],
    copts = select({
        "@platforms//os:macos": ["-D_FILE_OFFSET_BITS=64"],
        "//conditions:default": [],
    }),
)
