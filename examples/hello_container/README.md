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
        ├── org.example.hello.zip            # C hello bundle (byte-identical copy)
        └── org.example.hello_cxx.zip        # C++ hello bundle
```

Under `bazel run` the process working directory is the container's package directory, and the launcher passes `hello_container_runtime/` to the runner, so the framework loads `config.properties` and the `bundles/` directory relative to it. The generated `config.properties` is minimal and hermetic:

```
CELIX_BUNDLES_PATH=bundles
CELIX_FRAMEWORK_CACHE_DIR=.cache
CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true
CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info
```

`CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true` keeps repeated runs clean: the framework cache lives in `/tmp` and is deleted on destroy, never touching the runfiles tree.

## Running

```bash
bazel run //examples/hello_container
```

You will see the framework boot and the runner's sentinel line:

```
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

- The bundles are **not yet auto-started**.
  This milestone ships the runner, the config, and the correct layout, but the framework does not install or start the runfiles' bundles yet.
  Bundle start levels (`CELIX_AUTO_START_0..6` / `CELIX_AUTO_INSTALL`) arrive in a later step.
- There is **no distributable tarball yet**; the container tree is built under `bazel-bin` and usable via `bazel run` or the `start_sh` wrapper.
