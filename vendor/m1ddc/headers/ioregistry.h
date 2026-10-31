#ifndef _IOREGISTRY_H
# define _IOREGISTRY_H

# import <CoreGraphics/CoreGraphics.h>

# ifndef MAX_DISPLAYS
#  define MAX_DISPLAYS   16  // Online displays, including built-in and virtual ones that are skipped
# endif

# define UUID_SIZE      37

// IOAVServiceRef is a private class, so we need to define it here
typedef CFTypeRef IOAVServiceRef;

# define DDC_CHIP_ADDRESS_DEFAULT  0x37
# define DDC_CHIP_ADDRESS_MCDP29XX 0xB7

typedef struct
{
    IOAVServiceRef service;
    UInt32 chipAddress;
} DDCTransport;

// Base structure for display infos
typedef struct
{
    CGDirectDisplayID id;
    // Owned per entry; uuid and ioLocation are borrowed from info.
    CFDictionaryRef info;
    io_service_t adapter;
    NSString *ioLocation;
    NSString *uuid;
    NSString *edid;
    NSString *productName;
    NSString *manufacturer;
    NSString *alphNumSerial;
    UInt32 serial;
    UInt32 model;
    UInt32 vendor;
} DisplayInfos;

CGDisplayCount  getOnlineDisplayInfos(DisplayInfos* displayInfos);
void            releaseDisplayInfos(DisplayInfos* displayInfos, int count);
// Returns NULL when nothing matches; *ambiguous is set when several displays match.
DisplayInfos*   selectDisplay(DisplayInfos *displays, int connectedDisplays, char *displayIdentifier, bool *ambiguous);

IOAVServiceRef  getDefaultDisplayAVService();
IOAVServiceRef  getDisplayAVService(DisplayInfos* displayInfos);
DDCTransport    getDisplayDDCTransport(DisplayInfos* displayInfos);

// External functions
extern IOAVServiceRef   IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVServiceRef   IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern CFDictionaryRef  CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID);

#endif