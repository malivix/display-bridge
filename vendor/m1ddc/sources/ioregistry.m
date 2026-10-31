@import Foundation;
@import IOKit;
@import ApplicationServices;
@import CoreGraphics;

#include "ioregistry.h"
#include "utils.h"

static CFTypeRef getCFStringRef(io_service_t service, char* key) {
    CFStringRef cfstring = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingASCII);
    if (cfstring == NULL) return NULL;
    CFTypeRef value = IORegistryEntrySearchCFProperty(service, kIOServicePlane, cfstring, kCFAllocatorDefault, kIORegistryIterateRecursively);
    CFRelease(cfstring);
    return value;
}

// Retains a property value only when it has the expected type.
static NSString *retainedString(NSDictionary *dictionary, NSString *key) {
    id value = [dictionary objectForKey:key];
    return [value isKindOfClass:[NSString class]] ? [value retain] : nil;
}

static void releaseDisplayInfo(DisplayInfos *display) {
    if (display->adapter != MACH_PORT_NULL) IOObjectRelease(display->adapter);
    if (display->edid) CFRelease((CFTypeRef)display->edid);
    [display->productName release];
    [display->manufacturer release];
    [display->alphNumSerial release];
    if (display->info) CFRelease(display->info);
    memset(display, 0, sizeof(*display));
}

void releaseDisplayInfos(DisplayInfos *displayInfos, int count) {
    for (int i = 0; i < count; i++) releaseDisplayInfo(displayInfos + i);
}

static Boolean isMCDP29XXProxy(io_service_t proxy) {
    io_registry_entry_t parent = MACH_PORT_NULL;
    if (IORegistryEntryGetParentEntry(proxy, kIOServicePlane, &parent) != KERN_SUCCESS) {
        return false;
    }

    Boolean isMCDP29XX = false;
    CFTypeRef providerClass = IORegistryEntryCreateCFProperty(
        parent,
        CFSTR("EPICProviderClass"),
        kCFAllocatorDefault,
        0
    );
    if (providerClass != NULL && CFGetTypeID(providerClass) == CFStringGetTypeID()) {
        isMCDP29XX = CFStringCompare(providerClass, CFSTR("AppleDCPMCDP29XX"), 0) == kCFCompareEqualTo;
    }

    if (providerClass != NULL) {
        CFRelease(providerClass);
    }
    IOObjectRelease(parent);
    return isMCDP29XX;
}

CGDisplayCount getOnlineDisplayInfos(DisplayInfos* displayInfos) {
    // Getting online display list and count
    CGDisplayCount screenCount = 0;
    CGDirectDisplayID screenList[MAX_DISPLAYS];
    memset(displayInfos, 0, sizeof(DisplayInfos) * MAX_DISPLAYS);
    if (CGGetOnlineDisplayList(MAX_DISPLAYS, screenList, &screenCount) != kCGErrorSuccess) {
        return 0;
    }

    int validDisplayCount = 0;
    // Fetching each display infos from IOKit
    for (int i = 0; i < (int)screenCount && i < MAX_DISPLAYS && validDisplayCount < MAX_DISPLAYS; i++) {
        DisplayInfos *currDisplay = displayInfos + validDisplayCount;
        currDisplay->id = screenList[i];

        // This is a private API, but it's a shortcut to get the system UUID
        currDisplay->info = CoreDisplay_DisplayCreateInfoDictionary(currDisplay->id);
        if (currDisplay->info == NULL) {
            // Skip virtual displays that don't provide info dictionary
            releaseDisplayInfo(currDisplay);
            continue;
        }

        currDisplay->serial = CGDisplaySerialNumber(currDisplay->id);
        currDisplay->model = CGDisplayModelNumber(currDisplay->id);
        currDisplay->vendor = CGDisplayVendorNumber(currDisplay->id);

        CFTypeRef uuid = CFDictionaryGetValue(currDisplay->info, CFSTR("kCGDisplayUUID"));
        CFTypeRef location = CFDictionaryGetValue(currDisplay->info, CFSTR("IODisplayLocation"));

        // Skip virtual displays (like Sidecar/AirPlay) that don't have required properties
        if (uuid == NULL || location == NULL ||
            CFGetTypeID(uuid) != CFStringGetTypeID() || CFGetTypeID(location) != CFStringGetTypeID()) {
            releaseDisplayInfo(currDisplay);
            continue;
        }
        currDisplay->uuid = (NSString *)uuid;
        currDisplay->ioLocation = (NSString *)location;

        // Retrieving IORegistry entry for display
        currDisplay->adapter = IORegistryEntryCopyFromPath(kIOMainPortDefault, (CFStringRef)currDisplay->ioLocation);
        if (currDisplay->adapter == MACH_PORT_NULL) {
            releaseDisplayInfo(currDisplay);
            continue;
        }

        // If successful, we can retrieve the EDID UUID, and other display attributes
        CFTypeRef edid = getCFStringRef(currDisplay->adapter, "EDID UUID");
        if (edid != NULL && CFGetTypeID(edid) != CFStringGetTypeID()) {
            CFRelease(edid);
            edid = NULL;
        }
        currDisplay->edid = (NSString *)edid;
        CFTypeRef displayAttrs = getCFStringRef(currDisplay->adapter, "DisplayAttributes");
        if (displayAttrs && CFGetTypeID(displayAttrs) == CFDictionaryGetTypeID()) {
            NSDictionary* productAttrs = [(NSDictionary*)displayAttrs objectForKey:@"ProductAttributes"];
            if ([productAttrs isKindOfClass:[NSDictionary class]]) {
                currDisplay->productName = retainedString(productAttrs, @"ProductName");
                currDisplay->manufacturer = retainedString(productAttrs, @"ManufacturerID");
                currDisplay->alphNumSerial = retainedString(productAttrs, @"AlphanumericSerialNumber");
            }
        }
        if (displayAttrs) CFRelease(displayAttrs);
        // Standby and hotplug can omit product attributes; listing must not read garbage.
        if (currDisplay->productName == nil) currDisplay->productName = [@"Unknown Display" retain];

        validDisplayCount++;
    }

    return validDisplayCount;
}

/*
 *  Returns display identifier based on identification method
 *  Allowed methods are:
 *  - id    Display ID                          "<id>"
 *  - uuid  Display UUID                        "<uuid>"
 *  - edid  Display EDID UUID                   "<edid>"
 *  - seid  Display Alphnum SN + EDID UUID      "<an_serial>:<edid>"
 *  - basic Match basic identifiers             "<vendor>:<model>:<serial>"
 *  - ext   Match basic + extended identifiers  "<vendor>:<model>:<serial>:<manufacturer>:<an_serial>:<name>"
 *  - full  Match basic + extended + location   "<vendor>:<model>:<serial>:<manufacturer>:<an_serial>:<name>:<location>"
 */
NSString *getDisplayIdentifier(DisplayInfos *display, char *identificationMethod) {
    if (STR_EQ(identificationMethod, "id")) {
        return [NSString stringWithFormat:@"%u", display->id];
    } else if (STR_EQ(identificationMethod, "uuid")) {
        return display->uuid ?: @"";
    } else if (STR_EQ(identificationMethod, "edid")) {
        return display->edid ?: @"";
    } else if (STR_EQ(identificationMethod, "seid")) {
        return [NSString stringWithFormat:@"%@:%@",
            display->alphNumSerial ?: @"",
            display->edid ?: @""];
    } else if (STR_EQ(identificationMethod, "basic")) {
        return [NSString stringWithFormat:@"%u:%u:%u",
            display->vendor,
            display->model,
            display->serial];
    } else if (STR_EQ(identificationMethod, "ext")) {
        return [NSString stringWithFormat:@"%d:%d:%d:%@:%@:%@",
            display->vendor,
            display->model,
            display->serial,
            display->manufacturer ?: @"",
            display->alphNumSerial ?: @"",
            display->productName ?: @""];
    } else if (STR_EQ(identificationMethod, "full")) {
        return [NSString stringWithFormat:@"%d:%d:%d:%@:%@:%@:%@",
            display->vendor,
            display->model,
            display->serial,
            display->manufacturer ?: @"",
            display->alphNumSerial ?: @"",
            display->productName ?: @"",
            display->ioLocation ?: @""];
    }
    return NULL;
}

DisplayInfos* selectDisplay(DisplayInfos *displays, int connectedDisplays, char *displayIdentifier, bool *ambiguous) {
    *ambiguous = false;
    if (displayIdentifier[0] == '\0') return NULL;

    // Checking if display identifier is a display index from the "list" command
    char *stop;
    long displayNumber = strtol(displayIdentifier, &stop, 10);
    if (*stop == '\0') {
        return displayNumber >= 1 && displayNumber <= connectedDisplays ? displays + (displayNumber - 1) : NULL;
    }

    // Checking if an identification method is specified, otherwise defaulting to UUID
    char *identificationMethod = "uuid";
    char *delimiter = strstr(displayIdentifier, "=");
    if (delimiter != NULL) {
        // Delimiter should not be at the beginning or end of the string
        if (delimiter == displayIdentifier || delimiter == displayIdentifier + strlen(displayIdentifier) - 1) return NULL;
        // Splitting display identifier into identification method and value
        *delimiter = '\0';
        identificationMethod = displayIdentifier;
        displayIdentifier = delimiter + 1;
    }

    // Identical monitors can share basic identifiers, and CoreGraphics order can change
    // across wake or hotplug, so a value that matches more than one display selects none.
    DisplayInfos *match = NULL;
    for (int i = 0; i < connectedDisplays; i++) {
        const char *displayValue = getDisplayIdentifier(displays + i, identificationMethod).UTF8String;
        if (displayValue != NULL && STR_EQ(displayIdentifier, displayValue)) {
            if (match != NULL) {
                *ambiguous = true;
                return NULL;
            }
            match = displays + i;
        }
    }
    return match;
}

static kern_return_t getIORegistryRootIterator(io_iterator_t* iter) {
    *iter = MACH_PORT_NULL;
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    kern_return_t ret = IORegistryEntryCreateIterator(root, kIOServicePlane, kIORegistryIterateRecursively, iter);
    IOObjectRelease(root);
    return ret;
}

IOAVServiceRef getDefaultDisplayAVService() {
    return IOAVServiceCreate(kCFAllocatorDefault);
}

DDCTransport getDisplayDDCTransport(DisplayInfos* displayInfos) {

    DDCTransport transport = {
        .service = NULL,
        .chipAddress = DDC_CHIP_ADDRESS_DEFAULT,
    };
    if (displayInfos == NULL || displayInfos->adapter == MACH_PORT_NULL) {
        return transport;
    }

    uint64_t selectedAdapterID;
    if (IORegistryEntryGetRegistryEntryID(displayInfos->adapter, &selectedAdapterID) != KERN_SUCCESS) {
        return transport;
    }

    // Creating IORegistry iterator
    io_iterator_t iter;
    if (getIORegistryRootIterator(&iter) != KERN_SUCCESS) {
        return transport;
    }

    Boolean framebufferMatchesDisplay = false;
    io_service_t service;

	// Iterating through IORegistry
    while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        if (IOObjectConformsTo(service, "IOMobileFramebuffer")) {
            uint64_t framebufferID;
            framebufferMatchesDisplay =
                IORegistryEntryGetRegistryEntryID(service, &framebufferID) == KERN_SUCCESS &&
                framebufferID == selectedAdapterID;
            IOObjectRelease(service);
            continue;
        }

        // Searching for DCPAVServiceProxy associated with the selected display
        io_name_t name;
        IORegistryEntryGetName(service, name);
        if (!framebufferMatchesDisplay || !STR_EQ(name, "DCPAVServiceProxy")) {
            IOObjectRelease(service);
            continue;
        }

        // Creating IOAVServiceRef from DCPAVServiceProxy
        IOAVServiceRef avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service);
        if (avService == NULL) {
            IOObjectRelease(service);
            continue;
        }

        CFStringRef location = getCFStringRef(service, "Location");
        Boolean isExternal = location != NULL &&
            CFGetTypeID(location) == CFStringGetTypeID() &&
            CFStringCompare(CFSTR("External"), location, 0) == kCFCompareEqualTo;
        if (location != NULL) {
            CFRelease(location);
        }

        if (!isExternal) {
            CFRelease(avService);
            IOObjectRelease(service);
            continue;
        }

        transport.service = avService;
        // MCDP29xx routes DDC through chip address 0xB7.
        transport.chipAddress = isMCDP29XXProxy(service)
            ? DDC_CHIP_ADDRESS_MCDP29XX
            : DDC_CHIP_ADDRESS_DEFAULT;
        IOObjectRelease(service);
        IOObjectRelease(iter);
        return transport;
    }

    IOObjectRelease(iter);
    return transport;
}

IOAVServiceRef getDisplayAVService(DisplayInfos* displayInfos) {
    return getDisplayDDCTransport(displayInfos).service;
}
