# hello_container — runnable Celix container example

This example assembles the C and C++ hello bundles (`//examples/hello_c:hello_bundle` and `//examples/hello_cxx:hello_bundle`) into one **runnable** Celix container.
The `celix_container` macro emits a copy of the shared runner binary (`@rules_celix//tools:container_runner`, built once in the rules_celix repository with the framework embedded), the generated `config.properties`, the copied bundle zips, and a launcher, so `bazel run` boots the real Celix framework against the container layout without any consumer-side `@celix`.

## Runtime layout

`bazel build //examples/hello_container` produces a container tree like this (replace `<package>` with `bazel-bin/examples/hello_container`):

```
<package>/
├── hello_container                          # launcher (executed by bazel run)
├── hello_container_runner                   # copy of the shared runner (embeds the Celix framework)
└── hello_container_runtime/                 # the container's runtime directory
    ├── config.properties                    # generated framework configuration
    └── bundles/
        ├── org.example.hello.zip            # C hello bundle (auto-started, level 1)
        └── org.example.hello_cxx.zip        # C++ hello bundle (install-only, never started)
```

Under `bazel run` the process working directory is the container's package directory, and the launcher passes `hello_container_runtime/` to the runner, so the framework loads `config.properties` and the `bundles/` directory relative to it. The generated `config.properties` is deterministic and carries the bundles' start levels:

```
CELIX_BUNDLES_PATH=bundles
CELIX_FRAMEWORK_CACHE_DIR=.cache
CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true
CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info
CELIX_AUTO_START_1=bundles/org.example.hello.zip
CELIX_AUTO_INSTALL=bundles/org.example.hello_cxx.zip
```

`CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true` keeps repeated runs clean: the framework cache lives in `/tmp` and is deleted on destroy, never touching the runfiles tree.

The framework installs all bundles first, then starts them in ascending start-level order. Here the C `hello_bundle` (level 1) is auto-started, and the C++ `hello_bundle` is installed without starting (`CELIX_AUTO_INSTALL`).

## Running

```bash
bazel run //examples/hello_container
```

You will see the C hello bundle's marker (and the runner's sentinel):

```
Hello from bundle id 1
[ ... ] [   info] [celix_framework] rules_celix container runner started
```

The runner is synchronous: it blocks until it receives SIGINT/SIGTERM (Ctrl-C) or until `STOP_RUNNER=1` appears in the active `config.properties` (re-checked on a timer), then stops the framework and exits 0.
One `bazel run` invocation is enough for the whole lifecycle.
To use the file-marker stop, stop the process with Ctrl-C, edit a copy of the config and relaunch the runner with the directory as its argument:

```bash
# From the container's package dir under bazel-bin:
./hello_container_runner /path/to/container_runtime
# in another shell:  echo STOP_RUNNER=1 >> /path/to/container_runtime/config.properties
```

The runner copy is a real file, so this works unchanged from a copied tree.

## start.sh

The macro also emits `<name>_start_sh` — an `sh_binary` wrapper that `cd`s to its own directory and execs the container runner.
It works from inside a build tree and is the shape a future distributable tarball step reuses:

```bash
bazel run //examples/hello_container:hello_container_start_sh
```

## Limitations

- There is **no distributable tarball yet**; the container tree is built under `bazel-bin` and usable via `bazel run` or the `start_sh` wrapper.
- Start levels are limited to Celix's seven fixed levels `0..6` (Karaf style, ascending start / reverse stop). `install_only = [...]` bundles are installed but never started.
- The C++ hello bundle is **installed but not started** here: C++ activators built with the current ruleset embed their own static copy of the Celix framework, which clashes with the runner's framework instance at runtime (a pre-existing limitation, tracked outside this milestone). The C hello bundle is the auto-started demonstration.
