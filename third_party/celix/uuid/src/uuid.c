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

#include <uuid/uuid.h>

#include <stdio.h>
#include <string.h>

#if defined(__linux__)
#include <sys/random.h>
#elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__)
#include <stdlib.h>
#endif

static void celix_uuid_random_fill(unsigned char out[16]) {
#if defined(__linux__)
    /* getrandom is always available on Linux >= 3.17 / glibc >= 2.25. */
    size_t done = 0;
    while (done < 16) {
        ssize_t n = getrandom(out + done, 16 - done, 0);
        if (n < 0) {
            /* Very unlikely; fall through to urandom below on error. */
            break;
        }
        done += (size_t)n;
    }
    if (done == 16) {
        return;
    }
#elif defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__)
    arc4random_buf(out, 16);
    return;
#endif
    /* Portable fallback: /dev/urandom. */
    FILE *f = fopen("/dev/urandom", "rb");
    if (f != NULL) {
        size_t n = fread(out, 1, 16, f);
        fclose(f);
        if (n == 16) {
            return;
        }
    }
    /* Last resort: an unseeded pseudo-random sequence (never used in practice). */
    static unsigned long seed = 0x9e3779b97f4a7c15UL;
    for (int i = 0; i < 16; i++) {
        seed = seed * 6364136223846793005UL + 1442695040888963407UL;
        out[i] = (unsigned char)(seed >> 33);
    }
}

void uuid_generate(uuid_t out) {
    celix_uuid_random_fill(out);
    /* Set version (4) and variant (RFC 4122) bits. */
    out[6] = (unsigned char)((out[6] & 0x0f) | 0x40);
    out[8] = (unsigned char)((out[8] & 0x3f) | 0x80);
}

static int hexval(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    }
    if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    return -1;
}

int uuid_parse(const char *in, uuid_t uu) {
    int group[5] = {8, 4, 4, 4, 12};
    const char *p = in;
    int pos = 0;
    for (int g = 0; g < 5; g++) {
        for (int i = 0; i < group[g]; i += 2) {
            int hi = hexval(p[0]);
            int lo = hexval(p[1]);
            if (hi < 0 || lo < 0) {
                return -1;
            }
            uu[pos++] = (unsigned char)((hi << 4) | lo);
            p += 2;
        }
        if (g < 4 && *p != '-') {
            return -1;
        }
        if (g < 4) {
            p++;
        }
    }
    return *p == '\0' ? 0 : -1;
}

void uuid_unparse(const uuid_t uu, char *out) {
    snprintf(out, 37,
             "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
             uu[0], uu[1], uu[2], uu[3], uu[4], uu[5], uu[6], uu[7], uu[8], uu[9],
             uu[10], uu[11], uu[12], uu[13], uu[14], uu[15]);
    (void)memset(out + 36, '\0', 1);
}
