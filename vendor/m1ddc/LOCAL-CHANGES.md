# Local read fixes for shared display-auto v2.2.0

Upstream: https://github.com/waydabber/m1ddc/tree/04d949794102eb8df01ad3681afff6464a3eede2
License: upstream MIT LICENSE retained.

Changes:
1. Get-VCP request checksum includes the actual source address (normally 0x51). Live PG42UQ testing proved the old form returned stale input packets even when asked for contrast/brightness. Corrected requests returned matching live feature packets and HDMI2=18.
2. Validate reply header, opcode, status, requested VCP, and checksum. Retry at most three times, then fail the read.
3. Allow 50 ms normal read processing time instead of 10 ms. MCDP-specific timing unchanged.
4. Copy decoded 16-bit fields with sizeof(uint16_t).
5. Send one Get-VCP request per attempt instead of two writes 10 ms apart; retry the complete transaction after an additional 50 ms. Maximum three attempts remains unchanged.

The controller only invokes get input. It never changes physical inputs or other monitor controls. DDC reads send a Get-VCP request before reading the reply.

This is a local patch, not an upstream release or security certification. No issue or PR was submitted. Build with make binary CC=/usr/bin/clang; do not use make install.

## 2.6 read-only orientation query

Added the named `get orientation` VCP 0xAA query. Set/change/max through this alias are rejected. Uses the same validated read/checksum/retry transport as input reads. Verified RD280UG values: 1 physical landscape; 2 physical portrait. No VCP 0xFC enable writes are used. Other orientation values are not calibrated.

## Public repository documentation

Replaced upstream example device UUIDs with `DISPLAY_UUID` placeholders; license and attribution retained.

## Public bootstrap transport correction

Set-VCP writes now use the packet header's payload length plus the header/checksum bytes.
The earlier last-nonzero-byte scan could truncate a valid zero checksum or include stale
buffer bytes. The hardware-free native test intercepts the transport write and checks the
actual transmitted length. Incidental trailing whitespace was also normalized.
