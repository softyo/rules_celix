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

"""Integration test: the distributable tarball runs on a host without Bazel.

Builds the container's `<name>_tarball` target, extracts the resulting
`<name>.tgz` with Python's stdlib `tarfile` (no Bazel, no `tar`, no runner
runfiles — proving the artifact is self-contained), asserts the expected
extraction layout, and boots the container from the extracted tree by running
`./start.sh`, then asks the runner to exit cleanly via STOP_RUNNER=1.

The tarball's start.sh is the same launcher the macro generates for `bazel
run` (`cd $SCRIPT_DIR; exec ./<name>_runner <name>_runtime`), so running it
from the extracted `<name>/` directory exercises the exact no-Bazel path.
"""

import os
import select
import subprocess
import sys
import tarfile
import tempfile
import time


class PipeReader:
    """Deadline-aware line reader over a subprocess stdout pipe.

    Reads the raw file descriptor instead of the TextIOWrapper: mixing
    `select` on the wrapper with `readline()` over-reads the pipe into
    Python's stdio buffer, and the buffered sentinel is then invisible to
    `select`, hanging the test even though the runner is healthy.  `readline`
    returns the next line (without its trailing newline), `None` at EOF, and
    raises `TimeoutError` when `timeout` seconds elapse without a full line.
    """

    def __init__(self, proc, timeout):
        self._fd = proc.stdout.fileno()
        self._buf = b""
        self._timeout = timeout
        self._deadline = time.time() + timeout
        os.set_blocking(self._fd, False)

    def readline(self):
        while b"\n" not in self._buf:
            if time.time() >= self._deadline:
                raise TimeoutError(
                    "no output from the child within %ds" % self._timeout,
                )
            readable, _, _ = select.select([self._fd], [], [], 1.0)
            if not readable:
                continue
            try:
                chunk = os.read(self._fd, 65536)
            except (BlockingIOError, InterruptedError):
                continue
            if not chunk:
                if self._buf:
                    line = self._buf.decode(errors="replace")
                    self._buf = b""
                    return line
                return None
            self._buf += chunk
        raw, self._buf = self._buf.split(b"\n", 1)
        return raw.decode(errors="replace")

# The fixed sentinel line the runner logs via the framework bundle context once
# the framework has started.  Grepping only this substring keeps the test
# robust against verbose INFO framework logs.
SENTINEL = "rules_celix container runner started"

# Key/value the test appends to the extracted config to ask the runner to stop.
STOP_LINE = "STOP_RUNNER=1"

SENTINEL_TIMEOUT = 120
STOP_TIMEOUT = 30


def fail(msg):
    """Print a failure message and exit non-zero."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def drain_until_stop(proc, reader, timeout=STOP_TIMEOUT):
    """Read the runner's stdout until it exits after STOP_RUNNER=1.

    Prints lines as they arrive and bounds the wait with a deadline: a runner
    stuck after the stop marker must not mask an earlier failure with a second
    long hang.  Returns the exit code of a clean (or EOF-reached) exit.
    """
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            line = reader.readline()
        except TimeoutError:
            break
        if line is None:
            return proc.wait()
        print(line, end="")
    proc.kill()
    fail(
        "runner did not exit within %ds after STOP_RUNNER=1 "
        "(killed)" % timeout,
    )


def main():
    if len(sys.argv) < 4:
        fail(
            "Usage: container_tarball_test.py <tarball_rootpath> "
            "<container_name> <runner_filename>",
        )

    tarball_path = sys.argv[1]
    container_name = sys.argv[2]
    runner_filename = sys.argv[3]

    if not os.path.isfile(tarball_path):
        fail("Tarball not found: %s" % tarball_path)

    with tempfile.TemporaryDirectory(prefix="rules_celix_tarball_") as workdir:
        extract_dir = os.path.join(workdir, "extracted")
        os.makedirs(extract_dir)

        # Unpack the tarball with Python's stdlib: this is the explicit
        # no-Bazel proof — no runner runfiles, no tar binary, no build tree.
        with tarfile.open(tarball_path, "r:gz") as tf:
            tf.extractall(extract_dir)

        root = os.path.join(extract_dir, container_name)
        if not os.path.isdir(root):
            fail("Extracted tarball is missing the expected <name>/ root dir: %s" % root)

        runtime_dir = os.path.join(root, container_name + "_runtime")
        for rel in [
            "start.sh",
            runner_filename,
            os.path.join(container_name + "_runtime", "config.properties"),
            os.path.join(container_name + "_runtime", "bundles", "com.example.test.zip"),
            os.path.join(container_name + "_runtime", "bundles", "com.example.no_activator.zip"),
        ]:
            if not os.path.isfile(os.path.join(root, rel)):
                fail("Extracted tarball is missing expected file: %s" % rel)

        # The launcher and runner must be executable (explicit modes in the tar).
        start_sh = os.path.join(root, "start.sh")
        runner = os.path.join(root, runner_filename)
        for path in (start_sh, runner):
            if not os.access(path, os.X_OK):
                fail("Expected executable file in tarball, not executable: %s" % path)

        # The framework needs a writable config (re-checked on a timer) and the
        # extracted tree is fine to mutate (it is a temp copy, no Bazel race).
        config_path = os.path.join(runtime_dir, "config.properties")
        with open(config_path, "r") as fh:
            config_body = fh.read()
        if "CELIX_AUTO_START_1=bundles/com.example.test.zip" not in config_body:
            fail("Extracted config is missing the level-1 autostart entry for the test bundle")

        proc = subprocess.Popen(
            [start_sh],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            cwd=root,
        )

        rc = None
        try:
            seen_sentinel = False
            collected = []
            reader = PipeReader(proc, SENTINEL_TIMEOUT)
            while True:
                try:
                    line = reader.readline()
                except TimeoutError:
                    line = None
                    break
                if line is None:
                    break
                collected.append(line)
                if SENTINEL in line:
                    seen_sentinel = True
                    print(line, end="")
                    break

            if not seen_sentinel:
                for line in collected:
                    print(line, end="")
                proc.kill()
                fail(
                    "start.sh from the extracted tarball did not log the "
                    "sentinel '%s' within %ds (exit code %s)" %
                    (SENTINEL, SENTINEL_TIMEOUT, proc.wait()),
                )

            # Ask the runner to stop cleanly, then assert a clean exit.
            with open(config_path, "a") as fh:
                fh.write(STOP_LINE + "\n")

            rc = drain_until_stop(proc, reader)
        finally:
            if proc.poll() is None:
                proc.kill()

        if rc != 0:
            fail("start.sh from the extracted tarball exited with code %s (expected 0)" % rc)

    print("PASS: tarball extracted and ran without Bazel: sentinel logged, "
          "clean exit on STOP_RUNNER=1.")


if __name__ == "__main__":
    main()