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

"""Integration test: the runner boots the framework and auto-starts bundles
in ascending start-level order.

Boots `test_container_start_order` (a two-level container whose activators
print fixed marker lines), collects stdout, asserts the level-1 marker
(`rules_celix start-order: infra`) appears strictly before the level-2 marker
(`rules_celix start-order: app`), then writes `STOP_RUNNER=1` into a writable
copy of the config and asserts the runner exits 0.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import time

# The config.properties produced by Bazel is read-only and the runfiles tree
# should not be mutated, so work from a writable copy, exactly like the smoke
# test.
SENTINEL = "rules_celix container runner started"

INFRA_MARKER = "rules_celix start-order: infra"
APP_MARKER = "rules_celix start-order: app"

STOP_LINE = "STOP_RUNNER=1"


def fail(msg):
    """Print a failure message and exit non-zero."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 3:
        fail(
            "Usage: runner_start_order_test.py <config.properties_rootpath> "
            "<runner_filename>",
        )

    config_path = sys.argv[1]
    runner_filename = sys.argv[2]

    if not os.path.isfile(config_path):
        fail("Config not found: %s" % config_path)

    runtime_dir = os.path.dirname(config_path)
    if not os.path.isdir(runtime_dir):
        fail("Runtime directory not found: %s" % runtime_dir)

    # The runner copy lands in the package dir next to the container's runtime
    # directory, exactly like the smoke test derives it.
    runner = os.path.join(
        os.path.dirname(os.path.dirname(config_path)),
        runner_filename,
    )
    if not os.path.isfile(runner):
        fail("Runner not found: %s" % runner)

    with tempfile.TemporaryDirectory(prefix="rules_celix_start_order_") as workdir:
        # The framework needs a writable copy of the whole runtime dir (config
        # is re-checked on a timer and bundle zips are installed from bundles/).
        for entry in os.listdir(runtime_dir):
            src = os.path.join(runtime_dir, entry)
            dst = os.path.join(workdir, entry)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                # copyfile (not copy/copy2): the runfiles config.properties is
                # read-only in bazel-out; the copy must stay writable so the
                # test can append STOP_RUNNER=1.
                shutil.copyfile(src, dst)

        copied_config = os.path.join(workdir, "config.properties")
        config_body = open(copied_config, "r").read()
        if "CELIX_AUTO_START_1=bundles/com.example.start_order_infra.zip" not in config_body:
            fail("Copied config is missing the level-1 autostart entry for the infra bundle")
        if "CELIX_AUTO_START_2=bundles/com.example.start_order_app.zip" not in config_body:
            fail("Copied config is missing the level-2 autostart entry for the app bundle")

        proc = subprocess.Popen(
            [runner, workdir],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        order = []
        rc = None
        try:
            deadline = time.time() + 120
            while time.time() < deadline:
                line = proc.stdout.readline()
                if not line:
                    break
                if INFRA_MARKER in line and INFRA_MARKER not in order:
                    order.append(INFRA_MARKER)
                if APP_MARKER in line and APP_MARKER not in order:
                    order.append(APP_MARKER)
                print(line, end="")
                if set(order) == {INFRA_MARKER, APP_MARKER}:
                    break

            if set(order) != {INFRA_MARKER, APP_MARKER}:
                proc.kill()
                fail(
                    "Runner did not start both bundles; markers seen in order %s "
                    "(waiting for '%s' / '%s')" % (order, INFRA_MARKER, APP_MARKER),
                )

            if order.index(INFRA_MARKER) > order.index(APP_MARKER):
                proc.kill()
                fail(
                    "Start order violated: level-2 marker '%s' appeared before "
                    "level-1 marker '%s' (order seen: %s)" %
                    (APP_MARKER, INFRA_MARKER, order),
                )

            # Ask the runner to stop cleanly, then assert a clean exit.
            with open(copied_config, "a") as fh:
                fh.write(STOP_LINE + "\n")

            rc = proc.wait(timeout=30)
        finally:
            if proc.poll() is None:
                proc.kill()

        if rc != 0:
            fail("Runner exited with code %s (expected 0)" % rc)

    print("PASS: level-1 bundle started before level-2 bundle; "
          "runner exited cleanly on STOP_RUNNER=1.")


if __name__ == "__main__":
    main()