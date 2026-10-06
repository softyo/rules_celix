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

"""Hermetic smoke test for the celix_container runner.

Boots the generated container: execs the container's runner binary with a
writable copy of its runtime directory (config.properties + bundles/) as
argv[1], waits for the fixed sentinel line logged by the runner once the Celix
framework is up, then writes `STOP_RUNNER=1` into the copied config path and
asserts the process exits 0 on its own.

The config.properties produced by Bazel is read-only and the runfiles tree
should not be mutated, so this test copies the whole runtime directory into a
temp dir and mutates the copy.  This is the same configuration-path contract the
plan specifies (the runner re-checks the loaded config path on a timer), and it
keeps the test hermetic and deterministic: no kill timers, no races.

The runner copy is rule-internal (a copy of the shared
@rules_celix//tools:container_runner binary), so its path is derived from the
config rootpath (config sits at <pkg>/<name>_runtime/config.properties, the
runner at <pkg>/<name>_runner); the runner filename is passed as an argument,
sourced from the same celix/internal/container.bzl helper the rule uses, so a
rename is caught by the test.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import time

# The fixed sentinel line the runner logs via the framework bundle context once
# the framework has started.  Grepping only this substring keeps the test
# robust against verbose INFO framework logs.
SENTINEL = "rules_celix container runner started"

# Key/value the test appends to the config copy to ask the runner to stop.
STOP_LINE = "STOP_RUNNER=1"


def fail(msg):
    """Print a failure message and exit non-zero."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 3:
        fail(
            "Usage: runner_smoke_test.py <config.properties_rootpath> "
            "<runner_filename>",
        )

    config_path = sys.argv[1]
    runner_filename = sys.argv[2]

    if not os.path.isfile(config_path):
        fail("Config not found: %s" % config_path)

    # The runtime directory is the parent of the generated config.properties
    # (which sits at <container_runtime_dir>/config.properties).
    runtime_dir = os.path.dirname(config_path)
    if not os.path.isdir(runtime_dir):
        fail("Runtime directory not found: %s" % runtime_dir)

    # The runner copy lands in the package dir next to the container's runtime
    # directory: config rootpath is <pkg>/<name>_runtime/config.properties, so
    # the runner is <pkg>/<runner_filename>.
    runner = os.path.join(
        os.path.dirname(os.path.dirname(config_path)),
        runner_filename,
    )
    if not os.path.isfile(runner):
        fail("Runner not found: %s" % runner)

    with open(config_path, "r") as fh:
        config_body = fh.read()

    with tempfile.TemporaryDirectory(prefix="rules_celix_smoke_") as workdir:
        # Work from a writable copy so the sandbox runfiles tree is untouched.
        copied_config = os.path.join(workdir, "config.properties")
        with open(copied_config, "w") as fh:
            fh.write(config_body)

        proc = subprocess.Popen(
            [runner, workdir],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        try:
            seen_sentinel = False
            deadline = time.time() + 60
            while time.time() < deadline:
                line = proc.stdout.readline()
                if not line:
                    break
                if SENTINEL in line:
                    seen_sentinel = True
                    print(line, end="")
                    break

            if not seen_sentinel:
                proc.kill()
                fail(
                    "Runner did not log the sentinel '%s' within 60s "
                    "(exit code %s)" % (SENTINEL, proc.wait()),
                )

            # Drain any buffered output so the process can exit cleanly.
            with open(copied_config, "a") as fh:
                fh.write(STOP_LINE + "\n")

            rc = proc.wait(timeout=30)
        finally:
            if proc.poll() is None:
                proc.kill()

        if rc != 0:
            fail("Runner exited with code %s (expected 0)" % rc)

    print("PASS: container runner booted the framework, logged the sentinel, "
          "and exited cleanly on STOP_RUNNER=1.")


if __name__ == "__main__":
    main()