// SPDX-License-Identifier: MIT
#ifndef DISPLAY_AUTO_REPLY_VALIDATION_H
#define DISPLAY_AUTO_REPLY_VALIDATION_H
#include <stdint.h>
#include <stdbool.h>
static inline bool validVCPReply(const uint8_t *reply, uint8_t requestedVCP) {
    if (reply[0] != 0x6e || reply[1] != 0x88 || reply[2] != 0x02 ||
        reply[3] != 0 || reply[4] != requestedVCP) return false;
    uint8_t checksum = 0x50;
    for (int i = 0; i < 11; i++) checksum ^= reply[i];
    return checksum == 0;
}
#endif
