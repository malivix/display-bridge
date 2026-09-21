// SPDX-License-Identifier: MIT
import Foundation
import CoreFoundation
import Darwin

enum PresetCommands {
    static let brightness:Set<String>=["brightness-list","brightness-save","brightness-apply","brightness-remove"]
    static let size:Set<String>=["preset-save","preset-remove"]
    static let all=brightness.union(size)
}

final class MenuOwnership {
    private let descriptor:Int32
    init?(path:String) {
        let handle=Darwin.open(path,O_CREAT|O_RDWR|O_NOFOLLOW,0o600)
        guard handle>=0 else{return nil}
        guard flock(handle,LOCK_EX|LOCK_NB)==0 else {Darwin.close(handle);return nil}
        descriptor=handle
    }
    deinit {Darwin.close(descriptor)}
}

// Runtime status is small JSON written by atomic replacement. Never follow a link or
// wait on a pipe on the AppKit thread; unknown/unreadable state stays unavailable.
func readMenuState(_ path:URL,limit:Int=1_048_576,allowMissing:Bool=false)->[String:Any]? {
    guard limit>0,limit<=1_048_576 else {return nil}
    let descriptor=Darwin.open(path.path,O_RDONLY|O_NONBLOCK|O_NOFOLLOW)
    guard descriptor>=0 else {return allowMissing && errno==ENOENT ? [:]:nil}
    defer {Darwin.close(descriptor)}
    var info=stat()
    guard fstat(descriptor,&info)==0,info.st_mode & mode_t(S_IFMT)==mode_t(S_IFREG),info.st_size>=0,info.st_size<=limit else {return nil}
    let file=FileHandle(fileDescriptor:descriptor,closeOnDealloc:false)
    guard let bytes=try? file.read(upToCount:limit+1),bytes.count<=limit,
          let value=try? JSONSerialization.jsonObject(with:bytes) as? [String:Any] else {return nil}
    return value
}

struct CommandResult {
    let output: String
    let code: Int32
}

func runMenuCommand(_ executable:URL,_ arguments:[String],timeout:Double=45,outputLimit:Int=1_048_576)->CommandResult {
    guard timeout.isFinite && timeout>0 && outputLimit>0 else {
        return CommandResult(output:"Invalid command limits",code:1)
    }
    let process=Process(),pipe=Pipe()
    process.executableURL=executable;process.arguments=arguments
    process.standardOutput=pipe;process.standardError=pipe
    let descriptor=pipe.fileHandleForReading.fileDescriptor
    defer {try? pipe.fileHandleForReading.close();try? pipe.fileHandleForWriting.close()}
    let flags=fcntl(descriptor,F_GETFL)
    guard flags>=0 && fcntl(descriptor,F_SETFL,flags|O_NONBLOCK)>=0 else {
        return CommandResult(output:"Cannot prepare command output",code:1)
    }
    do {try process.run()} catch {return CommandResult(output:error.localizedDescription,code:1)}
    try? pipe.fileHandleForWriting.close()
    let deadline=ProcessInfo.processInfo.systemUptime+timeout
    var output=Data(),buffer=[UInt8](repeating:0,count:65536)
    var failure:CommandResult?
    while true {
        if ProcessInfo.processInfo.systemUptime>=deadline {
            failure=CommandResult(output:"Command timed out. Check status before retrying; any queued controller work may still finish.",code:124)
            break
        }
        let count=Darwin.read(descriptor,&buffer,buffer.count)
        if count>0 {
            if output.count+count>outputLimit {
                failure=CommandResult(output:"Command output exceeded its limit. Check status before retrying.",code:125)
                break
            }
            output.append(contentsOf:buffer.prefix(count))
            continue
        }
        if count<0 && errno != EAGAIN && errno != EINTR {
            failure=CommandResult(output:"Could not read command output",code:1)
            break
        }
        if !process.isRunning && count==0 {break}
        Thread.sleep(forTimeInterval:0.01)
    }
    if let failure=failure {
        if process.isRunning {
            process.terminate()
            let grace=ProcessInfo.processInfo.systemUptime+0.25
            while process.isRunning && ProcessInfo.processInfo.systemUptime<grace {
                Thread.sleep(forTimeInterval:0.01)
            }
            if process.isRunning {kill(process.processIdentifier,SIGKILL)}
        }
        return failure
    }
    process.waitUntilExit()
    return CommandResult(output:String(decoding:output,as:UTF8.self),code:process.terminationStatus)
}

func menuCapabilities(_ probe:CommandResult)->Set<String>? {
    guard probe.code==0,let data=probe.output.data(using:.utf8),
          let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
          let protocolNumber=report["protocol"] as? NSNumber,CFGetTypeID(protocolNumber) != CFBooleanGetTypeID(),protocolNumber.doubleValue==1,
          let readOnly=report["read_only"] as? NSNumber,CFGetTypeID(readOnly)==CFBooleanGetTypeID(),readOnly.boolValue,
          let commands=report["commands"] as? [String],commands.count<=128,Set(commands).count==commands.count else{return nil}
    return Set(commands)
}
func percentageSupportReason(_ commands:Set<String>?,checking:Bool)->String? {
    if checking {return "Checking percentage control support…"}
    guard let commands=commands else {
        return "Percentage support is unverified. Open Show support details and check support."
    }
    guard commands.contains("monitor-set") else {
        return "This controller does not support percentage entry. Update the menu and controller together, then check support."
    }
    return nil
}

func presetCompatibilitySummary(_ commands:Set<String>?,checking:Bool)->String {
    if checking {return "Checking preset command support…"}
    guard let commands=commands else {return "Preset support could not be verified. Update the menu and controller together, then choose Check preset support. Status and recovery remain available."}
    let brightness=PresetCommands.brightness.isSubset(of:commands)
    let size=PresetCommands.size.isSubset(of:commands)
    return "Last support check: brightness presets \(brightness ? "available":"unavailable"); size preset saving/removal \(size ? "available":"unavailable")." + (brightness && size ? " Commands are checked again before use.":" Update the menu and controller together, then check again.")
}

// Probe only newer commands; preserve legacy inspection and recovery access.
func runCompatibleMenuCommand(_ arguments:[String],onPhase:(String,Double)->Void={_,_ in},runner:([String],Double,Int)->CommandResult)->CommandResult {
    if let action=arguments.first,(PresetCommands.all.contains(action) || ["capture-review","audio-test","installation-status","monitor-set"].contains(action)) {
        onPhase(action=="monitor-set" ? "Checking percentage control support":action=="installation-status" ? "Checking installation report support":action=="capture-review" ? "Checking enrollment review support":action=="audio-test" ? "Checking listening test support":"Checking preset support",5)
        let probe=runner(["capabilities"],5,16_384)
        let supported=menuCapabilities(probe)?.contains(action)==true
        guard supported else {return CommandResult(output:"This command requires a compatible controller. Update the menu and controller together from the same trusted source. The requested action was not sent; status and recovery remain available.",code:78)}
    }
    onPhase(operationTitle(arguments.first ?? ""),45)
    return runner(arguments,45,1_048_576)
}

func operationTitle(_ action:String)->String {
    let names=["installation-status":"Reading last installation","audio-test":"Playing quiet sample","capture-review":"Reviewing prospective enrollment","preset-remove":"Removing saved size preset","preset-save":"Saving named size preset","display-info":"Inspecting display modes","doctor":"Checking health","diagnostics":"Saving diagnostics","support-summary":"Preparing support summary","history":"Reading transition history",
        "ddc-history":"Reading monitor history","preview-options":"Inspecting size choices","monitor-settings":"Reading monitor settings",
        "monitor-adjust":"Adjusting monitor settings","monitor-set":"Applying requested percentage","preview-start":"Requesting size preview","preview-keep":"Requesting saved size",
        "brightness-list":"Reading saved brightness presets","brightness-save":"Saving current brightness","brightness-apply":"Applying saved brightness","brightness-remove":"Removing brightness preset",
        "preview-revert":"Requesting size restoration","preview-repair":"Requesting restoration retry",
        "repair-audio":"Requesting audio repair","pause":"Requesting pause","pause-for":"Requesting timed pause",
        "resume":"Requesting resume","audio-manual":"Saving audio override","audio-auto":"Requesting automatic audio",
        "speaker":"Saving speaker preference","rotation-auto":"Enabling automatic rotation","rotation-manual":"Disabling automatic rotation"]
    return names[action] ?? "Running command"
}
