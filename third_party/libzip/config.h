#ifndef HAD_CONFIG_H
#define HAD_CONFIG_H
#ifndef _HAD_ZIPCONF_H
#include "zipconf.h"
#endif

/* Hand-authored native build configuration for libzip 1.10.1.
 * Targets 64-bit POSIX (Linux glibc and macOS). */
#define ENABLE_FDOPEN
#define HAVE_FCHMOD
#define HAVE_FILENO
#define HAVE_FSEEKO
#define HAVE_FTELLO
#define HAVE_LOCALTIME_R
#define HAVE_MKSTEMP
#define HAVE_SNPRINTF
#define HAVE_STDBOOL_H
#define HAVE_STRCASECMP
#define HAVE_STRDUP
#define HAVE_STRINGS_H
#define HAVE_STRTOLL
#define HAVE_STRTOULL
#define HAVE_UNISTD_H
#define HAVE_DIRENT_H
#define HAVE_SYS_DIR_H
#define SIZEOF_OFF_T 8
#define SIZEOF_SIZE_T 8
#define PACKAGE "libzip"
#define VERSION "1.10.1"

#endif /* HAD_CONFIG_H */
