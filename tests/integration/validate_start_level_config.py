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

"""Validates the generated config.properties of a level-aware celix_container.

Reads the generated `config.properties` (via `$(rootpath
//tests/testdata:test_container_levels_config)`) and asserts its exact body:
the four static keys, then `CELIX_AUTO_START_1` / `CELIX_AUTO_START_2` in
ascending order, then `CELIX_AUTO_INSTALL`.  Asserts that empty levels (e.g.
`CELIX_AUTO_START_0`) are omitted.
"""

import os
import sys


def fail(msg):
    """Print a failure message and exit non-zero."""
    print("FAIL: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        fail("Usage: validate_start_level_config.py <config.properties rootpath>")

    config_path = sys.argv[1]
    if not os.path.isfile(config_path):
        fail("config.properties not found: %s" % config_path)

    with open(config_path, "r") as fh:
        body = fh.read()

    expected = (
        "CELIX_BUNDLES_PATH=bundles\n"
        "CELIX_FRAMEWORK_CACHE_DIR=.cache\n"
        "CELIX_FRAMEWORK_CACHE_USE_TMP_DIR=true\n"
        "CELIX_LOGGING_DEFAULT_ACTIVE_LOG_LEVEL=info\n"
        "CELIX_AUTO_START_1=bundles/com.example.test.zip\n"
        "CELIX_AUTO_START_2=bundles/com.example.no_activator.zip\n"
        "CELIX_AUTO_INSTALL=bundles/com.example.full.zip\n"
    )

    if body != expected:
        fail(
            "config.properties body mismatch.\n"
            "Expected:\n%s\n"
            "Got:\n%s" % (expected, body)
        )

    print("PASS: config.properties carries the expected start-level + install-only body.")


if __name__ == "__main__":
    main()