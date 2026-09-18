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

#ifndef ENABLED_TEST
#error "copts were not forwarded"
#endif

#include "flags_only_header.h"

int flags_activate(void) {
    return FLAGS_ONLY_HEADER_PRESENT;
}