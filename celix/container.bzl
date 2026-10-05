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

"""celix_container macro — assembles a Celix container from celix_bundle targets.

Lays each bundle zip out at `bundles/<symbolic_name>.zip`, producing the deployable contents of a Celix container as real standalone files ready to copy next to the Celix executable.

The launcher executable (`CelixContainerInfo.runner`) and the framework configuration (`CelixContainerInfo.config`) are not yet generated; they arrive in later steps.

Example:

    load("@rules_celix//celix:defs.bzl", "celix_bundle", "celix_container")

    celix_bundle(
        name = "hello_bundle",
        activator = ":hello_lib",
        symbolic_name = "org.example.hello",
    )

    celix_container(
        name = "hello_container",
        bundles = [":hello_bundle"],
    )
"""

load("//celix/internal:container_impl.bzl", _celix_container_impl = "celix_container_impl")

def celix_container(name, bundles, **kwargs):
    """Macro that assembles a Celix container from a list of Celix bundles.

    Args:
        name (str): Unique target name for the resulting container.
        bundles (list of Label): Ordered list of `celix_bundle` targets to assemble.
            Each bundle is laid out at `bundles/<symbolic_name>.zip`, so symbolic
            names must be unique within a container.
        **kwargs: Additional attributes forwarded to the underlying rule.
    """
    _celix_container_impl(
        name = name,
        bundles = bundles,
        **kwargs
    )
