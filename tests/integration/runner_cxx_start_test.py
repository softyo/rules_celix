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

"""Integration test: the runner auto-starts a real-Celix C++ bundle.

Boots `test_container_start_cxx` (a level-1 container whose activator is a C++
bundle using `CELIX_GEN_CXX_BUNDLE_ACTIVATOR` — the `celix::impl::createActivator`
path that used to ODR-crash when the bundle embedded its own static framework
copy, issue #13), collects stdout, asserts the fixed CXX marker line appears
without the framework crashing, then writes `STOP_RUNNER=1` and asserts the
runner exits 0.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import time

CXX_MARKER = "rules_celix start-order: cxx"

STOP_LINE = "STOP_RUNNER=1"


def fail(msg):
    """Print a failure message and exit non-zero."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 3:
        fail(
            "Usage: runner_cxx_start_test.py <config.properties_rootpath> "
            "<runner_filename>",
        )

    config_path = sys.argv[1]
    runner_filename = sys.argv[2]

    if not os.path.isfile(config_path):
        fail("Config not found: %s" % config_path)

    runtime_dir = os.path.dirname(config_path)
    if not os.path.isdir(runtime_dir):
        fail("Runtime directory not found: %s" % runtime_dir)

    runner = os.path.join(
        os.path.dirname(os.path.dirname(config_path)),
        runner_filename,
    )
    if not os.path.isfile(runner):
        fail("Runner not found: %s" % runner)

    with tempfile.TemporaryDirectory(prefix="rules_celix_cxx_") as workdir:
        for entry in os.listdir(runtime_dir):
            src = os.path.join(runtime_dir, entry)
            dst = os.path.join(workdir, entry)
            if os.path.isdir(src):
                shutil.copytree(src, dst)
            else:
                shutil.copyfile(src, dst)

        copied_config = os.path.join(workdir, "config.properties")
        config_body = open(copied_config, "r").read()
        if "CELIX_AUTO_START_1=bundles/com.example.start_order_cxx.zip" not in config_body:
            fail("Copied config is missing the level-1 autostart entry for the cxx bundle")

        proc = subprocess.Popen(
            [runner, workdir],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        seen = False
        rc = None
        try:
            deadline = time.time() + 120
            while time.time() < deadline:
                line = proc.stdout.readline()
                if not line:
                    break
                if CXX_MARKER in line:
                    seen = True
                    break
                print(line, end="")

            if not seen:
                proc.kill()
                fail(
                    "Runner did not start the C++ bundle; marker '%s' not seen "
                    "(framework probably crashed during autostart)" % CXX_MARKER,
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

    print("PASS: C++ bundle auto-started via the runner's single framework "
          "instance; runner exited cleanly on STOP_RUNNER=1.")


if __name__ == "__main__":
    main()