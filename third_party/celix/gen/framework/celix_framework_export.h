#ifndef CELIX_FRAMEWORK_EXPORT_H
#define CELIX_FRAMEWORK_EXPORT_H

/*
 * Hand-authored stand-in for the header normally produced by CMake's
 * generate_export_header(framework). In the native Bazel build the framework is
 * compiled as a static archive whose objects are linked directly into a bundle
 * activator shared library, so no symbols need default-visibility attributes —
 * all export/import macros are therefore empty.
 *
 * Keep in sync with the framework target in third_party/celix/framework.BUILD.
 */

#ifdef CELIX_FRAMEWORK_STATIC_DEFINE
#  define CELIX_FRAMEWORK_EXPORT
#  define CELIX_FRAMEWORK_NO_EXPORT
#else
#  ifndef CELIX_FRAMEWORK_EXPORT
#    ifdef celix_framework_EXPORTS
        /* We are building this library */
#      define CELIX_FRAMEWORK_EXPORT
#    else
        /* We are using this library */
#      define CELIX_FRAMEWORK_EXPORT
#    endif
#  endif
#  ifndef CELIX_FRAMEWORK_NO_EXPORT
#    define CELIX_FRAMEWORK_NO_EXPORT
#  endif
#endif

#ifndef CELIX_FRAMEWORK_DEPRECATED
#  define CELIX_FRAMEWORK_DEPRECATED
#endif
#ifndef CELIX_FRAMEWORK_DEPRECATED_EXPORT
#  define CELIX_FRAMEWORK_DEPRECATED_EXPORT CELIX_FRAMEWORK_EXPORT
#endif
#ifndef CELIX_FRAMEWORK_DEPRECATED_NO_EXPORT
#  define CELIX_FRAMEWORK_DEPRECATED_NO_EXPORT CELIX_FRAMEWORK_NO_EXPORT
#endif

#ifndef CELIX_FRAMEWORK_DEFINE_NO_DEPRECATED
#  define CELIX_FRAMEWORK_DEFINE_NO_DEPRECATED
#endif

#endif /* CELIX_FRAMEWORK_EXPORT_H */
