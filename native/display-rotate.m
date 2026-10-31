// SPDX-License-Identifier: MIT
// MPDisplay is a private macOS API, also used by displayplacer for rotation.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/message.h>
#import <dlfcn.h>
int main(int argc,const char **argv){@autoreleasepool {
    if(argc!=4 && argc!=5){fprintf(stderr,"Usage: display-rotate PG_KEY BENQ_KEY 0|90 [BUILTIN_KEY]\n");return 1;}
    NSString *pg=@(argv[1]),*benq=@(argv[2]),*builtin=argc==5?@(argv[4]):nil;
    if(strcmp(argv[3],"0") && strcmp(argv[3],"90")){fprintf(stderr,"Unsupported rotation\n");return 1;}
    CGDirectDisplayID ids[32],target=0;uint32_t count=0;
    if(CGGetOnlineDisplayList(32,ids,&count)!=kCGErrorSuccess || count<2 || count>3){fprintf(stderr,"Online displays differ from the saved setup; no rotation\n");return 1;}
    NSMutableSet *keys=[NSMutableSet set];
    for(uint32_t i=0;i<count;i++){
        NSString *key=[NSString stringWithFormat:@"%u:%u:%u",CGDisplayVendorNumber(ids[i]),CGDisplayModelNumber(ids[i]),CGDisplaySerialNumber(ids[i])];
        [keys addObject:key];if([key isEqual:benq])target=ids[i];
        // Only the enrolled lid may mirror; the two externals must be extended.
        if(CGDisplayMirrorsDisplay(ids[i]) && !(builtin && [key isEqual:builtin])){fprintf(stderr,"Rotation requires extended displays\n");return 1;}
    }
    NSSet *pair=[NSSet setWithObjects:pg,benq,nil];
    if(!target || keys.count!=count || !([keys isEqual:pair] || (builtin && [keys isEqual:[pair setByAddingObject:builtin]]))){fprintf(stderr,"Saved displays are not the active setup; no rotation\n");return 1;}
    int angle=atoi(argv[3]);if(CGDisplayRotation(target)==angle)return 0;
    if(!dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel",RTLD_NOW)){fprintf(stderr,"MonitorPanel unavailable\n");return 1;}
    Class cls=NSClassFromString(@"MPDisplay");SEL init=NSSelectorFromString(@"initWithCGSDisplayID:"),set=NSSelectorFromString(@"setOrientation:");
    if(!cls || ![cls instancesRespondToSelector:init] || ![cls instancesRespondToSelector:set]){fprintf(stderr,"MonitorPanel rotation interface unavailable\n");return 1;}
    id display=((id(*)(id,SEL,uint32_t))objc_msgSend)([cls alloc],init,target);
    ((void(*)(id,SEL,int))objc_msgSend)(display,set,angle);
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    while(CGDisplayRotation(target)!=angle && deadline.timeIntervalSinceNow>0)[NSThread sleepForTimeInterval:.1];
    if(CGDisplayRotation(target)!=angle){fprintf(stderr,"Rotation readback timed out\n");return 1;}
    return 0;
}}
