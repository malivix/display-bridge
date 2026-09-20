// SPDX-License-Identifier: MIT
// Public CoreAudio output discovery and explicit UID selection. No volume changes.
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <math.h>
#ifdef DISPLAY_AUDIO_TESTING
#import <signal.h>
#endif

static AudioObjectPropertyAddress address(AudioObjectPropertySelector selector, AudioObjectPropertyScope scope) {
    return (AudioObjectPropertyAddress){selector, scope, kAudioObjectPropertyElementMain};
}
static void fail(NSString *message) { fprintf(stderr,"%s\n",message.UTF8String);exit(1); }
static UInt32 integer(AudioObjectID object, AudioObjectPropertySelector selector) {
    UInt32 value=0, size=sizeof(value);
    AudioObjectPropertyAddress a=address(selector,kAudioObjectPropertyScopeGlobal);
    OSStatus result=AudioObjectGetPropertyData(object,&a,0,NULL,&size,&value);
    if(result) fail([NSString stringWithFormat:@"CoreAudio read failed: %d",result]);
    return value;
}
static NSString *text(AudioObjectID object, AudioObjectPropertySelector selector) {
    CFStringRef value=NULL; UInt32 size=sizeof(value);
    AudioObjectPropertyAddress a=address(selector,kAudioObjectPropertyScopeGlobal);
    OSStatus result=AudioObjectGetPropertyData(object,&a,0,NULL,&size,&value);
    if(result || !value) fail(@"CoreAudio identity read failed");
    return CFBridgingRelease(value);
}
static Float64 sampleRate(AudioObjectID id);
static id optionalRate(AudioObjectID id) {
    Float64 value=0;UInt32 size=sizeof(value);
    AudioObjectPropertyAddress a=address(kAudioDevicePropertyNominalSampleRate,kAudioObjectPropertyScopeGlobal);
    if(AudioObjectGetPropertyData(id,&a,0,NULL,&size,&value) || !isfinite(value))return [NSNull null];
    return @(value);
}
static NSArray *outputs(void) {
    AudioObjectPropertyAddress a=address(kAudioHardwarePropertyDevices,kAudioObjectPropertyScopeGlobal);
    UInt32 size=0;
    if(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,&a,0,NULL,&size)) fail(@"Cannot enumerate audio devices");
    AudioObjectID *ids=calloc(1,MAX(size,1));
    if(!ids) fail(@"Cannot allocate audio device list");
    if(AudioObjectGetPropertyData(kAudioObjectSystemObject,&a,0,NULL,&size,ids)) { free(ids);fail(@"Cannot read audio devices"); }
    NSMutableArray *rows=[NSMutableArray array];
    UInt32 defaultID=integer(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultOutputDevice);
    UInt32 systemID=integer(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultSystemOutputDevice);
    for(UInt32 i=0;i<size/sizeof(AudioObjectID);i++) {
        AudioObjectID id=ids[i]; UInt32 streamBytes=0;
        a=address(kAudioDevicePropertyStreams,kAudioDevicePropertyScopeOutput);
        if(AudioObjectGetPropertyDataSize(id,&a,0,NULL,&streamBytes) || !streamBytes) continue;
        [rows addObject:@{@"id":@(id), @"name":text(id,kAudioObjectPropertyName),
            @"uid":text(id,kAudioDevicePropertyDeviceUID), @"sampleRate":optionalRate(id), @"default":@(id==defaultID),
            @"system":@(id==systemID), @"alive":@(integer(id,kAudioDevicePropertyDeviceIsAlive)!=0),
            @"builtin":@(integer(id,kAudioDevicePropertyTransportType)==kAudioDeviceTransportTypeBuiltIn)}];
    }
    free(ids);return rows;
}
static OSStatus selectOutput(AudioObjectPropertySelector selector, AudioObjectID id) {
    AudioObjectPropertyAddress a=address(selector,kAudioObjectPropertyScopeGlobal);
    if(!AudioObjectHasProperty(kAudioObjectSystemObject,&a)) return kAudioHardwareUnknownPropertyError;
    return AudioObjectSetPropertyData(kAudioObjectSystemObject,&a,0,NULL,sizeof(id),&id);
}
static Float64 sampleRate(AudioObjectID id) {
    Float64 rate=0;UInt32 size=sizeof(rate);
    AudioObjectPropertyAddress a=address(kAudioDevicePropertyNominalSampleRate,kAudioObjectPropertyScopeGlobal);
    if(AudioObjectGetPropertyData(id,&a,0,NULL,&size,&rate)) fail(@"Cannot read original audio sample rate");
    return rate;
}
static OSStatus setRate(AudioObjectID id, Float64 rate) {
    AudioObjectPropertyAddress a=address(kAudioDevicePropertyNominalSampleRate,kAudioObjectPropertyScopeGlobal);
    return AudioObjectSetPropertyData(id,&a,0,NULL,sizeof(rate),&rate);
}
static BOOL waitRate(AudioObjectID id, Float64 wanted) {
    for(int i=0;i<10;i++) {
        Float64 rate=0;UInt32 size=sizeof(rate);
        AudioObjectPropertyAddress a=address(kAudioDevicePropertyNominalSampleRate,kAudioObjectPropertyScopeGlobal);
        if(!AudioObjectGetPropertyData(id,&a,0,NULL,&size,&rate) && fabs(rate-wanted)<1) return YES;
        usleep(50000);
    }
    return NO;
}
static Float64 refreshStream(AudioObjectID id, NSString *uid, NSString *journal) {
    Float64 original=sampleRate(id);
    AudioObjectPropertyAddress a=address(kAudioDevicePropertyNominalSampleRate,kAudioObjectPropertyScopeGlobal);
    Boolean settable=false;
    if(AudioObjectIsPropertySettable(id,&a,&settable) || !settable) fail(@"Sample rate is not writable; no refresh performed");
    a=address(kAudioDevicePropertyAvailableNominalSampleRates,kAudioObjectPropertyScopeGlobal);
    UInt32 bytes=0;
    if(AudioObjectGetPropertyDataSize(id,&a,0,NULL,&bytes) || !bytes) fail(@"No supported audio rates; no refresh performed");
    AudioValueRange *ranges=calloc(1,bytes);
    if(!ranges) fail(@"Cannot allocate rate list");
    OSStatus result=AudioObjectGetPropertyData(id,&a,0,NULL,&bytes,ranges);
    Float64 alternative=0;
    Float64 choices[]={44100,48000};
    if(!result) for(int c=0;c<2 && !alternative;c++) for(UInt32 i=0;i<bytes/sizeof(AudioValueRange);i++)
        if(fabs(choices[c]-original)>1 && choices[c]>=ranges[i].mMinimum && choices[c]<=ranges[i].mMaximum) alternative=choices[c];
    free(ranges);
    if(!alternative) fail(@"No supported alternate rate; no refresh performed");
    if(integer(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultOutputDevice)!=id) {
        fputs("Audio output changed before refresh; selection preserved\n",stderr);exit(75);
    }
    NSDictionary *record=@{@"uid":uid,@"original":@(original),@"alternate":@(alternative),
        @"created":@([[NSDate date] timeIntervalSince1970]),@"attempt":[NSUUID UUID].UUIDString};
    NSError *error=nil;
    NSData *data=[NSJSONSerialization dataWithJSONObject:record options:0 error:&error];
    if(!data || ![data writeToFile:journal options:NSDataWritingAtomic error:&error]) fail(@"Cannot persist original audio rate; no refresh performed");
    chmod(journal.fileSystemRepresentation,0600);
    int journalFD=open(journal.fileSystemRepresentation,O_RDONLY);
    if(journalFD<0 || fsync(journalFD))fail(@"Could not sync recovery journal; no rate change applied");
    close(journalFD);
    // Always restore the captured rate, including after a failed alternate write.
    result=setRate(id,alternative);
    BOOL changed=!result && waitRate(id,alternative);
    #ifdef DISPLAY_AUDIO_TESTING
    if(changed) raise(SIGSTOP); // Only the separately compiled fault-injection binary.
    #endif
    if(changed) usleep(250000);
    OSStatus restored=setRate(id,original);
    BOOL restoredOK=!restored && waitRate(id,original);
    if(!changed || !restoredOK) fail([NSString stringWithFormat:@"Audio refresh failed: alternate=%d restored=%d verified=%d",result,restored,restoredOK]);
    if(unlink(journal.fileSystemRepresentation)) fail(@"Rate restored but recovery journal could not be cleared");
    usleep(250000);
    return original;
}
static void journalLock(NSString *path) {
    NSString *lock=[path stringByAppendingString:@".lock"];
    int fd=open(lock.fileSystemRepresentation,O_CREAT|O_RDWR,0600);
    if(fd<0 || flock(fd,LOCK_EX|LOCK_NB)) fail(@"Audio recovery journal is busy or inaccessible");
    // Descriptor stays owned until this short-lived helper exits.
}
static void recoverJournal(NSString *path, NSArray *rows) {
    if(![[NSFileManager defaultManager]fileExistsAtPath:path])return;
    NSData *data=[NSData dataWithContentsOfFile:path];
    NSDictionary *record=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    if(![record isKindOfClass:[NSDictionary class]] || ![record[@"uid"] isKindOfClass:[NSString class]] ||
       ![record[@"original"] isKindOfClass:[NSNumber class]] || ![record[@"alternate"] isKindOfClass:[NSNumber class]]) fail(@"Invalid audio recovery journal; no rate changes applied");
    Float64 original=[record[@"original"] doubleValue],alternate=[record[@"alternate"] doubleValue];
    if(!isfinite(original)||!isfinite(alternate)||original<=0||alternate<=0||original==alternate)fail(@"Invalid journal sample rates");
    NSMutableArray *matches=[NSMutableArray array];
    for(NSDictionary *row in rows)if([row[@"uid"]isEqual:record[@"uid"]] && [row[@"alive"]boolValue])[matches addObject:row];
    if(matches.count!=1)fail(@"Interrupted audio refresh: original device unavailable; recovery retained");
    AudioObjectID id=[matches[0][@"id"]unsignedIntValue];
    Float64 current=sampleRate(id);
    if(fabs(current-original)>=1) {
        if(fabs(current-alternate)>=1)fail(@"Audio rate changed outside automation; recovery retained without overwriting it");
        if(setRate(id,original) || !waitRate(id,original))fail(@"Interrupted audio rate restoration failed; recovery retained");
    }
    if(unlink(path.fileSystemRepresentation))fail(@"Recovered audio rate but could not clear journal");
}
int main(int argc,const char **argv) { @autoreleasepool {
    NSArray *rows=outputs();
    if(argc==2 && strcmp(argv[1],"status")==0) {
        NSError *error=nil;
        NSData *json=[NSJSONSerialization dataWithJSONObject:rows options:NSJSONWritingPrettyPrinted error:&error];
        if(!json) fail(error.localizedDescription);
        puts([[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding].UTF8String);return 0;
    }
    if(argc==3 && strcmp(argv[1],"recover")==0) {
        NSString *journal=@(argv[2]);journalLock(journal);recoverJournal(journal,rows);return 0;
    }
    if(argc==4 && strcmp(argv[1],"refresh")==0) {
        NSString *journal=@(argv[3]);journalLock(journal);recoverJournal(journal,rows);
        NSMutableArray *matches=[NSMutableArray array];
        for(NSDictionary *row in rows) if([row[@"uid"] isEqualToString:@(argv[2])] && [row[@"alive"] boolValue]) [matches addObject:row];
        if(matches.count!=1) fail(@"Refresh output UID unavailable or ambiguous");
        Float64 original=refreshStream([matches[0][@"id"] unsignedIntValue],@(argv[2]),journal);
        printf("{\"original_rate\":%.17g}\n",original);return 0;
    }
    if((argc!=4 && argc!=6) || strcmp(argv[1],"select") || (strcmp(argv[3],"output") && strcmp(argv[3],"both")))
        fail(@"Usage: display-audio status | select UID output|both [EXPECTED_OUTPUT EXPECTED_ALERTS] | refresh UID JOURNAL | recover JOURNAL");
    NSMutableArray *matches=[NSMutableArray array];
    for(NSDictionary *row in rows) if([row[@"uid"] isEqualToString:@(argv[2])] && [row[@"alive"] boolValue]) [matches addObject:row];
    if(matches.count!=1) fail(@"Audio output UID unavailable or ambiguous");
    AudioObjectID target=[matches[0][@"id"] unsignedIntValue];
    AudioObjectID oldOutput=integer(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultOutputDevice);
    AudioObjectID oldSystem=integer(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultSystemOutputDevice);
    BOOL both=strcmp(argv[3],"both")==0;
    if(argc==6 && (![text(oldOutput,kAudioDevicePropertyDeviceUID)isEqualToString:@(argv[4])] ||
                  (both && ![text(oldSystem,kAudioDevicePropertyDeviceUID)isEqualToString:@(argv[5])]))) {
        fputs("Audio selection changed since planning; preserving current output\n",stderr);return 75;
    }
    OSStatus result=noErr;
    if(oldOutput!=target) result=selectOutput(kAudioHardwarePropertyDefaultOutputDevice,target);
    if(!result && both && oldSystem!=target) result=selectOutput(kAudioHardwarePropertyDefaultSystemOutputDevice,target);
    if(!result) {
        // Property application can settle asynchronously.
        for(int attempt=0;attempt<10;attempt++) {
            if(integer(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultOutputDevice)==target &&
               (!both || integer(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultSystemOutputDevice)==target)) return 0;
            usleep(50000);
        }
        result=kAudioHardwareUnspecifiedError;
    }
    OSStatus undoOutput=selectOutput(kAudioHardwarePropertyDefaultOutputDevice,oldOutput);
    OSStatus undoSystem=both?selectOutput(kAudioHardwarePropertyDefaultSystemOutputDevice,oldSystem):noErr;
    fail([NSString stringWithFormat:@"Audio selection failed (%d); rollback output=%d system=%d",result,undoOutput,undoSystem]);
}return 0; }
