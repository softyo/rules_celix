// Copyright 2026 SOFTYONARY SL
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Hermetic runner binary for a celix_container (issue #8).
//
// A container is a runtime directory holding `config.properties`, a `bundles/`
// directory, and this executable. When `bazel run` launches the container the
// generated launcher passes that directory as `argv[1]`; the runner chdirs into
// it, so the process working directory IS the container directory and all
// relative paths (`CELIX_BUNDLES_PATH=bundles`, the framework cache, ...)
// resolve against it. With no argument the runner uses `.` as the directory.
//
// The runner is deliberately minimal and synchronous:
//   - chdirs into the container directory and loads the framework configuration
//     from `config.properties`,
//   - creates (and starts) the Celix framework via
//     celix_frameworkFactory_createFramework,
//   - logs the fixed sentinel line
//     "rules_celix container runner started" through the framework bundle
//     context (the smoke test waits for exactly this substring),
//   - waits until either a stop signal arrives (SIGINT/SIGTERM) or the line
//     "STOP_RUNNER=1" appears in the loaded config path (re-checked on a
//     timer); then destroys the framework and exits 0.
//
// It does NOT install or start any bundle itself: the generated
// config.properties carries the CELIX_AUTO_START_* and CELIX_AUTO_INSTALL
// keys, and the framework's own autostart machinery performs the install and
// start, so the runner stays a thin embedding shell.

#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <celix_bundle_context.h>
#include <celix_framework.h>
#include <celix_framework_factory.h>
#include <celix_properties.h>

// Fixed sentinel line emitted at INFO level right after the framework starts.
// The integration smoke test greps for exactly this substring.
#define RUNNER_SENTINEL "rules_celix container runner started"

// Sentinel-adjacent marker the smoke test writes into the loaded config file
// (a runfiles-adjacent space, never the source tree) to ask the runner to stop
// cleanly. Re-checked on a timer, so one `bazel run` invocation is enough for
// the whole lifecycle without kill races.
#define STOP_RUNNER_KEY "STOP_RUNNER"
#define STOP_RUNNER_VALUE "1"

// Poll interval in seconds for STOP_RUNNER re-checks.
#define STOP_POLL_SECONDS 1

static const char *g_config_dir = ".";
static volatile sig_atomic_t g_stop_requested = 0;

static void handle_stop_signal(int sig) {
    (void)sig;
    g_stop_requested = 1;
}

static bool should_stop(void) {
    if (g_stop_requested) {
        return true;
    }

    // The runner chdir'd into the config directory before creating the
    // framework, so the config is always at "./config.properties".
    FILE *fh = fopen("config.properties", "r");
    if (fh == NULL) {
        // The config is gone; treat that as a stop request so a torn-down
        // runfiles tree does not wedge a bazel run.
        return true;
    }

    char line[512];
    bool found = false;
    while (fgets(line, sizeof(line), fh) != NULL) {
        char *eq = strchr(line, '=');
        if (eq == NULL) {
            continue;
        }
        *eq = '\0';
        char *key = line;
        char *value = eq + 1;
        // Trim trailing newline/carriage return.
        value[strcspn(value, "\r\n")] = '\0';
        if (strcmp(key, STOP_RUNNER_KEY) == 0 &&
            strcmp(value, STOP_RUNNER_VALUE) == 0) {
            found = true;
            break;
        }
    }
    fclose(fh);
    return found;
}

int main(int argc, char **argv) {
    if (argc > 2) {
        fprintf(stderr, "usage: %s [container-directory]\n", argv[0]);
        return 1;
    }
    if (argc == 2) {
        g_config_dir = argv[1];
    }

    if (chdir(g_config_dir) != 0) {
        fprintf(stderr, "failed to chdir to config dir: %s\n", g_config_dir);
        return 1;
    }

    // The container directory is now the CWD; the config always lives at
    // "./config.properties" relative to it.
    celix_properties_t *properties = celix_properties_load("config.properties");
    if (properties == NULL) {
        fprintf(stderr, "failed to load framework config in %s\n", g_config_dir);
        return 1;
    }

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handle_stop_signal;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    celix_framework_t *framework = celix_frameworkFactory_createFramework(properties);
    if (framework == NULL) {
        fprintf(stderr, "failed to create Celix framework\n");
        return 1;
    }

    celix_bundle_context_t *fw_context = celix_framework_getFrameworkContext(framework);
    celix_bundleContext_log(fw_context, CELIX_LOG_LEVEL_INFO, RUNNER_SENTINEL);

    while (!should_stop()) {
        struct timespec ts;
        ts.tv_sec = STOP_POLL_SECONDS;
        ts.tv_nsec = 0;
        nanosleep(&ts, NULL);
    }

    celix_frameworkFactory_destroyFramework(framework);
    return 0;
}