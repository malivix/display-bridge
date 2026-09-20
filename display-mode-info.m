// SPDX-License-Identifier: MIT
// Read-only public mode snapshot plus optional private MonitorPanel metadata.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSNumber *optionalNumber(id object,NSString *key){
    if(!object || ![object respondsToSelector:NSSelectorFromString(key)])return nil;
    id value=[object valueForKey:key];return [value isKindOfClass:[NSNumber class]]?value:nil;
}
int main(int argc,const char **argv){@autoreleasepool{
    if(argc!=2 || (strcmp(argv[1],"status") && strcmp(argv[1],"modes"))){fprintf(stderr,"Usage: display-mode-info status|modes\n");return 1;}
    BOOL enumerateModes=strcmp(argv[1],"modes")==0;
    BOOL available=dlopen("/System/Library/PrivateFrameworks/MonitorPanel.framework/MonitorPanel",RTLD_LAZY)!=NULL;
    Class cls=available?NSClassFromString(@"MPDisplay"):Nil;
    SEL initializer=NSSelectorFromString(@"initWithCGSDisplayID:");
    CGDirectDisplayID ids[32];uint32_t count=0;
    if(CGGetOnlineDisplayList(32,ids,&count)!=kCGErrorSuccess){fprintf(stderr,"Display inventory unavailable\n");return 1;}
    NSMutableArray *rows=[NSMutableArray array];
    for(uint32_t i=0;i<count;i++){
        CGDirectDisplayID displayID=ids[i];
        NSString *key=[NSString stringWithFormat:@"%u:%u:%u",CGDisplayVendorNumber(displayID),CGDisplayModelNumber(displayID),CGDisplaySerialNumber(displayID)];
        CGDisplayModeRef mode=CGDisplayCopyDisplayMode(displayID);
        NSMutableDictionary *row=[NSMutableDictionary dictionaryWithDictionary:@{@"key":key,@"id":@(displayID)}];
        if(!mode){row[@"error"]=@"Current mode unavailable";[rows addObject:row];continue;}
        row[@"modeID"]=@(CGDisplayModeGetIODisplayModeID(mode));
        row[@"width"]=@(CGDisplayModeGetWidth(mode));row[@"height"]=@(CGDisplayModeGetHeight(mode));
        row[@"pixelWidth"]=@(CGDisplayModeGetPixelWidth(mode));row[@"pixelHeight"]=@(CGDisplayModeGetPixelHeight(mode));
        row[@"hz"]=@(CGDisplayModeGetRefreshRate(mode));row[@"rotation"]=@(CGDisplayRotation(displayID));
        @try{
            if(!cls || ![cls instancesRespondToSelector:initializer]){
                row[@"metadataError"]=@"MonitorPanel metadata unavailable on this macOS version";
            }else{
                id display=((id(*)(id,SEL,uint32_t))objc_msgSend)([cls alloc],initializer,displayID);
                if(enumerateModes && [display respondsToSelector:NSSelectorFromString(@"allModes")]){
                    id all=[display valueForKey:@"allModes"];
                    NSMutableArray *descriptions=[NSMutableArray array];
                    if([all isKindOfClass:[NSArray class]]){
                        for(id candidate in all){
                            NSNumber *identifier=optionalNumber(candidate,@"modeNumber");
                            NSNumber *vrr=optionalNumber(candidate,@"isVRR"),*promotion=optionalNumber(candidate,@"isProMotion");
                            if(identifier){
                                NSMutableDictionary *description=[NSMutableDictionary dictionaryWithDictionary:@{@"modeID":identifier}];
                                if(vrr)description[@"variableRefresh"]=@(vrr.boolValue);
                                if(promotion)description[@"proMotion"]=@(promotion.boolValue);
                                [descriptions addObject:description];
                            }
                        }
                        row[@"modes"]=descriptions;
                    }
                }
                id current=[display respondsToSelector:NSSelectorFromString(@"currentMode")]?[display valueForKey:@"currentMode"]:nil;
                NSNumber *privateID=optionalNumber(current,@"modeNumber");
                if(!privateID || privateID.intValue!=CGDisplayModeGetIODisplayModeID(mode)){
                    row[@"metadataError"]=@"Public/private modes disagree; display may be reconfiguring";
                }else{
                    NSNumber *vrr=optionalNumber(current,@"isVRR"),*promotion=optionalNumber(current,@"isProMotion"),*hdr=optionalNumber(display,@"preferHDRModes");
                    if(vrr)row[@"variableRefresh"]=@(vrr.boolValue);
                    if(promotion)row[@"proMotion"]=@(promotion.boolValue);
                    if(hdr)row[@"hdrPreferenceEnabled"]=@(hdr.boolValue);
                    if(!vrr || !promotion || !hdr)row[@"metadataError"]=@"Some required metadata properties are unavailable";
                }
            }
        }@catch(NSException *exception){row[@"metadataError"]=exception.reason?:@"Display metadata query failed";}
        CGDisplayModeRef after=CGDisplayCopyDisplayMode(displayID);
        if(!after || CGDisplayModeGetIODisplayModeID(after)!=CGDisplayModeGetIODisplayModeID(mode)){
            row[@"metadataError"]=@"Mode changed while reading; retry after displays settle";
            [row removeObjectForKey:@"variableRefresh"];[row removeObjectForKey:@"proMotion"];[row removeObjectForKey:@"hdrPreferenceEnabled"];
        }
        if(after)CGDisplayModeRelease(after);CGDisplayModeRelease(mode);[rows addObject:row];
    }
    NSDictionary *result=@{@"read_only":@YES,@"displays":rows,@"limits":@"HDR preference is not independent proof of the HDMI/DP signal format. Private metadata may become unavailable after macOS updates."};
    NSData *data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
    if(!data)return 1;puts([[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);return 0;
}}
