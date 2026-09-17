#ifndef CELIX_UTILS_EXPORT_H
#define CELIX_UTILS_EXPORT_H

/*
 * Hand-authored stand-in for the header normally produced by CMake's
 * generate_export_header(utils). See celix_framework_export.h for rationale —
 * all macros are empty because the library is compiled statically in Bazel.
 */

#ifdef CELIX_UTILS_STATIC_DEFINE
#  define CELIX_UTILS_EXPORT
#  define CELIX_UTILS_NO_EXPORT
#else
#  ifndef CELIX_UTILS_EXPORT
#    ifdef celix_utils_EXPORTS
#      define CELIX_UTILS_EXPORT
#    else
#      define CELIX_UTILS_EXPORT
#    endif
#  endif
#  ifndef CELIX_UTILS_NO_EXPORT
#    define CELIX_UTILS_NO_EXPORT
#  endif
#endif

#ifndef CELIX_UTILS_DEPRECATED
#  define CELIX_UTILS_DEPRECATED
#endif
#ifndef CELIX_UTILS_DEPRECATED_EXPORT
#  define CELIX_UTILS_DEPRECATED_EXPORT CELIX_UTILS_EXPORT
#endif
#ifndef CELIX_UTILS_DEPRECATED_NO_EXPORT
#  define CELIX_UTILS_DEPRECATED_NO_EXPORT CELIX_UTILS_NO_EXPORT
#endif

#ifndef CELIX_UTILS_DEFINE_NO_DEPRECATED
#  define CELIX_UTILS_DEFINE_NO_DEPRECATED
#endif

#endif /* CELIX_UTILS_EXPORT_H */
