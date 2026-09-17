/*
 * Copyright 2026 SOFTYONARY SL
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* Minimal, hermetic replacement for libuuid's uuid/uuid.h.
 *
 * The Celix framework only needs uuid_generate / uuid_parse / uuid_unparse
 * (RFC 4122), so we implement a tiny, portable subset here instead of pulling
 * in util-linux/e2fsprogs. See the package README for rationale. */

#ifndef CELIX_UUID_H
#define CELIX_UUID_H

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned char uuid_t[16];

void uuid_generate(uuid_t out);
int uuid_parse(const char *in, uuid_t uu);
void uuid_unparse(const uuid_t uu, char *out);

#ifdef __cplusplus
}
#endif

#endif /* CELIX_UUID_H */
