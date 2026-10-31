// SPDX-License-Identifier: MIT
#include <assert.h>
#include <stdio.h>
#include "i2c.h"
#include "reply_validation.h"
#include "ioregistry.h"
static uint32_t sentLength;
IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chip, uint32_t offset,
                           void *buffer, uint32_t length) {
    (void)service; (void)chip; (void)offset; (void)buffer;
    sentLength = length;
    return kIOReturnSuccess;
}
int main(void) {
    DDCPacket write = createDDCPacket(VOLUME);
    prepareDDCWrite(&write, 218); // Produces a zero checksum, still part of the packet.
    assert(write.data[5] == 0);
    assert(performDDCWriteAtChipAddress(NULL, 0x37, &write) == kIOReturnSuccess);
    assert(sentLength == 6);

    DDCPacket request = createDDCPacket(INPUT);
    prepareDDCRead(&request);
    assert(request.data[0] == 0x82 && request.data[1] == 0x01);
    assert(request.data[2] == 0x60 && request.data[3] == 0xdc);
    prepareDDCRead(&request);
    assert(request.data[3] == 0xdc); // Retry must not XOR an old checksum.
    uint8_t hdmi2[12] = {0x6e,0x88,0x02,0x00,0x60,0x00,0x00,0x05,0x00,0x12,0xc3,0x65};
    assert(validVCPReply(hdmi2, 0x60));
    assert(!validVCPReply(hdmi2, 0x12)); // Stale input packet cannot answer contrast.
    hdmi2[10] ^= 1;
    assert(!validVCPReply(hdmi2, 0x60));
    hdmi2[10] ^= 1;
    hdmi2[3] = 1;
    assert(!validVCPReply(hdmi2, 0x60));
    uint8_t empty[12] = {0};
    assert(!validVCPReply(empty, 0x60));
    DisplayInfos twins[3] = {0};
    for (int i = 0; i < 3; i++) { twins[i].vendor = 2513; twins[i].model = 32963; twins[i].serial = 0; }
    twins[0].uuid = @"A"; twins[1].uuid = @"B"; twins[2].vendor = 1715; twins[2].uuid = @"C";
    bool ambiguous = true;
    char exact[] = "uuid=B";
    assert(selectDisplay(twins, 3, exact, &ambiguous) == twins + 1 && !ambiguous);
    char shared[] = "basic=2513:32963:0";
    assert(selectDisplay(twins, 3, shared, &ambiguous) == NULL && ambiguous); // Identical monitors select none.
    char unique[] = "basic=1715:32963:0";
    assert(selectDisplay(twins, 3, unique, &ambiguous) == twins + 2 && !ambiguous);
    char zero[] = "0", negative[] = "-1", past[] = "4", blank[] = "", first[] = "1", missing[] = "uuid=Z";
    assert(selectDisplay(twins, 3, zero, &ambiguous) == NULL);
    assert(selectDisplay(twins, 3, negative, &ambiguous) == NULL);
    assert(selectDisplay(twins, 3, past, &ambiguous) == NULL);
    assert(selectDisplay(twins, 3, blank, &ambiguous) == NULL);
    assert(selectDisplay(twins, 3, missing, &ambiguous) == NULL && !ambiguous);
    assert(selectDisplay(twins, 3, first, &ambiguous) == twins);
    puts("PASS DDC request checksum, retry, matching VCP, response status, reply checksum, and display selection");
    return 0;
}
