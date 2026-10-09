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
        └── org.example.hello_cxx.zip        # C++ hello bundle (auto-started, level 2)
```

Under `bazel run` the process working directory is the container's package directory, and the launcher passes `hello_container_runtime/` to the runner, so the framework loads `config.properties` and the `bundles/` directory relative to it. The generated `config.properties` is deterministic and carries the bundles' start levels:

```
CELIX_BUNDLES_PATH=bundles
CELIX_FRAMEWORK_CACHE_DIR=.cache
CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true
CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info
CELIX_AUTO_START_1=bundles/org.example.hello.zip
CELIX_AUTO_START_2=bundles/org.example.hello_cxx.zip
```

`CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true` keeps repeated runs clean: the framework cache lives in `/tmp` and is deleted on destroy, never touching the runfiles tree.

The framework installs all bundles first, then starts them in ascending start-level order (and stops them in reverse order on shutdown). Both examples are auto-started:
the C `hello_bundle` at level 1 and the C++ `hello_bundle` at level 2.

## Why the C++ bundle can now be auto-started

Roughly, framework resolution for containers is:

- The runner statically embeds **one** copy of the framework (`@celix//:framework_static`) and exports its `celix_*` symbols with `--export-dynamic`.
- Bundle activators use the default `framework = "runtime"` link mode: they compile against the **headers-only** `@celix//:framework` target, so their `celix_*` references stay unresolved in the `.so` and bind against the runner's single instance at dlopen time.
- A single framework instance means no duplicated C++ program state — the ODR crash that used to hit `celix::impl::createActivator` when each C++ activator embedded its own static framework copy is gone.

## Running

```bash
bazel run //examples/hello_container
```

You will see the C hello bundle's marker, the C++ hello bundle's start log, and the runner's sentinel:

```
Hello from bundle id 1
[ ... ] [   info] [celix_framework] Hello CXX activator started in bundle id 2
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
It works from inside a build tree and is reused as both the `bazel run` launcher and the tarball's `start.sh`:

```bash
bazel run //examples/hello_container:hello_container_start_sh
```

## Distributable tarball

`celix_container` also emits a deterministic, self-contained tarball (`tarball = True` is the default):

```bash
bazel build //examples/hello_container:hello_container_tarball
# → bazel-bin/examples/hello_container/hello_container.tgz
```

Ship that file to a machine **without Bazel or Celix**, extract, and run:

```bash
tar -xzf hello_container.tgz
cd hello_container
./start.sh
```

The extraction tree mirrors the `bazel run` layout exactly (`hello_container/start.sh`, `hello_container/hello_container_runner`, `hello_container/hello_container_runtime/{config.properties,bundles/*.zip}`), with deterministic mtimes/owner and no absolute build paths, so identical inputs give byte-identical archives.
The tarball is host-platform-specific (the bundles and runner are binaries for the platform they were built on).

## Limitations

- Start levels are limited to Celix's seven fixed levels `0..6` (Karaf style, ascending start / reverse stop). `install_only = [...]` bundles are installed but never started.
- A **C++ bundle** built with `framework = "static"` (framework embedded into the activator `.so`) cannot be auto-started inside a container.
  The `celix_container` rule rejects it at analysis with a clear message.
  Keep the convenience-macro default (`framework = "runtime"`) for auto-started C++ bundles, or list a static-mode C++ bundle under `install_only`.
- Our bundled `start.sh` is the **single-container** launcher; it is distinct from Celix's deprecated multi-container runtime `start.sh`/`stop.sh`/`common.sh` orchestrator (`add_celix_runtime`).
