// SPDX-License-Identifier: MIT
import AppKit
import UserNotifications
import Darwin
import CryptoKit

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
func presetCompatibilitySummary(_ commands:Set<String>?,checking:Bool)->String {
    if checking {return "Checking preset command support…"}
    guard let commands=commands else {return "Preset support could not be verified. Update the menu and controller together, then choose Check preset support. Status and recovery remain available."}
    let brightness=["brightness-list","brightness-save","brightness-apply","brightness-remove"].allSatisfy{commands.contains($0)}
    let size=["preset-save","preset-remove"].allSatisfy{commands.contains($0)}
    return "Last support check: brightness presets \(brightness ? "available":"unavailable"); size preset saving/removal \(size ? "available":"unavailable")." + (brightness && size ? " Commands are checked again before use.":" Update the menu and controller together, then check again.")
}

// Probe only newer commands; preserve legacy inspection and recovery access.
func runCompatibleMenuCommand(_ arguments:[String],onPhase:(String,Double)->Void={_,_ in},runner:([String],Double,Int)->CommandResult)->CommandResult {
    let guarded=["brightness-list","brightness-save","brightness-apply","brightness-remove","preset-save","preset-remove"]
    if let action=arguments.first,guarded.contains(action) {
        onPhase("Checking preset support",5)
        let probe=runner(["capabilities"],5,16_384)
        let supported=menuCapabilities(probe)?.contains(action)==true
        guard supported else {return CommandResult(output:"This command requires a compatible controller. Update the menu and controller together from the same trusted source. The requested action was not sent; status and recovery remain available.",code:78)}
    }
    onPhase(operationTitle(arguments.first ?? ""),45)
    return runner(arguments,45,1_048_576)
}

func controlsAvailable(_ control:[String:Any])->Bool {control["_read_unavailable"] as? Bool != true}
func safeWithoutControls(_ action:String)->Bool {
    ["panel","quit","status","doctor","setup","brightness-list","diagnostics","support-summary","history","ddc-history","display-info","monitor-settings","notifications","preview-revert","preview-repair"].contains(action)
}
func automationPaused(_ control:[String:Any],_ now:Double=Date().timeIntervalSince1970)->Bool {
    let until=control["pause_until"] as? Double ?? 0
    return control["paused"] as? Bool == true && (until==0 || until>now)
}
// Presentation only: hardware authorization remains in the controller.
func statusFresh(_ health:[String:Any],_ now:Double=Date().timeIntervalSince1970)->Bool {
    guard let updated=health["updated_at"] as? Double,updated.isFinite,now.isFinite else{return false}
    return now>=updated && now-updated<15
}
func statusAge(_ health:[String:Any],_ now:Double=Date().timeIntervalSince1970)->String {
    guard let updated=health["updated_at"] as? Double,updated.isFinite,now.isFinite,now>=updated else{return "Status age unavailable"}
    let age=min(now-updated,31536000)
    return "Last report: \(Int(age)) seconds ago"
}
func detailPrefix(_ health:[String:Any],_ control:[String:Any],_ now:Double=Date().timeIntervalSince1970)->String {
    statusFresh(health,now) && controlsAvailable(control) && health["status"] as? String == "ready" && !automationPaused(control,now) ? "":"Last known · "
}
func operationTitle(_ action:String)->String {
    let names=["preset-remove":"Removing saved size preset","preset-save":"Saving named size preset","display-info":"Inspecting display modes","doctor":"Checking health","diagnostics":"Saving diagnostics","support-summary":"Preparing support summary","history":"Reading transition history",
        "ddc-history":"Reading monitor history","preview-options":"Inspecting size choices","monitor-settings":"Reading monitor settings",
        "monitor-adjust":"Adjusting monitor settings","preview-start":"Requesting size preview","preview-keep":"Requesting saved size",
        "brightness-list":"Reading saved brightness presets","brightness-save":"Saving current brightness","brightness-apply":"Applying saved brightness","brightness-remove":"Removing brightness preset",
        "preview-revert":"Requesting size restoration","preview-repair":"Requesting restoration retry",
        "repair-audio":"Requesting audio repair","pause":"Requesting pause","pause-for":"Requesting timed pause",
        "resume":"Requesting resume","audio-manual":"Saving audio override","audio-auto":"Requesting automatic audio",
        "speaker":"Saving speaker preference","rotation-auto":"Enabling automatic rotation","rotation-manual":"Disabling automatic rotation"]
    return names[action] ?? "Running command"
}
func commandSummary(_ health:[String:Any],_ control:[String:Any])->String {
    if let error=health["command_tracking_error"] as? String {return error}
    guard let request=control["command_request"] as? [String:Any],let id=request["id"] as? String else{return ""}
    let action=request["action"] as? String ?? "command"
    guard let result=health["command_result"] as? [String:Any],
          let observed=result["request"] as? [String:Any],observed["id"] as? String == id else {
        return "Request saved (\(action)); controller acknowledgement not yet reported."
    }
    let titles=["policy-applied":"Preference acknowledged","verified":"Reconciliation verified",
        "applying":"Applying request","accepted":"Request accepted","deferred":"Request deferred",
        "failed":"Request failed","superseded":"Request superseded"]
    let state=result["state"] as? String ?? "unknown"
    let prefix=statusFresh(health) ? "":"Last reported · "
    return "\(prefix)\(titles[state] ?? "Unrecognized command result") (\(action))\n\(result["detail"] as? String ?? "")"
}
func speakerChoices(_ profile:String)->[(String,String)] {
    [("pg","PG42UQ"),("benq","BenQ"),("fallback","Built-in speakers"),("preserve","Preserve current output")].filter {
        !($0.0=="pg" && ["benq","away"].contains(profile)) && !($0.0=="benq" && ["pg","away"].contains(profile))
    }
}
func monitorControlReason(_ health:[String:Any],_ control:[String:Any],_ role:String,_ busy:Bool)->String? {
    if !controlsAvailable(control) {return "Saved controls are unreadable. Check health; setting changes are disabled."}
    if busy {return "Waiting for the current command and monitor readback."}
    if !statusFresh(health) {return "Controller status is unavailable. Check health first."}
    if automationPaused(control) {return "Resume automation to adjust monitor settings."}
    guard health["status"] as? String == "ready" else{return "Available after input switching or recovery completes."}
    guard let host=health["host"] as? String,["A","B"].contains(host),["pg","benq"].contains(role) else{return "Monitor ownership is not confirmed."}
    let inputs=health["inputs"] as? [String:Int] ?? [:]
    let expected=role=="pg" ? (host=="A" ? 17:18):(host=="A" ? 19:15)
    return inputs[role]==expected ? nil:"This monitor is not showing this Mac. No setting changes are available."
}
func audioRepairReason(_ health:[String:Any],_ control:[String:Any],_ busy:Bool,_ now:Double=Date().timeIntervalSince1970)->String? {
    if !controlsAvailable(control) {return "Saved controls are unreadable. Check health; setting changes are disabled."}
    if busy {return "Wait for the current command to finish."}
    if !statusFresh(health,now) {return "Controller status is unavailable; check health first."}
    if automationPaused(control,now) {return "Resume automation before repairing audio."}
    if (control["audio_manual_until"] as? Double ?? 0)>now {return "Resume automatic audio before repairing audio."}
    if !["ready","degraded"].contains(health["status"] as? String ?? "") {return "Wait for switching or preview recovery to finish; check health if it remains blocked."}
    if !["extended","pg","benq","away"].contains(health["profile"] as? String ?? "") {return "Monitor ownership is not confirmed."}
    return nil
}
func notificationCommand(_ identifier:String)->String? {
    switch identifier {
    case UNNotificationDefaultActionIdentifier:return "panel"
    case "repair":return "repair-audio"
    case "inspect":return "doctor"
    default:return nil
    }
}
func previewRemaining(_ health:[String:Any],_ now:Double=Date().timeIntervalSince1970)->Int {
    let age=now-(health["updated_at"] as? Double ?? 0)
    guard age>=0 && age<15,let preview=health["preview"] as? [String:Any],preview["state"] as? String == "preview",let remaining=preview["remaining_seconds"] as? Double,remaining.isFinite else{return 0}
    return Int(max(0,min(20,ceil(remaining-age))))
}
struct RecoveryAction: Equatable {
    let title:String
    let arguments:[String]
}
func recoveryAction(_ health:[String:Any],_ control:[String:Any],_ now:Double=Date().timeIntervalSince1970)->RecoveryAction? {
    let inspect=RecoveryAction(title:"Check health",arguments:["doctor"])
    guard statusFresh(health,now),controlsAvailable(control) else {return inspect}
    let state=health["status"] as? String ?? "unknown"
    if state=="state-error" {return inspect}
    if state.hasPrefix("preview-") {
        let preview=health["preview"] as? [String:Any] ?? [:]
        guard preview["state"] as? String == "needs-repair" else {return nil}
        guard let token=preview["token"] as? String,!token.isEmpty else {return inspect}
        return RecoveryAction(title:"Retry size restoration",arguments:["preview-repair","--token",token])
    }
    let recovery=health["recovery"] as? [String:Any] ?? [:]
    let pending=recovery["pending"] as? Bool == true || health["audio_journal_pending"] as? Bool == true
    guard pending,(recovery["attempts"] as? Int ?? 0)>=3 else {return nil}
    guard ["ready","degraded"].contains(state) else {return nil}
    guard audioRepairReason(health,control,false,now)==nil else {return inspect}
    return RecoveryAction(title:"Repair audio",arguments:["repair-audio"])
}
// Revalidate the presented action, including its preview token, without substituting a
// different mutation when the state changes between rendering and clicking.
func currentRecoveryArguments(_ presented:RecoveryAction?,_ health:[String:Any],_ control:[String:Any],_ busy:Bool,_ now:Double=Date().timeIntervalSince1970)->[String]? {
    guard !busy,let presented=presented,presented==recoveryAction(health,control,now) else {return nil}
    return presented.arguments
}
func recoverySummary(_ health:[String:Any],_ control:[String:Any],_ now:Double=Date().timeIntervalSince1970)->String {
    let recovery=health["recovery"] as? [String:Any] ?? [:]
    let state=health["status"] as? String ?? "unknown"
    let pending=recovery["pending"] as? Bool == true || health["audio_journal_pending"] as? Bool == true
    let attempts=max(0,min(3,recovery["attempts"] as? Int ?? 0))
    var lines:[String]=[]
    if !statusFresh(health,now) {lines.append("Recovery status is out of date. Check health before retrying; no current retry time is known.")}
    else if !controlsAvailable(control) {lines.append("Saved controls are unreadable. Check health and restore valid control settings; do not delete recovery journals.")}
    else if state=="state-error" {lines.append("Saved state needs attention. Check health and preserve the recovery files before restoring a known-good copy.")}
    else if state.hasPrefix("preview-") {
        let preview=health["preview"] as? [String:Any] ?? [:]
        switch preview["state"] as? String ?? "" {
        case "needs-repair":lines.append("Size restoration needs attention. Use Retry size restoration after checking health.")
        case "restore-deferred":lines.append("Size restoration is waiting for both monitors on this Mac and the original orientation. Keep the monitors connected.")
        case "preview":lines.append("Temporary size preview is active. Use Keep or Revert; automatic rollback is owned by the controller.")
        default:lines.append("Size preview recovery is in progress. Inspect Details for its current phase.")
        }
        if let error=preview["error"] as? String {lines.append("Last size error: "+String(error.prefix(1000)))}
    }
    else if automationPaused(control,now) {lines.append(pending ? "Recovery is pending while automation is paused. Resume automation when ready.":"Automation is paused; no pending recovery was reported.")}
    else if ["waiting-for-known-input","waiting-for-ddc","inactive-setup","settling"].contains(state) {
        lines.append("Waiting for stable, recognized monitor ownership. Layout changes are held; do not repeatedly request repair.")
    }
    else if pending && attempts>=3 {lines.append("Automatic recovery stopped after 3 attempts. Check health, then use Repair audio when available to retry reconciliation. Confirm sound by listening afterward.")}
    else if pending {
        lines.append("Recovery pending · \(attempts)/3 failed attempts.")
        if let delay=health["retry_in_seconds"] as? Double,delay.isFinite,delay>=0,delay<=30,
           let updated=health["updated_at"] as? Double {
            let remaining=Int(ceil(max(0,delay-(now-updated))))
            lines.append(remaining>0 ? "Retry eligible in about \(remaining) seconds, once ownership is stable.":"Retry is eligible when monitor ownership is stable.")
        } else {lines.append("Next retry time has not been reported.")}
    } else {lines.append("No pending recovery reported.")}
    if let reason=recovery["reason"] as? String,!reason.isEmpty {lines.append("Trigger: "+String(reason.prefix(300)))}
    if let error=health["error"] as? String ?? recovery["error"] as? String,!error.isEmpty {lines.append("Last error: "+String(error.prefix(1000)))}
    return lines.joined(separator:"\n")
}
func dashboard(_ health:[String:Any],_ control:[String:Any],_ now:Double=Date().timeIntervalSince1970)->String {
    let fresh=statusFresh(health,now)
    let state=fresh ? health["status"] as? String ?? "unknown":"unavailable"
    let titles=["starting":"Starting controller","waiting-for-known-input":"Unrecognized monitor input; layout changes held","ready":"Ready","waiting-for-ddc":"Waiting for monitor response","inactive-setup":"Saved monitor pair is not connected","paused":"Paused","degraded":"Recovery needs attention","state-error":"Saved settings need attention","unavailable":"Controller status unavailable","settling":"Waiting for stable inputs","recovering":"Recovering"]
    var lines=["\(controlsAvailable(control) ? (titles[state] ?? state):"Saved controls unavailable") · Mac \(health["host"] as? String ?? "?") · v\(health["version"] as? String ?? "—")"]
    if let preview=health["preview"] as? [String:Any],state.hasPrefix("preview-") {
        let phase=preview["state"] as? String ?? "unknown"
        let descriptions=["preparing":"Preparing size preview","preview":"Temporary size preview","restore-deferred":"Restoration waiting for both monitors and the original orientation","restore-pending":"Restoring your previous size","needs-repair":"Size restoration needs attention","kept":"New size saved for this orientation","reverted":"Previous size restored","request-rejected":"Preview request rejected"]
        lines=[descriptions[phase] ?? phase]
        if phase=="preview" {lines.append("\nKeep within \(previewRemaining(health,now)) seconds or the controller will restore the previous size.")}
        if let error=preview["error"] as? String {lines.append("\n\(error)")}
        lines.append("\nKeep applies to the current orientation only. Closing this window does not cancel automatic rollback. If inputs or orientation change, restoration waits until they return.")
        return lines.joined(separator:"\n")
    }
    let prefix=detailPrefix(health,control,now)
    let trusted=prefix.isEmpty
    lines.append(statusAge(health,now))
    if !trusted {lines.append("\nLast reported details below may be out of date. Run Check health for a fresh inspection.")}
    let inputs=health["inputs"] as? [String:Int] ?? [:]
    for (key,label,a,b) in [("pg","PG42UQ",17,18),("benq","BenQ RD280UG",19,15)] {
        let input=inputs[key]
        let owner=input==a ? "Mac A":input==b ? "Mac B":"Unknown input"
        lines.append("\n\(prefix)\(label): \(owner)")
    }
    let profile=health["profile"] as? String ?? "unknown"
    let profiles=["extended":"Two independent desktops","pg":"PG desktop; hidden BenQ mirrors PG","benq":"BenQ desktop; hidden PG mirrors BenQ","away":"Both away; previous desktop layout preserved"]
    lines.append("\n\(prefix)Desktop: \(profiles[profile] ?? "Not confirmed")")
    let rotation=health["rotation"] as? [String:Any] ?? [:]
    let automatic=control["auto_rotate"] as? Bool ?? true
    let angle=(rotation["sensor_degrees"] as? Int).map{"\($0)°"} ?? "not currently reported"
    lines.append("\(prefix)BenQ rotation: \(automatic ? "automatic":"manual") · sensor \(angle)")
    let audio=health["audio"] as? [String:Any] ?? [:],selected=audio["selected"] as? [String:Any] ?? [:]
    lines.append("\(prefix)Selected speaker: \(selected["name"] as? String ?? "Not reported")")
    lines.append("\n"+recoverySummary(health,control,now))
    if automationPaused(control,now) {
        if let until=control["pause_until"] as? Double,until>now {lines.append("\nAutomation resumes at \(Date(timeIntervalSince1970:until).formatted(date:.omitted,time:.shortened)).")}
        else {lines.append("\nAutomation is paused until you resume it from Controls.")}
    }
    lines.append("\nSettings and recovery details come from the controller. Speaker selection does not prove audible sound.")
    return lines.joined(separator:"\n")
}
struct StatusSection {
    let title:String
    let body:String
}
func statusSections(_ health:[String:Any],_ control:[String:Any])->[StatusSection] {
    let prefix=detailPrefix(health,control)
    let inputs=health["inputs"] as? [String:Int] ?? [:]
    let rotation=health["rotation"] as? [String:Any] ?? [:]
    let audio=health["audio"] as? [String:Any] ?? [:]
    let selected=audio["selected"] as? [String:Any] ?? [:]
    let headline=dashboard(health,control).components(separatedBy:"\n").first ?? "Status unavailable"
    func owner(_ role:String,_ a:Int,_ b:Int)->String {
        guard let input=inputs[role] else{return "Ownership not reported"}
        return input==a ? "Showing Mac A":input==b ? "Showing Mac B":"Unknown input; changes held"
    }
    let profile=health["profile"] as? String ?? "unknown"
    let layouts=["extended":"Two independent desktops","pg":"PG is the desktop; hidden BenQ mirrors PG",
                 "benq":"BenQ is the desktop; hidden PG mirrors BenQ","away":"Both monitors away; layout preserved"]
    let sensor=(rotation["sensor_degrees"] as? Int).map{"\($0)°"} ?? "unavailable"
    let audioOverride=(control["audio_manual_until"] as? Double ?? 0)>Date().timeIntervalSince1970
    let rotationMode = !controlsAvailable(control) ? "unavailable":rotation["enabled"] as? Bool != true ? "not calibrated":control["auto_rotate"] as? Bool == false ? "manual":"automatic"
    let routing = !controlsAvailable(control) ? "Saved audio preferences are unavailable":automationPaused(control) ? "Automation is paused":audioOverride ? "Manual output preservation is active":"Automatic routing follows profile preferences"
    return [
        StatusSection(title:"Overview",body:(health["status"] as? String ?? "").hasPrefix("preview-") ? dashboard(health,control):headline+"\n"+statusAge(health)+"\n"+prefix+(layouts[profile] ?? "Desktop not confirmed")),
        StatusSection(title:"PG42UQ",body:prefix+owner("pg",17,18)),
        StatusSection(title:"BenQ RD280UG",body:prefix+owner("benq",19,15)+"\n\(prefix)Rotation: \(rotationMode) · sensor \(sensor)"),
        StatusSection(title:"Audio",body:prefix+(selected["name"] as? String ?? "Output not reported")+"\n"+routing+"\nSpeaker selection does not prove audible sound."),
        StatusSection(title:"Recovery",body:recoverySummary(health,control))
    ]
}
func writeReviewedSummary(_ body:String,to pasteboard:NSPasteboard)->Bool {
    guard !body.isEmpty,body.utf8.count<=1_048_576 else{return false}
    pasteboard.clearContents()
    return pasteboard.setString(body,forType:.string)
}

struct ReviewedSupportSummary {
    private var text:String?
    mutating func show(_ report:String,_ body:String) {
        text=report=="support-summary" && !body.isEmpty && body.utf8.count<=1_048_576 ? body:nil
    }
    mutating func clear() {text=nil}
    func body(for report:String)->String? {report=="support-summary" ? text:nil}
}

struct DisplayReading {
    var report:[String:Any]?
    var failed=false
    mutating func accept(_ json:String)->Bool {
        guard let data=json.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
              let readOnly=value["read_only"] as? NSNumber,CFGetTypeID(readOnly)==CFBooleanGetTypeID(),readOnly.boolValue,
              let rows=value["displays"] as? [[String:Any]],rows.count==2,
              rows.compactMap({$0["monitor"] as? String}).sorted()==["benq","pg"] else {failed=true;return false}
        report=value;failed=false;return true
    }
    func notice(_ health:[String:Any],refreshing:Bool,now:Double=Date().timeIntervalSince1970)->String {
        if refreshing {return report==nil ? "Reading displays…":"Refreshing… previous snapshot shown below."}
        if failed {return report==nil ? "Refresh failed. No valid display snapshot available.":"Refresh failed. Previous snapshot retained; do not treat it as current."}
        guard let report=report else {return "No display snapshot yet. Choose Refresh display details."}
        guard statusFresh(health,now) else {return "Controller unavailable. Snapshot may be outdated; refresh after it recovers."}
        func inputs(_ value:Any?)->[Int]? {
            guard let value=value as? [String:Any],Set(value.keys)==Set(["pg","benq"]) else{return nil}
            var result:[Int]=[]
            for role in ["pg","benq"] {
                guard let n=value[role] as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),n.doubleValue.rounded()==n.doubleValue,
                      (role=="pg" ? [17.0,18.0]:[19.0,15.0]).contains(n.doubleValue) else{return nil}
                result.append(n.intValue)
            }
            return result
        }
        guard let observed=inputs(report["inputs"]),let current=inputs(health["inputs"]) else {return "Input comparison unavailable. Refresh after inputs are recognized."}
        if observed != current {return "Inputs changed since this snapshot. Refresh display details."}
        if health["status"] as? String != "ready" {return "Controller is not ready. Refresh after switching or recovery settles."}
        return "Snapshot only. Inputs still match; refresh after changing size or rotation."
    }
}

func layoutSummary(_ value:Any?)->String {
    guard let layout=value as? [String:Any],let state=layout["state"] as? String,
          let monitors=layout["monitors"] as? [[String:Any]],monitors.count==2,
          monitors.compactMap({$0["monitor"] as? String}).sorted()==["benq","pg"] else {return "Logical layout unavailable. Refresh after updating both helper and menu."}
    let relationships=["extended":"[PG42UQ]    [BenQ RD280UG]\nTwo independent desktops",
        "pg-source":"[PG42UQ] → [BenQ RD280UG]\nPG is the source; BenQ mirrors PG on this Mac",
        "benq-source":"[BenQ RD280UG] → [PG42UQ]\nBenQ is the source; PG mirrors BenQ on this Mac"]
    var lines=["Logical layout on this Mac — snapshot",relationships[state] ?? "Mirroring relationship not confirmed"]
    for role in ["pg","benq"] {
        let row=monitors.first{$0["monitor"] as? String==role}!
        let owner=row["owner"] as? String
        let ownership=["A","B"].contains(owner ?? "") ? "Showing Mac \(owner!)":"Input ownership unknown"
        var rotation="Rotation not reported"
        if let angle=row["rotation"] as? NSNumber,CFGetTypeID(angle) != CFBooleanGetTypeID(),[0.0,90,180,270].contains(angle.doubleValue) {rotation="macOS rotation \(angle.intValue)°"}
        lines.append("\(role=="pg" ? "PG42UQ":"BenQ RD280UG"): \(ownership) · \(rotation)")
    }
    lines.append("Arrow means source to mirror, not cable direction or physical position. Another Mac's desktop is not inspected.")
    return lines.joined(separator:"\n")
}

func displaySummary(_ json:String)->String {
    guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
          report["read_only"] as? Bool == true,let rows=report["displays"] as? [[String:Any]] else{return "Display snapshot could not be read. Refresh after switching settles."}
    var lines=["Read-only mode snapshot — use Refresh after changing inputs or display settings."]
    if let stamp=report["observed_at"] as? Double,stamp.isFinite {
        lines.append("Observed: \(Date(timeIntervalSince1970:stamp).formatted(date:.abbreviated,time:.standard))")
    }
    lines.append("\n"+layoutSummary(report["logical_layout"]))
    func size(_ value:Any?)->String {
        guard let mode=value as? [String:Any],let width=mode["width"] as? Int,let height=mode["height"] as? Int,
              let pixelsWide=mode["pixelWidth"] as? Int,let pixelsHigh=mode["pixelHeight"] as? Int else{return "Not available"}
        return "\(width) × \(height) logical; \(pixelsWide) × \(pixelsHigh) framebuffer"
    }
    for row in rows {
        lines.append("\n"+(row["monitor"] as? String == "pg" ? "PG42UQ":"BenQ RD280UG"))
        guard row["available"] as? Bool == true else {lines.append(row["reason"] as? String ?? "Not available");continue}
        lines.append("Measured: \(size(row["current"]))")
        lines.append("Saved: \(size(row["saved"]))")
        let hz=(row["hz"] as? Double).map{String(format:"%.2f Hz",$0)} ?? "Unknown refresh rate"
        let fixed=(row["fixed_refresh"] as? Bool).map{$0 ? "fixed":"variable or adaptive"} ?? "refresh type unknown"
        lines.append("\(hz) · \(fixed)")
        lines.append("2× HiDPI: \((row["hidpi"] as? Bool).map{$0 ? "yes":"no"} ?? "unknown")")
        lines.append("HDR preference: \((row["hdr_preference"] as? Bool).map{$0 ? "on":"off"} ?? "unknown")")
        lines.append("Saved mode match: \((row["saved_mode_matches"] as? Bool).map{$0 ? "yes":"no"} ?? "not available")")
    }
    lines.append("\n"+(report["limits"] as? String ?? "Readback does not establish optical quality."))
    return lines.joined(separator:"\n")
}
func healthSummary(_ json:String)->String {
    guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let checks=report["checks"] as? [[String:Any]] else{return "Health report could not be read. Save a diagnostic report for details."}
    var lines=["Read-only check: \(report["status"] as? String ?? "unknown")"]
    for check in checks {
        lines.append("\n\((check["status"] as? String ?? "?").uppercased()) · \(check["name"] as? String ?? "Check")\n\(check["detail"] as? String ?? "")")
        if let action=check["action"] as? String{lines.append(action)}
    }
    lines.append("\n\(report["limits"] as? String ?? "")")
    return lines.joined(separator:"\n")
}

func recognizedDisplayTools(_ bundleNames:[String])->[String] {
    // Advisory name matching only: never use this list to authorize or terminate apps.
    let known=["betterdisplay.app":"BetterDisplay","monitorcontrol.app":"MonitorControl","lunar.app":"Lunar","display pilot.app":"BenQ Display Pilot","display pilot 2.app":"BenQ Display Pilot 2"]
    return Set(bundleNames.compactMap{known[$0.lowercased()]}).sorted()
}
func displayToolSummary(_ bundleNames:[String]?)->String {
    guard let names=bundleNames else{return "Other display tools: not inspected."}
    let found=recognizedDisplayTools(names)
    if found.isEmpty {return "Other display tools\nNo recognized app bundles in this snapshot. Renamed apps, background services and command-line tools are not detected; this is not proof that no other controller is running."}
    return "Other display tools\nRunning: "+found.joined(separator:", ")+".\nRunning does not prove competing control. If settings change unexpectedly, review overlapping brightness, layout or rotation automation in these apps. Keep any app needed for custom display modes. Nothing was stopped.\nDetection covers recognized bundle names only, not renamed apps, background services or command-line tools."
}

func setupSummary(_ json:String,_ runningBundles:[String]?=nil)->String {
    guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],report["read_only"] as? Bool == true,let checks=report["checks"] as? [[String:Any]] else {return "Setup readiness is unavailable. Refresh the health report; no enrollment or settings were changed."}
    var lines=["Setup readiness · inspection only"]
    for required in ["Host enrollment","Rotation enrollment"] where !checks.contains(where:{$0["name"] as? String==required}) {
        lines.append("Not reported: "+required+". Inspect configuration errors below; an older controller may need a coordinated update.")
    }
    lines.append(healthSummary(json))
    lines.append(displayToolSummary(runningBundles))
    lines.append("Next steps\n1. Resolve the findings above. Missing information is unknown, not a pass.\n2. Enroll another Mac independently; never copy runtime identities or recovery journals.\n3. Confirm switching, rotation and audible sound physically after setup. This report cannot certify those results.")
    return lines.joined(separator:"\n\n")
}

func ddcSummary(_ json:String)->String {
    guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let episodes=report["episodes"] as? [[String:Any]],let count=report["ddc_interruptions"] as? Int else{return "DDC report could not be read. Save a diagnostic report for details."}
    let coverage=report["coverage"] as? [String:Any] ?? [:]
    var lines=["Monitor communication · current retained log", "\(coverage["first"] as? String ?? "No records") → \(coverage["last"] as? String ?? "No records")", "\nRecorded interruptions: \(count)", "Without a recorded recovery: \(report["without_recorded_recovery"] as? Int ?? 0)"]
    if let longest=report["longest_recorded_seconds"] as? Double {lines.append(String(format:"Longest recorded interruption: %.2f s",longest))}
    if episodes.isEmpty {lines.append("\nNo interruptions recorded in this log.")}
    else {
        lines.append("\nMost recent interruptions (up to 8)")
        for episode in episodes.suffix(8).reversed() {
            let duration=(episode["seconds"] as? Double).map{String(format:"%.2f s",$0)} ?? "duration unavailable"
            let recovered=episode["recovered"] as? String != nil
            lines.append("\(episode["started"] as? String ?? "—") · \(episode["monitor"] as? String ?? "unknown")\n\(recovered ? "Read recovered" : "No recovery recorded") · \(duration)")
        }
    }
    lines.append("\nBrief interruptions can occur while switching inputs. Automation waits for valid readings before changing the desktop. Persistent trouble: keep the inputs stable, run Check system health, then save diagnostics.")
    lines.append("\n\(report["limits"] as? String ?? "Retained logs only; this is not a hardware failure rate.")")
    return lines.joined(separator:"\n")
}

func timingSummary(_ json:String)->String {
    guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let profiles=report["profiles"] as? [String:[String:Any]] else{return "Timing report could not be read. Save a diagnostic report for details."}
    if report["history_available"] as? Bool == false {return "Transition history is unavailable or exceeds the read limit. Save private diagnostics to inspect it; no timing conclusion can be drawn."}
    var lines=["Measured application time — median / p95 / slowest"]
    for (key,label) in [("extended","Both monitors here"),("pg","Only PG here"),("benq","Only BenQ here"),("away","Both monitors away")] {
        guard let profile=profiles[key],let phases=profile["seconds"] as? [String:[String:Any]] else{continue}
        lines.append("\n\(label)")
        if let count=profile["count"] as? Int,count>=0 {lines.append("Completed records: \(count)")}
        if let failed=profile["failed_attempts"] as? Int,failed>=0 {lines.append("Failed attempts: \(failed) (may include retries)")}
        if phases.isEmpty {lines.append("No completed phase timings available.")}
        for (phase,name) in [("total","Application total"),("rotation_check","Rotation check and change"),("layout_apply","Layout application"),("input_confirmation","Input recheck"),("audio","Audio recovery"),("settling","Initial stable-read interval")] {
            guard let stats=phases[phase],let median=stats["median"] as? Double,let maximum=stats["max"] as? Double,median.isFinite,maximum.isFinite,median>=0,maximum>=0 else{continue}
            let count=stats["count"] as? Int
            let sampleText=count.map{$0>=0 ? "\($0) samples":"sample count unavailable"} ?? "sample count unavailable"
            let percentile=stats["p95"] as? Double
            let p95=percentile.map{$0.isFinite && $0>=0 ? String(format:"%.2f",$0):"unavailable"} ?? "unavailable"
            lines.append(String(format:"%@: %.2f / %@ / %.2f s (%@)",name,median,p95,maximum,sampleText))
        }
    }
    if profiles.isEmpty{lines.append("\nNo completed transitions recorded yet.")}
    lines.append("\nPhysical input-switch time before the first valid reading is not measured. The stable-read interval is separate from application time. p95 is the nearest-rank 95th percentile; small samples are not a reliable performance baseline. Older records lack the rotation/layout breakdown. Sound still requires listening.")
    return lines.joined(separator:"\n")
}

func failureIncident(_ health:[String:Any])->String? {
    let state=health["status"] as? String ?? ""
    guard ["degraded","state-error","preview-needs-repair"].contains(state) else{return nil}
    let recovery=health["recovery"] as? [String:Any] ?? [:]
    let preview=health["preview"] as? [String:Any] ?? [:]
    // Do not fingerprint timestamps or attempt counters: retries are the same incident.
    let origin=(health["error"] as? String ?? "").components(separatedBy:":").first ?? ""
    let fields=[state,health["profile"] as? String ?? "",recovery["reason"] as? String ?? "",
                state=="state-error" ? origin:"",preview["token"] as? String ?? ""]
    let data=(try? JSONSerialization.data(withJSONObject:fields)) ?? Data()
    return SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
}
struct FailureAlerts {
    struct Attempt {let id:UUID;let incident:String}
    var sent:[String]=[]
    var pending:Attempt?
    mutating func reserve(_ incident:String)->Attempt? {
        guard pending==nil,!sent.contains(incident),sent.count<16 else{return nil}
        let attempt=Attempt(id:UUID(),incident:incident);pending=attempt;return attempt
    }
    func current(_ attempt:Attempt)->Bool {pending?.id==attempt.id}
    mutating func finish(_ attempt:Attempt,success:Bool) {
        guard current(attempt) else{return}
        if success {sent.append(attempt.incident)}
        pending=nil
    }
    mutating func clear() {sent=[];pending=nil}
}
// Synthetic states never read or mutate the installed controller.
func demoState(_ scenario:String,_ name:String,_ now:Double)->[String:Any] {
    if name=="control.json" {return scenario=="controls-error" ? ["_read_unavailable":true]:scenario=="paused" ? ["paused":true]:[:]}
    guard name=="health.json" else {return [:]}
    var health:[String:Any] = ["host":"A","version":"Demo","updated_at":now,
        "status":"ready","profile":"extended","inputs":["pg":17,"benq":19],
        "rotation":["enabled":true,"sensor_degrees":90],"audio":["selected":["name":"Example monitor speakers"]]]
    switch scenario {
    case "stale":health["updated_at"]=now-90
    case "paused":health["status"]="paused"
    case "away":health["profile"]="away";health["inputs"]=["pg":18,"benq":15]
    case "preview":
        health["status"]="preview-preview"
        health["preview"]=["state":"preview","token":"synthetic-preview","remaining_seconds":20.0]
    case "recovery-wait":
        health["status"]="recovering";health["retry_in_seconds"]=8.0
        health["recovery"]=["pending":true,"attempts":2,"reason":"input transition","error":"Synthetic monitor response timed out"]
    case "recovery":
        health["status"]="degraded"
        health["recovery"]=["pending":true,"attempts":3,"error":"Audio recovery exhausted after three attempts. Inspect health before retrying."]
    default:break
    }
    return health
}
if CommandLine.arguments.contains("--self-test") {
    let stateFolder=FileManager.default.temporaryDirectory.appendingPathComponent("display-state-test-"+UUID().uuidString)
    try! FileManager.default.createDirectory(at:stateFolder,withIntermediateDirectories:true)
    let statePath=stateFolder.appendingPathComponent("health.json")
    try! Data("{\"status\":\"ready\"}".utf8).write(to:statePath)
    precondition(readMenuState(statePath)?["status"] as? String == "ready")
    precondition(readMenuState(statePath,limit:4)==nil)
    let link=stateFolder.appendingPathComponent("link")
    try! FileManager.default.createSymbolicLink(at:link,withDestinationURL:statePath)
    precondition(readMenuState(link)==nil)
    let pipe=stateFolder.appendingPathComponent("pipe")
    precondition(mkfifo(pipe.path,0o600)==0)
    precondition(readMenuState(pipe)==nil)
    for invalid in ["{broken","[]"] {
        try! Data(invalid.utf8).write(to:statePath)
        precondition(readMenuState(statePath)==nil)
    }
    try! FileManager.default.removeItem(at:stateFolder)
    precondition(readMenuState(statePath)==nil)
    precondition(readMenuState(statePath,allowMissing:true)?.isEmpty==true)
    let missingControl:[String:Any]=["_read_unavailable":true]
    precondition(!controlsAvailable(missingControl) && controlsAvailable([:]))
    precondition(safeWithoutControls("doctor") && safeWithoutControls("preview-revert") && !safeWithoutControls("preview-start"))
    precondition(monitorControlReason([:],missingControl,"pg",false) != nil)
    precondition(audioRepairReason([:],missingControl,false) != nil)
    precondition(dashboard(["status":"ready","updated_at":100.0],missingControl,101).hasPrefix("Saved controls unavailable"))
    print("PASS bounded regular-file menu state reads and unavailable controls")
    let lockPath=FileManager.default.temporaryDirectory.appendingPathComponent("display-menu-test-"+UUID().uuidString).path
    var firstOwner=MenuOwnership(path:lockPath)
    precondition(firstOwner != nil)
    precondition(MenuOwnership(path:lockPath)==nil,"Only one menu may own heartbeat and notifications")
    firstOwner=nil
    let nextOwner=MenuOwnership(path:lockPath)
    precondition(nextOwner != nil,"Exited owner's lock must be reusable")
    try? FileManager.default.removeItem(atPath:lockPath)
    print("PASS exclusive menu ownership and release")
    let commandStarted=ProcessInfo.processInfo.systemUptime
    let timed=runMenuCommand(URL(fileURLWithPath:"/bin/sleep"),["2"],timeout:0.1)
    precondition(timed.code==124,"Menu command must stop at its deadline")
    precondition(ProcessInfo.processInfo.systemUptime-commandStarted<1.5)
    let echo=runMenuCommand(URL(fileURLWithPath:"/bin/echo"),["ready"])
    precondition(echo.code==0 && echo.output=="ready\n")
    let failed=runMenuCommand(URL(fileURLWithPath:"/usr/bin/false"),[])
    precondition(failed.code != 0)
    let noisy=runMenuCommand(URL(fileURLWithPath:"/usr/bin/yes"),[],outputLimit:1024)
    precondition(noisy.code==125)
    print("PASS menu command completion, failure, deadline, and output limit")

    precondition(previewRemaining(["updated_at":100.0,"preview":["state":"preview","remaining_seconds":20.0]],105)==15)
    precondition(previewRemaining(["updated_at":100.0,"preview":["state":"preview","remaining_seconds":20.0]],120)==0)
    let live:[String:Any]=["updated_at":100.0,"status":"ready","host":"A","inputs":["pg":17,"benq":15],"profile":"pg"]
    precondition(dashboard(live,[:],101).contains("PG42UQ: Mac A"))
    precondition(dashboard(live,[:],101).contains("BenQ RD280UG: Mac B"))
    precondition(!dashboard(live,[:],101).contains("may be out of date"))
    precondition(dashboard(live,[:],120).contains("may be out of date"))
    precondition(dashboard(live,[:],120).contains("Last known · PG42UQ"),"Stale monitor ownership must be labeled at the value")
    precondition(dashboard(live,[:],120).contains("Last known · Selected speaker"))
    precondition(dashboard(live,[:],99).contains("Controller status unavailable"))
    var waiting=live;waiting["status"]="waiting-for-ddc"
    precondition(dashboard(waiting,[:],101).contains("may be out of date"))
    precondition(statusFresh(live,101))
    precondition(!statusFresh(live,115) && !statusFresh(live,99))
    precondition(!statusFresh([:],0))
    precondition(!statusFresh(["updated_at":Double.infinity],101))
    precondition(statusAge(["updated_at":Double.nan],101)=="Status age unavailable")
    precondition(statusAge(live,120)=="Last report: 20 seconds ago")
    precondition(!detailPrefix(live,["paused":true],101).isEmpty)
    let monitorHealth:[String:Any]=["host":"A","status":"ready","updated_at":Date().timeIntervalSince1970,"inputs":["pg":17,"benq":15]]
    precondition(monitorControlReason(monitorHealth,[:],"pg",false)==nil)
    precondition(monitorControlReason(monitorHealth,[:],"benq",false) != nil)
    precondition(monitorControlReason(monitorHealth,["paused":true],"pg",false) != nil)
    precondition(monitorControlReason(monitorHealth,[:],"pg",true) != nil)
    precondition(monitorControlReason([:],[:],"pg",false) != nil)
    precondition(speakerChoices("away").map{$0.0}==["fallback","preserve"])
    precondition(!speakerChoices("benq").contains{$0.0=="pg"})
    precondition(audioRepairReason([:],[:],false) != nil)
    let audioHealth:[String:Any]=["updated_at":Date().timeIntervalSince1970,"status":"ready","profile":"extended"]
    precondition(audioRepairReason(audioHealth,[:],false)==nil)
    precondition(audioRepairReason(audioHealth,["paused":true],false) != nil)
    precondition(audioRepairReason(audioHealth,[:],true) != nil)
    precondition(audioRepairReason(audioHealth,["audio_manual_until":Date().timeIntervalSince1970+60],false) != nil)
    let sectionHealth:[String:Any]=["status":"ready","updated_at":Date().timeIntervalSince1970,"inputs":["pg":17,"benq":15],"profile":"pg"]
    let sections=statusSections(sectionHealth,[:])
    precondition(sections.map{$0.title}==["Overview","PG42UQ","BenQ RD280UG","Audio","Recovery"])
    precondition(sections[1].body=="Showing Mac A" && sections[2].body.contains("Showing Mac B"))
    precondition(statusSections([:],[:])[1].body.contains("Last known"))
    let previewSections=statusSections(["updated_at":Date().timeIntervalSince1970,"status":"preview-active","preview":["state":"preview","remaining_seconds":20.0]],[:])
    precondition(previewSections[0].body.contains("Keep within"))
    let retryHealth:[String:Any]=["updated_at":100.0,"status":"recovering","retry_in_seconds":8.0,"recovery":["pending":true,"attempts":2]]
    precondition(recoverySummary(retryHealth,[:],103).contains("about 5 seconds"))
    precondition(!recoverySummary(retryHealth,[:],120).contains("eligible"),"Stale data must not promise a retry")
    precondition(recoverySummary(retryHealth,["paused":true],103).contains("paused"))
    var exhausted=retryHealth;exhausted["recovery"]=["pending":true,"attempts":3]
    precondition(recoverySummary(exhausted,[:],103).contains("stopped after 3"))
    var badRetry=retryHealth;badRetry["retry_in_seconds"]=Double.infinity
    precondition(recoverySummary(badRetry,[:],103).contains("not been reported"))
    var held=retryHealth;held["status"]="waiting-for-known-input"
    precondition(recoverySummary(held,[:],103).contains("changes are held"))
    var repairHealth:[String:Any]=["updated_at":100.0,"status":"degraded","profile":"extended","recovery":["pending":true,"attempts":3]]
    let repair=recoveryAction(repairHealth,[:],103)!
    precondition(repair.arguments==["repair-audio"])
    precondition(recoveryAction(repairHealth,[:],120)?.arguments==["doctor"])
    precondition(recoveryAction(repairHealth,["paused":true],103)?.arguments==["doctor"])
    precondition(recoveryAction(repairHealth,["audio_manual_until":200.0],103)?.arguments==["doctor"])
    precondition(recoveryAction(repairHealth,missingControl,103)?.arguments==["doctor"])
    precondition(currentRecoveryArguments(repair,repairHealth,[:],true,103)==nil)
    precondition(currentRecoveryArguments(repair,repairHealth,[:],false,120)==nil)
    precondition(currentRecoveryArguments(repair,repairHealth,[:],false,103)==["repair-audio"])
    for state in ["settling","recovering","waiting-for-ddc","waiting-for-known-input"] {
        var waiting=repairHealth;waiting["status"]=state
        precondition(recoveryAction(waiting,[:],103)==nil)
    }
    repairHealth["status"]="preview-recovery";repairHealth["preview"]=["state":"needs-repair","token":"example-one"]
    let restoration=recoveryAction(repairHealth,[:],103)!
    precondition(restoration.arguments==["preview-repair","--token","example-one"])
    repairHealth["preview"]=["state":"needs-repair","token":"example-two"]
    precondition(currentRecoveryArguments(restoration,repairHealth,[:],false,103)==nil)
    repairHealth["preview"]=["state":"needs-repair"]
    precondition(recoveryAction(repairHealth,[:],103)?.arguments==["doctor"])
    repairHealth["preview"]=["state":"restore-deferred"]
    precondition(recoveryAction(repairHealth,[:],103)==nil)
    precondition(recoveryAction(["updated_at":100.0,"status":"ready"],[:],103)==nil)
    print("PASS contextual recovery actions, stale clicks, busy state and changed preview tokens")
    let comparisonCurrent:[String:Any]=["modes":["pg":["width":1920,"height":1080,"pixelWidth":3840,"pixelHeight":2160]]]
    let comparisonLarger:[String:Any]=["modes":["pg":["width":1536,"height":864,"pixelWidth":3072,"pixelHeight":1728]]]
    precondition(sizeComparison(comparisonCurrent,comparisonLarger).contains("25% larger"))
    precondition(sizeComparison(comparisonLarger,comparisonCurrent).contains("20% smaller"))
    precondition(sizeComparison(comparisonCurrent,comparisonCurrent).contains("unchanged"))
    precondition(sizeComparison([:],comparisonLarger).contains("estimate unavailable"))
    precondition(sizeComparison(comparisonCurrent,["modes":["pg":["width":Double.infinity]]]).contains("estimate unavailable"))
    precondition(sizeComparison(comparisonCurrent,comparisonLarger).contains("3840 × 2160 → 3072 × 1728"))
    print("PASS size comparison direction, missing dimensions and framebuffer labels")
    precondition(presetNameError("Reading")==nil)
    precondition(presetNameError(String(repeating:"a",count:48))==nil)
    for invalid in ["",String(repeating:"a",count:49)," Reading","Reading ","a\u{7F}b","a\nb","\u{85}Reading",String(repeating:"e\u{301}",count:25)] {
        precondition(presetNameError(invalid) != nil)
    }
    precondition(presetNameError("Reading 🌙")==nil)
    print("PASS preset names match code-point limits, whitespace and control-character rules")
    precondition(recognizedDisplayTools(["BetterDisplay.app","betterdisplay.app","NotBetterDisplay.app","Private editor.app"])==["BetterDisplay"])
    precondition(recognizedDisplayTools(["Lunar.app","MonitorControl.app"])==["Lunar","MonitorControl"])
    precondition(displayToolSummary(nil).contains("not inspected"))
    precondition(displayToolSummary([]).contains("not proof"))
    precondition(!displayToolSummary(["Private editor.app"]).contains("Private editor"))
    precondition(displayToolSummary(["BetterDisplay.app"]).contains("Nothing was stopped"))
    print("PASS advisory display-tool recognition, deduplication and unrelated-app omission")
    precondition(setupSummary("{}").contains("unavailable"))
    precondition(setupSummary("{\"read_only\":true,\"checks\":[]}").contains("Not reported: Host enrollment"))
    precondition(setupSummary("{\"read_only\":true,\"checks\":[]}").contains("older controller"))
    precondition(safeWithoutControls("setup"))
    print("PASS setup readiness marks missing enrollment information unknown")
    precondition(panelShortcut("3",.command,false) == .tab("displays"))
    precondition(panelShortcut("R",[.command,.capsLock],false) == .refresh)
    for modifiers:NSEvent.ModifierFlags in [[],.control,[.command,.shift],[.command,.option]] {
        precondition(panelShortcut("1",modifiers,false)==nil)
    }
    precondition(panelShortcut("r",.command,true)==nil)
    precondition(panelShortcut("6",.command,false)==nil)
    precondition(panelRefreshArguments("details","setup","pg")==["setup"])
    precondition(panelRefreshArguments("details","status","pg")==nil)
    precondition(panelRefreshArguments("details","repair-audio","pg")==nil)
    precondition(panelRefreshArguments("displays","status","pg")==["display-info"])
    precondition(panelRefreshArguments("monitor-controls","status","benq")==["monitor-settings","--monitor","benq"])
    precondition(panelRefreshArguments("monitor-controls","status","unknown")==nil)
    precondition(panelRefreshArguments("audio","status","pg")==nil)
    print("PASS window shortcuts, modifier isolation, repeat suppression and read-only refresh targets")
    precondition(presetCompatibilitySummary(nil,checking:true).contains("Checking"))
    precondition(presetCompatibilitySummary(nil,checking:false).contains("could not be verified"))
    precondition(presetCompatibilitySummary([],checking:false).contains("brightness presets unavailable"))
    precondition(presetCompatibilitySummary(Set(["preset-save","preset-remove"]),checking:false).contains("size preset saving/removal available"))
    print("PASS unknown, checking, unsupported and partial preset availability labels")
    let supportedReport="{\"protocol\":1,\"read_only\":true,\"commands\":[\"brightness-save\"]}"
    for report in [CommandResult(output:supportedReport,code:0),CommandResult(output:supportedReport,code:124),CommandResult(output:"{}",code:0),CommandResult(output:supportedReport.replacingOccurrences(of:"brightness-save",with:"status"),code:0),CommandResult(output:supportedReport.replacingOccurrences(of:"protocol\":1",with:"protocol\":true"),code:0)] {
        var calls:[[String]]=[];var phases:[String]=[];var deadlines:[Double]=[]
        let result=runCompatibleMenuCommand(["brightness-save","--monitor","pg"],onPhase:{name,deadline in phases.append(name);deadlines.append(deadline)}){args,timeout,limit in
            calls.append(args)
            if args==["capabilities"] {precondition(timeout==5 && limit==16_384);return report}
            return CommandResult(output:"requested",code:0)
        }
        let valid=report.code==0 && report.output==supportedReport
        precondition(calls.count==(valid ? 2:1) && result.code==(valid ? 0:78))
        precondition(phases.first=="Checking preset support" && phases.count==(valid ? 2:1))
        precondition(deadlines==(valid ? [5,45]:[5]))
        if valid {precondition(phases.last==operationTitle("brightness-save"))}
    }
    var recoveryCalls:[[String]]=[];var recoveryDeadlines:[Double]=[]
    _=runCompatibleMenuCommand(["preview-revert","--token","example"],onPhase:{_,deadline in recoveryDeadlines.append(deadline)}){args,_,_ in recoveryCalls.append(args);return CommandResult(output:"legacy",code:0)}
    precondition(recoveryCalls==[["preview-revert","--token","example"]] && recoveryDeadlines==[45])
    print("PASS capability preflight blocks unsupported commands and preserves legacy recovery")
    var brightnessSample:[String:Any]=["read_only":true,"monitor":"benq","presets":[["name":"Reading","monitor":"benq","value":15,"maximum":50,"revision":String(repeating:"a",count:64)]]]
    func brightnessJSON(_ report:[String:Any])->String {String(data:try! JSONSerialization.data(withJSONObject:report),encoding:.utf8)!}
    precondition(brightnessEntries(brightnessJSON(brightnessSample))?.entries.first?.description.contains("30%") == true)
    precondition(brightnessEntries(brightnessJSON(brightnessSample),"pg")==nil)
    precondition(brightnessEntries(brightnessJSON(brightnessSample),"benq") != nil)
    precondition(brightnessEntries("{}")==nil)
    for patch in [["value":true],["value":51],["maximum":0],["revision":"stale"],["monitor":"pg"]] as [[String:Any]] {
        var sample=brightnessSample;var entry=(sample["presets"] as! [[String:Any]])[0]
        entry.merge(patch){_,new in new};sample["presets"]=[entry]
        precondition(brightnessEntries(brightnessJSON(sample))==nil)
    }
    let brightnessRow=(brightnessSample["presets"] as! [[String:Any]])[0]
    brightnessSample["presets"]=[brightnessRow,brightnessRow]
    precondition(brightnessEntries(brightnessJSON(brightnessSample))==nil)
    brightnessSample["presets"]=[]
    precondition(brightnessEntries(brightnessJSON(brightnessSample))?.entries.isEmpty == true)
    print("PASS brightness list targets, ranges, revisions, duplicate names and empty states")
    let trackedRequest:[String:Any]=["id":"example","action":"resume"]
    precondition(commandSummary([:],["command_request":trackedRequest]).contains("not yet reported"))
    let trackedHealth:[String:Any]=["updated_at":Date().timeIntervalSince1970,"command_result":["request":trackedRequest,"state":"deferred","detail":"Waiting for input"]]
    precondition(commandSummary(trackedHealth,["command_request":trackedRequest]).contains("Request deferred"))
    precondition(commandSummary(trackedHealth,["command_request":["id":"new","action":"pause"]]).contains("not yet reported"))
    precondition(commandSummary(["command_tracking_error":"Damaged history"],[:])=="Damaged history")
    precondition(notificationCommand(UNNotificationDefaultActionIdentifier)=="panel")
    precondition(notificationCommand("inspect")=="doctor")
    precondition(notificationCommand("repair")=="repair-audio")
    precondition(notificationCommand(UNNotificationDismissActionIdentifier)==nil)
    precondition(notificationCommand("unknown")==nil)
    precondition(operationTitle("preview-options")=="Inspecting size choices")
    print("PASS status freshness, stale labels, progress labels and notification routing")
    precondition(automationPaused(["paused":true,"pause_until":200.0],100))
    precondition(!automationPaused(["paused":true,"pause_until":200.0],200))
    precondition(automationPaused(["paused":true],200))
    var reviewed=ReviewedSupportSummary()
    precondition(reviewed.body(for:"support-summary")==nil)
    reviewed.show("doctor","private details")
    precondition(reviewed.body(for:"support-summary")==nil)
    reviewed.show("support-summary","reviewed report")
    precondition(reviewed.body(for:"support-summary")=="reviewed report")
    precondition(reviewed.body(for:"status")==nil)
    reviewed.clear();precondition(reviewed.body(for:"support-summary")==nil)
    reviewed.show("support-summary",String(repeating:"x",count:1_048_577))
    precondition(reviewed.body(for:"support-summary")==nil)
    print("PASS reviewed-summary copy scope, invalidation and size bound; clipboard untouched")
    var reading=DisplayReading()
    let snapshotJSON="{\"read_only\":true,\"inputs\":{\"pg\":17,\"benq\":19},\"displays\":[{\"monitor\":\"pg\"},{\"monitor\":\"benq\"}]}"
    var snapshotHealth:[String:Any]=["updated_at":100.0,"status":"ready","inputs":["pg":17,"benq":19]]
    precondition(reading.notice(snapshotHealth,refreshing:false,now:100).contains("No display snapshot"))
    precondition(reading.accept(snapshotJSON))
    precondition(reading.notice(snapshotHealth,refreshing:false,now:100).contains("Inputs still match"))
    precondition(reading.notice(snapshotHealth,refreshing:false,now:120).contains("Controller unavailable"))
    snapshotHealth["inputs"]=["pg":18,"benq":19]
    precondition(reading.notice(snapshotHealth,refreshing:false,now:100).contains("Inputs changed"))
    snapshotHealth["inputs"]=["pg":true,"benq":19]
    precondition(reading.notice(snapshotHealth,refreshing:false,now:100).contains("comparison unavailable"))
    precondition(!reading.accept("{}") && reading.report != nil)
    precondition(reading.notice(snapshotHealth,refreshing:false,now:100).contains("Previous snapshot retained"))
    precondition(reading.notice(snapshotHealth,refreshing:true,now:100).contains("Refreshing"))
    precondition(reading.accept(snapshotJSON) && !reading.failed)
    print("PASS snapshot input comparison, stale health, failed refresh preservation and recovery")
    let sampleLayout:[String:Any]=["state":"pg-source","monitors":[["monitor":"pg","owner":"A","rotation":0],["monitor":"benq","owner":"B","rotation":90]]]
    precondition(layoutSummary(sampleLayout).contains("BenQ mirrors PG"))
    precondition(layoutSummary(sampleLayout).contains("Showing Mac B"))
    precondition(layoutSummary(nil).contains("unavailable"))
    var unknownLayout=sampleLayout;unknownLayout["state"]="unexpected"
    precondition(layoutSummary(unknownLayout).contains("not confirmed"))
    unknownLayout["monitors"]=[["monitor":"pg"],["monitor":"pg"]]
    precondition(layoutSummary(unknownLayout).contains("unavailable"))
    print("PASS logical layout direction, remote ownership and unknown topology labels")
    precondition(displaySummary("invalid").contains("could not be read"))
    precondition(displaySummary("{\"read_only\":true,\"displays\":[{\"monitor\":\"pg\",\"available\":false,\"reason\":\"Away\"}]}").contains("Away"))
    precondition(healthSummary("{\"status\":\"ok\",\"checks\":[]}").contains("Read-only check: ok"))
    precondition(ddcSummary("invalid").contains("could not be read"))
    precondition(ddcSummary("{\"episodes\":[],\"ddc_interruptions\":0}").contains("No interruptions recorded"))
    let ddc=ddcSummary("{\"ddc_interruptions\":1,\"episodes\":[{\"started\":\"now\",\"monitor\":\"benq\",\"seconds\":1.25,\"recovered\":\"later\"}]}")
    precondition(ddc.contains("Read recovered · 1.25 s") && ddc.contains("benq"))
    var alerts=FailureAlerts()
    let broken:[String:Any]=["status":"degraded","profile":"pg","recovery":["reason":"audio"]]
    let first=failureIncident(broken)!
    var retry=broken;retry["updated_at"]=123;retry["recovery"]=["reason":"audio","attempts":3]
    precondition(failureIncident(retry)==first)
    for state in ["ready","recovering","settling","paused","waiting-for-ddc","inactive-setup"] {
        precondition(failureIncident(["status":state])==nil)
    }
    let attempt=alerts.reserve(first)!
    precondition(alerts.reserve(first)==nil)
    alerts.finish(attempt,success:false)
    let retryAttempt=alerts.reserve(first)!
    alerts.finish(retryAttempt,success:true)
    precondition(alerts.reserve(first)==nil)
    let different=failureIncident(["status":"state-error","error":"control.json: invalid"])!
    precondition(different != first)
    let second=alerts.reserve(different)!
    alerts.clear()
    let afterRecovery=alerts.reserve(first)!
    alerts.finish(second,success:true)
    precondition(alerts.current(afterRecovery) && alerts.sent.isEmpty)
    alerts.finish(afterRecovery,success:true)
    var restartedAlerts=FailureAlerts(sent:alerts.sent)
    precondition(restartedAlerts.reserve(first)==nil)
    print("PASS distinct incidents, retry deduplication, failed delivery and late callbacks")
    precondition(timingSummary("{\"profiles\":{}}").contains("No completed transitions"))
    precondition(timingSummary("{\"history_available\":false,\"profiles\":{}}").contains("no timing conclusion"))
    precondition(timingSummary("invalid").contains("could not be read"))
    let timing=timingSummary("{\"profiles\":{\"extended\":{\"count\":4,\"seconds\":{\"total\":{\"median\":2,\"max\":5,\"count\":3}}}}}")
    precondition(timing.contains("Both monitors here") && timing.contains("2.00 / unavailable / 5.00 s (3 samples)"))
    let failures=timingSummary("{\"profiles\":{\"benq\":{\"count\":0,\"failed_attempts\":3,\"seconds\":{}}}}")
    precondition(failures.contains("Failed attempts: 3") && failures.contains("No completed phase timings"))
    let percentiles=timingSummary("{\"profiles\":{\"pg\":{\"count\":5,\"seconds\":{\"total\":{\"median\":2,\"p95\":4,\"max\":5,\"count\":4}}}}}")
    precondition(percentiles.contains("2.00 / 4.00 / 5.00 s (4 samples)"))
    print("PASS notification policy: persistent failure only, deduplication, freshness and re-arm")
    exit(0)
}
// Opt-in API integration test. A unique named pasteboard never touches the general clipboard.
if CommandLine.arguments.contains("--test-private-pasteboard") {
    let board=NSPasteboard(name:NSPasteboard.Name("io.github.display-bridge.test."+UUID().uuidString))
    guard board.setString("previous private test value",forType:.string) else {fatalError("Private pasteboard unavailable")}
    precondition(!writeReviewedSummary("",to:board))
    precondition(board.string(forType:.string)=="previous private test value")
    let report="Reviewed support summary\nSynthetic Unicode text: café · 2 transitions"
    precondition(writeReviewedSummary(report,to:board))
    precondition(board.string(forType:.string)==report)
    precondition(!writeReviewedSummary(String(repeating:"x",count:1_048_577),to:board))
    precondition(board.string(forType:.string)==report)
    board.releaseGlobally()
    print("PASS private pasteboard exact copy and invalid-input preservation; general clipboard untouched")
    exit(0)
}
if CommandLine.arguments.contains("--test-notification") {
    let center=UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
        guard settings.authorizationStatus == .authorized else {print("Notifications not authorized");exit(1)}
        let content=UNMutableNotificationContent();content.title="Display Auto test";content.body="Failure alerts are enabled. This is a test, not a display failure.";content.categoryIdentifier="failure"
        center.add(UNNotificationRequest(identifier:"display-test",content:content,trigger:nil)){error in
            if let error=error {print(error.localizedDescription);exit(1)}
            print("PASS test notification accepted by macOS");exit(0)
        }
    }
    dispatchMain()
}
func sizeComparison(_ current:[String:Any],_ selected:[String:Any])->String {
    let before=current["modes"] as? [String:[String:Any]] ?? [:]
    let after=selected["modes"] as? [String:[String:Any]] ?? [:]
    func dimension(_ mode:[String:Any],_ key:String)->Double? {
        guard let number=mode[key] as? NSNumber,CFGetTypeID(number) != CFBooleanGetTypeID() else{return nil}
        let value=number.doubleValue
        guard value.isFinite,value>0,value<=32768,value.rounded()==value else{return nil}
        return value
    }
    func dimensions(_ mode:[String:Any],_ a:String,_ b:String)->String {
        guard let width=dimension(mode,a),let height=dimension(mode,b) else{return "unavailable"}
        return "\(Int(width)) × \(Int(height))"
    }
    var lines=[selected["label"] as? String ?? "Selected size"]
    for (role,label) in [("pg","PG42UQ"),("benq","BenQ RD280UG")] {
        let old=before[role] ?? [:],new=after[role] ?? [:]
        var section="\(label)\nCurrent: \(dimensions(old,"width","height"))\nSelected: \(dimensions(new,"width","height"))"
        if let oldWidth=dimension(old,"width"),let newWidth=dimension(new,"width") {
            let delta=(oldWidth/newWidth-1)*100
            section += abs(delta)<0.5 ? "\nInterface size: unchanged":"\nInterface size: about \(String(format:"%.0f",abs(delta)))% \(delta>0 ? "larger":"smaller")"
        } else {section += "\nInterface size estimate unavailable"}
        section += "\nFramebuffer: \(dimensions(old,"pixelWidth","pixelHeight")) → \(dimensions(new,"pixelWidth","pixelHeight"))"
        lines.append(section)
    }
    lines.append("Size estimates compare each monitor with itself in the same orientation. They do not prove equal physical size across monitors or native pixel sharpness.")
    return lines.joined(separator:"\n\n")
}

final class SizeChooser: NSObject, NSWindowDelegate {
    let choices:[[String:Any]]
    let current:[String:Any]
    let notes:String
    let window:NSPanel
    let selector=NSPopUpButton()
    let comparison=NSTextView()
    var result = -1
    var selectedIndex:Int {selector.indexOfSelectedItem}
    init(choices:[[String:Any]],current:[String:Any],notes:String,orientation:String,fontSize:CGFloat,canSave:Bool,canRemove:Bool) {
        self.choices=choices;self.current=current;self.notes=notes
        window=NSPanel(contentRect:NSRect(x:0,y:0,width:660,height:720),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init()
        window.title="Compare display sizes";window.minSize=NSSize(width:600,height:620);window.delegate=self
        window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-20)])
        let intro=NSTextField(wrappingLabelWithString:"\(orientation) · Fixed 120 Hz · 2× HiDPI · HDR off\nPreview reverts after 20 seconds unless you Keep it.")
        intro.font=NSFont.systemFont(ofSize:fontSize);stack.addArrangedSubview(intro)
        intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        selector.font=intro.font;selector.setAccessibilityLabel("Size choice to preview")
        for choice in choices {selector.addItem(withTitle:choice["label"] as? String ?? "Size")}
        selector.target=self;selector.action=#selector(selectionChanged(_:));stack.addArrangedSubview(selector)
        selector.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
        comparison.isEditable=false;comparison.isSelectable=true;comparison.font=intro.font
        comparison.isVerticallyResizable=true;comparison.isHorizontallyResizable=false;comparison.textContainer?.widthTracksTextView=true
        comparison.autoresizingMask=[.width];comparison.setAccessibilityLabel("Current and selected size comparison")
        scroll.documentView=comparison;stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:140).isActive=true
        for (index,title) in ["Preview selected size","Save current as preset…","Remove a saved preset…","Cancel"].enumerated() {
            let button=NSButton(title:title,target:self,action:#selector(finish(_:)));button.tag=index;button.font=intro.font
            button.setContentHuggingPriority(.required,for:.vertical)
            if index==0 {button.keyEquivalent="\r"}
            if index==1 {button.isEnabled=canSave}
            if index==2 {button.isEnabled=canRemove}
            if index==3 {button.keyEquivalent="\u{1b}"}
            stack.addArrangedSubview(button)
        }
        window.initialFirstResponder=selector;selectionChanged(selector)
    }
    @objc func selectionChanged(_ sender:NSPopUpButton) {
        guard selectedIndex>=0,selectedIndex<choices.count else{return}
        comparison.string=sizeComparison(current,choices[selectedIndex])+(notes.isEmpty ? "":"\n\n"+notes)
        comparison.scrollRangeToVisible(NSRange(location:0,length:0))
    }
    @objc func finish(_ sender:NSButton) {result=sender.tag;NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {result = -1;NSApp.stopModal();return true}
    func run()->Int {
        window.center();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil)
        return result
    }
}

func presetNameError(_ value:String)->String? {
    let scalars=Array(value.unicodeScalars)
    // Match Python's code-point count and str.strip whitespace contract in size_presets.
    func whitespace(_ scalar:Unicode.Scalar)->Bool {
        let n=scalar.value
        return (9...13).contains(n) || (28...32).contains(n) || (0x2000...0x200A).contains(n) || [0x85,0xA0,0x1680,0x2028,0x2029,0x202F,0x205F,0x3000].contains(n)
    }
    guard !scalars.isEmpty,scalars.count<=48 else{return "Use a name with 1–48 Unicode characters."}
    guard !whitespace(scalars.first!),!whitespace(scalars.last!) else{return "Remove whitespace from the start and end of the name."}
    guard !scalars.contains(where:{$0.value<32 || $0.value==127}) else{return "Remove control characters from the name."}
    return nil
}

final class PresetDialog: NSObject, NSWindowDelegate {
    let window:NSPanel
    let presets:[[String:Any]]?
    let brightnessMonitor:String?
    let name=NSTextField()
    let replace=NSButton(checkboxWithTitle:"Replace existing preset",target:nil,action:nil)
    let selector=NSPopUpButton()
    let errorLabel=NSTextField(wrappingLabelWithString:"")
    var arguments:[String]?
    init(fontSize:CGFloat,presets:[[String:Any]]?=nil,brightnessMonitor:String?=nil) {
        self.presets=presets;self.brightnessMonitor=brightnessMonitor
        window=NSPanel(contentRect:NSRect(x:0,y:0,width:620,height:480),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init()
        let saving=presets==nil
        window.title=brightnessMonitor==nil ? (saving ? "Save current size preset":"Remove a saved size preset"):"Save current brightness preset"
        window.minSize=NSSize(width:600,height:460);window.delegate=self;window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=16
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(lessThanOrEqualTo:window.contentView!.bottomAnchor,constant:-20)])
        let intro=NSTextField(wrappingLabelWithString:saving ? "Save the sizes currently displayed for this orientation. The highlighted preview choice is not applied. Replacement affects only this name and orientation.":"Select the saved name and orientation to remove. Current display settings and presets for the other orientation are preserved.")
        if let role=brightnessMonitor {intro.stringValue="Save the current hardware brightness of \(role=="pg" ? "PG42UQ":"BenQ RD280UG"). Replacement affects only this name and monitor. Display size and speaker volume are unchanged."}
        let font=NSFont.systemFont(ofSize:fontSize);intro.font=font
        stack.addArrangedSubview(intro);intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        if saving {
            name.font=font;name.placeholderString="Preset name, e.g. Reading";name.setAccessibilityLabel("Preset name")
            stack.addArrangedSubview(name);name.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
            replace.font=font;stack.addArrangedSubview(replace);window.initialFirstResponder=name
        } else {
            selector.font=font;selector.setAccessibilityLabel("Saved preset and orientation to remove")
            for entry in presets ?? [] {
                selector.addItem(withTitle:"\(entry["name"] as? String ?? "Unnamed") — \(entry["rotation"] as? Int == 90 ? "Portrait":"Landscape")")
            }
            stack.addArrangedSubview(selector);selector.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
            window.initialFirstResponder=selector
        }
        errorLabel.font=font;errorLabel.textColor = .systemRed;errorLabel.isSelectable=true
        errorLabel.setAccessibilityLabel("Preset validation error");stack.addArrangedSubview(errorLabel)
        errorLabel.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        let submit=NSButton(title:brightnessMonitor==nil ? (saving ? "Save current size":"Remove selected preset"):"Save current brightness",target:self,action:#selector(confirm(_:)))
        submit.font=font
        // Destructive removal is explicit; Return in the selector must not remove a preset.
        if saving {submit.keyEquivalent="\r"}
        submit.isEnabled=saving || !(presets ?? []).isEmpty
        let cancel=NSButton(title:"Cancel",target:self,action:#selector(cancel(_:)));cancel.font=font;cancel.keyEquivalent="\u{1b}"
        stack.addArrangedSubview(submit);stack.addArrangedSubview(cancel)
    }
    @objc func confirm(_ sender:NSButton) {
        if let presets=presets {
            let index=selector.indexOfSelectedItem
            guard index>=0,index<presets.count,let label=presets[index]["name"] as? String,let rotation=presets[index]["rotation"] as? Int,[0,90].contains(rotation),let revision=presets[index]["revision"] as? String,!revision.isEmpty else {
                errorLabel.stringValue="This entry is incomplete. Cancel and refresh the preset list.";return
            }
            arguments=["preset-remove","--preset",label,"--orientation",String(rotation),"--fingerprint",revision]
        } else {
            if let error=presetNameError(name.stringValue) {
                errorLabel.stringValue=error;window.makeFirstResponder(name)
                NSAccessibility.post(element:errorLabel,notification:.valueChanged);return
            }
            arguments=brightnessMonitor.map{["brightness-save","--monitor",$0,"--preset",name.stringValue]} ?? ["preset-save","--preset",name.stringValue]
            if replace.state == .on {arguments?.append("--replace")}
        }
        NSApp.stopModal()
    }
    @objc func cancel(_ sender:NSButton) {arguments=nil;NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {arguments=nil;NSApp.stopModal();return true}
    func run()->[String]? {
        window.center();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil)
        return arguments
    }
}

struct BrightnessEntry {
    let name:String
    let value:Int
    let maximum:Int
    let revision:String
    var description:String {"\(name)\nSaved brightness: \(Int((Double(value)*100/Double(maximum)).rounded(.toNearestOrEven)))% (\(value) / \(maximum))"}
}
func brightnessEntries(_ json:String,_ expectedMonitor:String?=nil)->(monitor:String,entries:[BrightnessEntry])? {
    guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],report["read_only"] as? Bool == true,
          let role=report["monitor"] as? String,["pg","benq"].contains(role),let rows=report["presets"] as? [[String:Any]],rows.count<=20,expectedMonitor==nil || expectedMonitor==role else{return nil}
    var entries:[BrightnessEntry]=[];var names=Set<String>()
    for row in rows {
        guard row["monitor"] as? String==role,let name=row["name"] as? String,presetNameError(name)==nil,names.insert(name).inserted,
              let value=row["value"] as? NSNumber,let maximum=row["maximum"] as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),CFGetTypeID(maximum) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite,maximum.doubleValue.isFinite,value.doubleValue.rounded()==value.doubleValue,maximum.doubleValue.rounded()==maximum.doubleValue,
              value.doubleValue>=0,maximum.doubleValue>0,value.doubleValue<=maximum.doubleValue,maximum.doubleValue<=65535,
              let revision=row["revision"] as? String,revision.count==64,revision.allSatisfy({"0123456789abcdef".contains($0)}) else{return nil}
        entries.append(BrightnessEntry(name:name,value:value.intValue,maximum:maximum.intValue,revision:revision))
    }
    return (role,entries)
}
final class BrightnessChooser: NSObject, NSWindowDelegate {
    let window:NSPanel
    let entries:[BrightnessEntry]
    let selector=NSPopUpButton()
    let detail=NSTextField(wrappingLabelWithString:"")
    var result = -1
    var selected:BrightnessEntry? {entries.indices.contains(selector.indexOfSelectedItem) ? entries[selector.indexOfSelectedItem]:nil}
    init(monitor:String,entries:[BrightnessEntry],fontSize:CGFloat,unavailable:String?,canRemove:Bool) {
        self.entries=entries
        window=NSPanel(contentRect:NSRect(x:0,y:0,width:640,height:620),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init()
        window.title="\(monitor=="pg" ? "PG42UQ":"BenQ RD280UG") brightness presets"
        window.minSize=NSSize(width:600,height:620);window.delegate=self;window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=14
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(lessThanOrEqualTo:window.contentView!.bottomAnchor,constant:-20)])
        let font=NSFont.systemFont(ofSize:fontSize)
        let intro=NSTextField(wrappingLabelWithString:"Target: \(monitor=="pg" ? "PG42UQ":"BenQ RD280UG"). Apply changes only this monitor's hardware brightness. Save reads its current brightness; it does not apply the selected preset.")
        intro.font=font;stack.addArrangedSubview(intro);intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        selector.font=font;selector.setAccessibilityLabel("Brightness preset")
        for entry in entries {selector.addItem(withTitle:entry.name)}
        selector.isEnabled = !entries.isEmpty;selector.target=self;selector.action=#selector(selectEntry(_:))
        stack.addArrangedSubview(selector);selector.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        detail.font=font;detail.isSelectable=true;stack.addArrangedSubview(detail);detail.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        let note=NSTextField(wrappingLabelWithString:unavailable ?? "Saved values are not live readings. Apply checks the current input and range, then verifies the result. Nothing runs automatically.")
        note.font=font;stack.addArrangedSubview(note);note.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        for (index,title) in ["Apply selected brightness","Save current brightness…","Remove selected preset","Cancel"].enumerated() {
            let button=NSButton(title:title,target:self,action:#selector(finish(_:)));button.tag=index;button.font=font
            if index==0 {button.isEnabled=unavailable==nil && !entries.isEmpty}
            if index==1 {button.isEnabled=unavailable==nil}
            if index==2 {button.isEnabled=canRemove && !entries.isEmpty}
            if index==3 {button.keyEquivalent="\u{1b}"}
            stack.addArrangedSubview(button)
        }
        window.initialFirstResponder=selector;selectEntry(selector)
    }
    @objc func selectEntry(_ sender:NSPopUpButton) {detail.stringValue=selected?.description ?? "No saved brightness presets for this monitor."}
    @objc func finish(_ sender:NSButton) {result=sender.tag;NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {result = -1;NSApp.stopModal();return true}
    func run()->Int {window.center();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil);return result}
}

enum PanelShortcut: Equatable {
    case tab(String)
    case refresh
}
func panelShortcut(_ key:String,_ modifiers:NSEvent.ModifierFlags,_ repeating:Bool)->PanelShortcut? {
    guard !repeating,modifiers.intersection([.command,.option,.control,.shift]) == .command else{return nil}
    let tabs=["1":"overview","2":"details","3":"displays","4":"audio","5":"monitor-controls"]
    if let tab=tabs[key] {return .tab(tab)}
    return key.lowercased()=="r" ? .refresh:nil
}
func panelRefreshArguments(_ tab:String,_ report:String,_ monitor:String)->[String]? {
    switch tab {
    case "details":return ["setup","doctor","history","ddc-history","support-summary"].contains(report) ? [report]:nil
    case "displays":return ["display-info"]
    case "monitor-controls":return ["pg","benq"].contains(monitor) ? ["monitor-settings","--monitor",monitor]:nil
    default:return nil // Overview, live status and Audio reread local controller state.
    }
}
final class DisplayPanel: NSWindow {
    var onShortcut:((PanelShortcut)->Void)?
    override func performKeyEquivalent(with event:NSEvent)->Bool {
        guard isKeyWindow,NSApp.modalWindow==nil,attachedSheet==nil,
              let shortcut=panelShortcut(event.charactersIgnoringModifiers ?? "",event.modifierFlags,event.isARepeat),
              let handler=onShortcut else{return super.performKeyEquivalent(with:event)}
        handler(shortcut);return true
    }
}

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    let root=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/display-auto")
    let command=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/display-auto.sh")
    let demo=CommandLine.arguments.contains("--demo") || Bundle.main.object(forInfoDictionaryKey:"DisplayBridgeDemo") as? Bool == true
    var demoScenario="ready"
    var ownership:MenuOwnership?
    var item:NSStatusItem!
    var timer:Timer?
    var panel:NSWindow?
    var scalableControls:[NSControl]=[]
    let detailReports=[("status","Live status"),("setup","Setup readiness"),("doctor","Health check"),("history","Transition timing"),("ddc-history","Monitor communication"),("support-summary","Support summary")]
    var detailReport="status"
    var reportSelector:NSPopUpButton?
    var reportStatus:NSTextField?
    var copySummaryButton:NSButton?
    var reviewedSummary=ReviewedSupportSummary()
    var copySummaryNotice=""
    @objc func copyReviewedSummary() {
        guard !busy,let body=reviewedSummary.body(for:detailReport) else{return}
        if demo {message("Hardware-free demo","Clipboard copying is disabled in this demo. No clipboard content was changed.");return}
        copySummaryNotice=writeReviewedSummary(body,to:.general) ? "Reviewed summary copied. Nothing was uploaded.":"Could not copy the summary. Select the report text to copy manually."
        refresh()
    }
    var panelText:NSTextView?
    var contentTabs:NSTabView?
    var modeText:NSTextView?
    var modeStatus:NSTextField?
    var displayReading=DisplayReading()
    var displayRefreshing=false
    func acceptDisplayReading(_ json:String) {
        if displayReading.accept(json) {modeText?.string=displaySummary(json)}
        refresh()
    }
    var monitorRole="pg"
    var monitorSelector:NSPopUpButton?
    var monitorButtons:[NSButton]=[]
    var monitorReason:NSTextField?
    var monitorFeedback:NSTextField?
    var speakerPopups:[String:NSPopUpButton]=[:]
    var audioInfo:NSTextField?
    var audioRepair:NSButton?
    var audioReason:NSTextField?
    var overviewFields:[(NSTextField,NSTextField)]=[]
    var recoveryButton:NSButton?
    var presentedRecoveryAction:RecoveryAction?
    var pauseButton:NSButton?
    var displayTextIndex:Int?
    var panelActions:[NSButton]=[]
    var previewActions:[NSButton]=[]
    var previewToken:String?
    var busy=false
    var operationStarted:Double?
    var operationName=""
    var operationDeadline:Double=45
    var operationResult=""
    var openMenus=Set<ObjectIdentifier>()
    var menuOpen:Bool {!openMenus.isEmpty}
    var controlsUsable=true
    var presetCapabilities:Set<String>?
    var checkingCapabilities=false
    var compatibilityLabel:NSTextField?
    var compatibilityButton:NSButton?
    var visibleCapabilities:Set<String>? {demo ? (demoScenario=="older-controller" ? []:Set(["brightness-list","brightness-save","brightness-apply","brightness-remove","preset-save","preset-remove"])):presetCapabilities}
    @objc func checkPresetSupport() {
        guard !checkingCapabilities,!demo else{return}
        checkingCapabilities=true;presetCapabilities=nil;refresh()
        DispatchQueue.global().async {
            let result=runMenuCommand(self.command,["capabilities"],timeout:5,outputLimit:16_384)
            DispatchQueue.main.async {
                self.presetCapabilities=menuCapabilities(result);self.checkingCapabilities=false;self.refresh()
            }
        }
    }
    var failureAlerts=FailureAlerts(sent:Array((UserDefaults.standard.stringArray(forKey:"failureIncidents") ?? []).prefix(16)))
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {showPanel();return true}
    func showPanel() {
        if panel==nil {
            let window=DisplayPanel(contentRect:NSRect(x:0,y:0,width:640,height:600),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
            window.onShortcut={ [weak self] shortcut in self?.handlePanelShortcut(shortcut) }
            window.title=demo ? "Display Bridge — Demo":"Display Bridge";window.isReleasedWhenClosed=false;window.minSize=NSSize(width:600,height:480);window.center()
            let scroll=NSScrollView(frame:NSRect(x:20,y:138,width:600,height:440));scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
            scroll.autoresizingMask=[.width,.height]
            let text=NSTextView(frame:scroll.bounds);text.isEditable=false;text.isSelectable=true;text.font=NSFont.systemFont(ofSize:CGFloat([16,20,24][textSizeIndex()]))
            text.drawsBackground=false;text.isVerticallyResizable=true;text.isHorizontallyResizable=false;text.textContainer?.widthTracksTextView=true
            text.setAccessibilityLabel("Display status and command results")
            scroll.documentView=text;panelText=text;panel=window
            let tabs=NSTabView(frame:NSRect(x:20,y:138,width:600,height:440))
            tabs.autoresizingMask=[.width,.height];contentTabs=tabs
            tabs.toolTip="⌘1–5 selects a tab. ⌘R refreshes the current view."
            tabs.setAccessibilityHelp("Command 1 through 5 selects a tab. Command R refreshes the current view.")
            let overview=NSTabViewItem(identifier:"overview");overview.label="Overview"
            let overviewScroll=NSScrollView();overviewScroll.hasVerticalScroller=true;overviewScroll.autohidesScrollers=true
            let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=18
            stack.edgeInsets=NSEdgeInsets(top:16,left:16,bottom:16,right:16)
            stack.translatesAutoresizingMaskIntoConstraints=false;overviewScroll.documentView=stack
            NSLayoutConstraint.activate([stack.widthAnchor.constraint(equalTo:overviewScroll.contentView.widthAnchor),stack.topAnchor.constraint(equalTo:overviewScroll.contentView.topAnchor)])
            for section in statusSections(read("health.json"),read("control.json")) {
                let heading=NSTextField(labelWithString:section.title)
                let body=NSTextField(wrappingLabelWithString:section.body);body.isSelectable=true
                body.setAccessibilityElement(true);body.setAccessibilityRole(.staticText)
                body.setAccessibilityLabel(section.title+" details");body.setAccessibilityValue(section.body)
                let group=NSStackView(views:[heading,body]);group.orientation = .vertical;group.alignment = .leading;group.spacing=5
                group.setAccessibilityElement(true);group.setAccessibilityRole(.group);group.setAccessibilityLabel(section.title)
                stack.addArrangedSubview(group)
                group.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-32).isActive=true
                body.widthAnchor.constraint(equalTo:group.widthAnchor).isActive=true
                overviewFields.append((heading,body))
                if section.title=="Recovery" {
                    let button=NSButton(title:"Check health",target:self,action:#selector(runRecoveryAction(_:)))
                    group.addArrangedSubview(button);recoveryButton=button;scalableControls.append(button)
                }
            }
            overview.view=overviewScroll;tabs.addTabViewItem(overview)
            let details=NSTabViewItem(identifier:"details");details.label="Details"
            let detailView=NSView();let reportRow=NSStackView();reportRow.spacing=8;reportRow.orientation = .vertical;reportRow.alignment = .leading
            let selectionRow=NSStackView();selectionRow.spacing=12;reportRow.addArrangedSubview(selectionRow)
            let reportPicker=NSPopUpButton();reportPicker.addItems(withTitles:detailReports.map{$0.1})
            reportPicker.target=self;reportPicker.action=#selector(selectReport(_:));reportPicker.setAccessibilityLabel("Detail report")
            reportSelector=reportPicker;selectionRow.addArrangedSubview(reportPicker);scalableControls.append(reportPicker)
            let refreshReport=NSButton(title:"Refresh",target:self,action:#selector(refreshReport))
            selectionRow.addArrangedSubview(refreshReport);scalableControls.append(refreshReport);panelActions.append(refreshReport)
            let copySummary=NSButton(title:"Copy reviewed summary",target:self,action:#selector(copyReviewedSummary))
            copySummary.toolTip="Copy only the displayed support-summary body. Review it before sharing."
            reportRow.addArrangedSubview(copySummary);copySummaryButton=copySummary;scalableControls.append(copySummary)
            let reportNote=NSTextField(wrappingLabelWithString:"");reportNote.translatesAutoresizingMaskIntoConstraints=false
            detailView.addSubview(reportNote);reportStatus=reportNote;scalableControls.append(reportNote)
            reportRow.translatesAutoresizingMaskIntoConstraints=false;scroll.translatesAutoresizingMaskIntoConstraints=false
            detailView.addSubview(reportRow);detailView.addSubview(scroll)
            NSLayoutConstraint.activate([reportRow.leadingAnchor.constraint(equalTo:detailView.leadingAnchor,constant:12),reportRow.topAnchor.constraint(equalTo:detailView.topAnchor,constant:12),reportRow.trailingAnchor.constraint(lessThanOrEqualTo:detailView.trailingAnchor,constant:-12),scroll.leadingAnchor.constraint(equalTo:detailView.leadingAnchor,constant:12),scroll.trailingAnchor.constraint(equalTo:detailView.trailingAnchor,constant:-12),reportNote.topAnchor.constraint(equalTo:reportRow.bottomAnchor,constant:8),reportNote.leadingAnchor.constraint(equalTo:detailView.leadingAnchor,constant:12),reportNote.trailingAnchor.constraint(equalTo:detailView.trailingAnchor,constant:-12),scroll.topAnchor.constraint(equalTo:reportNote.bottomAnchor,constant:8),scroll.bottomAnchor.constraint(equalTo:detailView.bottomAnchor,constant:-12)])
            details.view=detailView;tabs.addTabViewItem(details)
            let displays=NSTabViewItem(identifier:"displays");displays.label="Displays"
            let modeView=NSView(frame:NSRect(x:0,y:0,width:580,height:400))
            let modeScroll=NSScrollView(frame:NSRect(x:12,y:52,width:556,height:336))
            modeScroll.hasVerticalScroller=true;modeScroll.autoresizingMask=[.width,.height]
            let modeContent=NSTextView(frame:modeScroll.bounds)
            modeContent.isEditable=false;modeContent.isSelectable=true;modeContent.drawsBackground=false
            modeContent.isVerticallyResizable=true;modeContent.isHorizontallyResizable=false;modeContent.textContainer?.widthTracksTextView=true
            modeContent.string="Refresh to inspect the enrolled displays. This reads current modes without changing settings. Values are a snapshot, not continuous monitoring."
            modeContent.setAccessibilityLabel("Measured display modes")
            modeScroll.documentView=modeContent;modeView.addSubview(modeScroll);modeText=modeContent
            let refreshModes=NSButton(title:"Refresh display details",target:self,action:#selector(panelAction(_:)))
            refreshModes.identifier=NSUserInterfaceItemIdentifier("display-info");refreshModes.translatesAutoresizingMaskIntoConstraints=false;scalableControls.append(refreshModes)
            modeView.addSubview(refreshModes);panelActions.append(refreshModes)
            let snapshotStatus=NSTextField(wrappingLabelWithString:"");snapshotStatus.isSelectable=true
            snapshotStatus.translatesAutoresizingMaskIntoConstraints=false;modeView.addSubview(snapshotStatus)
            modeStatus=snapshotStatus;scalableControls.append(snapshotStatus)
            NSLayoutConstraint.activate([snapshotStatus.leadingAnchor.constraint(equalTo:modeView.leadingAnchor,constant:12),snapshotStatus.trailingAnchor.constraint(equalTo:modeView.trailingAnchor,constant:-12),snapshotStatus.topAnchor.constraint(equalTo:modeView.topAnchor,constant:12)])
            modeScroll.translatesAutoresizingMaskIntoConstraints=false
            NSLayoutConstraint.activate([refreshModes.leadingAnchor.constraint(equalTo:modeView.leadingAnchor,constant:12),refreshModes.bottomAnchor.constraint(equalTo:modeView.bottomAnchor,constant:-12),modeScroll.leadingAnchor.constraint(equalTo:modeView.leadingAnchor,constant:12),modeScroll.trailingAnchor.constraint(equalTo:modeView.trailingAnchor,constant:-12),modeScroll.topAnchor.constraint(equalTo:snapshotStatus.bottomAnchor,constant:8),modeScroll.bottomAnchor.constraint(equalTo:refreshModes.topAnchor,constant:-12)])
            displays.view=modeView;tabs.addTabViewItem(displays)
            let audioTab=NSTabViewItem(identifier:"audio");audioTab.label="Audio"
            let audioScroll=NSScrollView();audioScroll.hasVerticalScroller=true
            let audioStack=NSStackView();audioStack.orientation = .vertical;audioStack.alignment = .leading;audioStack.spacing=16
            audioStack.edgeInsets=NSEdgeInsets(top:16,left:16,bottom:16,right:16)
            audioStack.translatesAutoresizingMaskIntoConstraints=false;audioScroll.documentView=audioStack
            audioStack.widthAnchor.constraint(equalTo:audioScroll.contentView.widthAnchor).isActive=true
            audioStack.topAnchor.constraint(equalTo:audioScroll.contentView.topAnchor).isActive=true
            let info=NSTextField(wrappingLabelWithString:"Speaker preferences apply to each monitor profile. External headsets remain under your control.")
            audioStack.addArrangedSubview(info);info.widthAnchor.constraint(equalTo:audioStack.widthAnchor,constant:-32).isActive=true;audioInfo=info
            for (profile,label) in [("extended","Both monitors here"),("pg","Only PG here"),("benq","Only BenQ here"),("away","Both monitors away")] {
                let title=NSTextField(wrappingLabelWithString:label);scalableControls.append(title)
                let popup=NSPopUpButton();popup.identifier=NSUserInterfaceItemIdentifier(profile)
                popup.target=self;popup.action=#selector(selectSpeaker(_:));popup.setAccessibilityLabel("Speaker when "+label.lowercased())
                for (key,name) in speakerChoices(profile) {popup.addItem(withTitle:name);popup.lastItem?.representedObject=key}
                speakerPopups[profile]=popup;scalableControls.append(popup)
                let row=NSStackView(views:[title,popup]);row.orientation = .vertical;row.alignment = .leading;row.spacing=6;audioStack.addArrangedSubview(row)
            }
            for (title,action) in [("Preserve output for 30 minutes","audio-manual"),("Resume automatic audio","audio-auto"),("Repair audio","repair-audio")] {
                let button=NSButton(title:title,target:self,action:#selector(panelAction(_:)));button.identifier=NSUserInterfaceItemIdentifier(action)
                audioStack.addArrangedSubview(button);scalableControls.append(button)
                if action=="repair-audio" {audioRepair=button} else {panelActions.append(button)}
            }
            let reason=NSTextField(wrappingLabelWithString:"");audioStack.addArrangedSubview(reason)
            reason.widthAnchor.constraint(equalTo:audioStack.widthAnchor,constant:-32).isActive=true;audioReason=reason
            audioTab.view=audioScroll;tabs.addTabViewItem(audioTab)
            let controlsTab=NSTabViewItem(identifier:"monitor-controls");controlsTab.label="Controls"
            let controlsScroll=NSScrollView();controlsScroll.hasVerticalScroller=true
            let controlsStack=NSStackView();controlsStack.orientation = .vertical;controlsStack.alignment = .leading;controlsStack.spacing=18
            controlsStack.edgeInsets=NSEdgeInsets(top:16,left:16,bottom:16,right:16)
            controlsStack.translatesAutoresizingMaskIntoConstraints=false;controlsScroll.documentView=controlsStack
            controlsStack.widthAnchor.constraint(equalTo:controlsScroll.contentView.widthAnchor).isActive=true
            controlsStack.topAnchor.constraint(equalTo:controlsScroll.contentView.topAnchor).isActive=true
            let selector=NSPopUpButton();selector.addItems(withTitles:["PG42UQ","BenQ RD280UG"])
            selector.target=self;selector.action=#selector(selectMonitor(_:));selector.setAccessibilityLabel("Monitor to adjust")
            controlsStack.addArrangedSubview(selector);monitorSelector=selector;scalableControls.append(selector)
            let compatibility=NSTextField(wrappingLabelWithString:"");compatibility.isSelectable=true
            controlsStack.addArrangedSubview(compatibility);compatibility.widthAnchor.constraint(equalTo:controlsStack.widthAnchor,constant:-32).isActive=true
            compatibilityLabel=compatibility;scalableControls.append(compatibility)
            let checkSupport=NSButton(title:"Check preset support",target:self,action:#selector(checkPresetSupport))
            controlsStack.addArrangedSubview(checkSupport);compatibilityButton=checkSupport;scalableControls.append(checkSupport)
            let presetsButton=NSButton(title:"Brightness presets…",target:self,action:#selector(openBrightnessPresets))
            presetsButton.identifier=NSUserInterfaceItemIdentifier("brightness-list");controlsStack.addArrangedSubview(presetsButton);panelActions.append(presetsButton);scalableControls.append(presetsButton)
            let availability=NSTextField(wrappingLabelWithString:"");controlsStack.addArrangedSubview(availability)
            availability.widthAnchor.constraint(equalTo:controlsStack.widthAnchor,constant:-32).isActive=true;monitorReason=availability
            for (title,key) in [("Read brightness and volume","read"),("Brightness −5%","luminance:-5"),("Brightness +5%","luminance:5"),("Speaker volume −5%","volume:-5"),("Speaker volume +5%","volume:5")] {
                let button=NSButton(title:title,target:self,action:#selector(adjustMonitor(_:)))
                button.identifier=NSUserInterfaceItemIdentifier(key);controlsStack.addArrangedSubview(button);monitorButtons.append(button);scalableControls.append(button)
            }
            let feedback=NSTextField(wrappingLabelWithString:"Read settings to see confirmed hardware values. Equal brightness percentages do not mean equal light output. Speaker volume does not select the Mac audio output.")
            controlsStack.addArrangedSubview(feedback);feedback.widthAnchor.constraint(equalTo:controlsStack.widthAnchor,constant:-32).isActive=true;monitorFeedback=feedback
            controlsTab.view=controlsScroll;tabs.addTabViewItem(controlsTab)
            guard let content=window.contentView else {return}
            let footer=NSStackView();footer.orientation = .vertical;footer.alignment = .leading;footer.spacing=10
            footer.translatesAutoresizingMaskIntoConstraints=false;content.addSubview(footer)
            tabs.translatesAutoresizingMaskIntoConstraints=false;content.addSubview(tabs)
            NSLayoutConstraint.activate([footer.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:20),footer.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-20),footer.bottomAnchor.constraint(equalTo:content.bottomAnchor,constant:-16),tabs.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:20),tabs.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-20),tabs.topAnchor.constraint(equalTo:content.topAnchor,constant:16),tabs.bottomAnchor.constraint(equalTo:footer.topAnchor,constant:-16)])
            let sizes=NSSegmentedControl(labels:["Standard","Large","Largest"],trackingMode:.selectOne,target:self,action:#selector(changeTextSize(_:)))
            sizes.selectedSegment=textSizeIndex();sizes.setAccessibilityLabel("Interface size")
            let pause=NSButton(title:"Pause",target:self,action:#selector(togglePause(_:)));pauseButton=pause
            let sizeRow=NSStackView(views:[sizes,pause]);sizeRow.spacing=16;footer.addArrangedSubview(sizeRow)
            scalableControls.append(contentsOf:[sizes,pause])
            let previewRow=NSStackView();previewRow.spacing=12;footer.addArrangedSubview(previewRow)
            for (title,action) in [("Preview size…","preview-options"),("Keep size","preview-keep"),("Revert size","preview-revert")] {
                let button=NSButton(title:title,target:self,action:#selector(panelAction(_:)))
                button.identifier=NSUserInterfaceItemIdentifier(action);previewRow.addArrangedSubview(button)
                previewActions.append(button);scalableControls.append(button)
            }
            let more=NSButton(title:"More controls",target:self,action:#selector(openControls(_:)))
            let actions=NSStackView(views:[more]);actions.spacing=12;footer.addArrangedSubview(actions);scalableControls.append(more)
            for (title,action) in [("Health","doctor"),("Diagnostics","diagnostics")] {
                let button=NSButton(title:title,target:self,action:#selector(panelAction(_:)))
                button.identifier=NSUserInterfaceItemIdentifier(action);actions.addArrangedSubview(button)
                panelActions.append(button);scalableControls.append(button)
            }
            if demo {
                let scenarios=NSPopUpButton();scenarios.addItems(withTitles:["ready","stale","paused","away","preview","recovery","recovery-wait","presets-error","controls-error","brightness-empty","older-controller","display-refresh-failed"])
                scenarios.target=self;scenarios.action=#selector(changeDemoScenario(_:));scenarios.setAccessibilityLabel("Synthetic scenario")
                let compact=NSButton(title:"Minimum window",target:self,action:#selector(compactDemo))
                let row=NSStackView(views:[scenarios,compact]);row.spacing=12;footer.addArrangedSubview(row)
                scalableControls.append(contentsOf:[scenarios,compact])
            }
            applyTextSize(textSizeIndex())
        }
        refresh();panel?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    func handlePanelShortcut(_ shortcut:PanelShortcut) {
        switch shortcut {
        case .tab(let identifier):
            contentTabs?.selectTabViewItem(withIdentifier:identifier)
            panel?.makeFirstResponder(contentTabs)
        case .refresh:
            guard !busy else{return}
            let tab=contentTabs?.selectedTabViewItem?.identifier as? String ?? "overview"
            if tab=="monitor-controls",let reason=monitorControlReason(read("health.json"),read("control.json"),monitorRole,busy) {
                monitorFeedback?.stringValue=reason;return
            }
            if let arguments=panelRefreshArguments(tab,detailReport,monitorRole) {execute(arguments)}
            else {refresh()}
        }
    }
    @objc func changeDemoScenario(_ sender:NSPopUpButton) {
        guard demo else {return}
        demoScenario=sender.titleOfSelectedItem ?? "ready";refresh()
    }
    @objc func compactDemo() {
        guard demo,let window=panel else {return}
        var frame=window.frame;frame.size=window.minSize;window.setFrame(frame,display:true)
    }
    @objc func selectReport(_ sender:NSPopUpButton) {
        let index=sender.indexOfSelectedItem
        guard index>=0,index<detailReports.count else {return}
        detailReport=detailReports[index].0
        reviewedSummary.clear();copySummaryNotice=""
        panelText?.setAccessibilityLabel(detailReports[index].1+" report")
        panelText?.string=detailReport=="status" ? "":"Choose Refresh to read this report. Reports are snapshots and do not update in the background."
        refresh()
    }
    @objc func refreshReport() {
        if detailReport=="status" {refresh()} else {execute([detailReport])}
    }
    func showReport(_ action:String,_ text:String) {
        guard let index=detailReports.firstIndex(where:{$0.0==action}) else {return}
        detailReport=action;reportSelector?.selectItem(at:index)
        reviewedSummary.show(action,text);copySummaryNotice=""
        panelText?.setAccessibilityLabel(detailReports[index].1+" report")
        reportStatus?.stringValue="Snapshot report; use Refresh to inspect again."
        panelText?.string="\(detailReports[index].1) · Snapshot at \(Date().formatted(date:.omitted,time:.standard))\nRefresh to inspect again.\n\n"+text
        contentTabs?.selectTabViewItem(withIdentifier:"details")
        refresh()
    }
    func textSizeIndex()->Int {displayTextIndex ?? min(2,max(0,UserDefaults.standard.integer(forKey:"statusTextSize")))}
    func applyTextSize(_ index:Int) {
        let size=CGFloat([16,20,24][index])
        for control in scalableControls {control.font=NSFont.systemFont(ofSize:size);control.invalidateIntrinsicContentSize()}
        contentTabs?.font=NSFont.systemFont(ofSize:size)
        panelText?.font=NSFont.systemFont(ofSize:size)
        modeText?.font=NSFont.systemFont(ofSize:size)
        audioInfo?.font=NSFont.systemFont(ofSize:size);audioReason?.font=NSFont.systemFont(ofSize:size)
        monitorReason?.font=NSFont.systemFont(ofSize:size);monitorFeedback?.font=NSFont.systemFont(ofSize:size)
        for (heading,body) in overviewFields {heading.font=NSFont.boldSystemFont(ofSize:size);body.font=NSFont.systemFont(ofSize:size)}
    }
    func showMonitorResult(_ text:String,_ role:String?) {
        if let role=role,["pg","benq"].contains(role) {
            monitorRole=role;monitorSelector?.selectItem(at:role=="pg" ? 0:1)
        }
        monitorFeedback?.stringValue=text
        contentTabs?.selectTabViewItem(withIdentifier:"monitor-controls")
    }
    @objc func openBrightnessPresets() {execute(["brightness-list","--monitor",monitorRole])}
    func chooseBrightness(_ json:String,expectedMonitor:String) {
        guard let report=brightnessEntries(json,expectedMonitor) else {message("Brightness presets unavailable","The list could not be validated. No preset was changed; refresh after checking health.");return}
        let role=report.monitor
        let chooser=BrightnessChooser(monitor:role,entries:report.entries,fontSize:CGFloat([16,20,24][textSizeIndex()]),unavailable:monitorControlReason(read("health.json"),read("control.json"),role,busy),canRemove:controlsAvailable(read("control.json")) && !busy)
        let action=chooser.run()
        guard [0,1,2].contains(action) else{return}
        if action != 2,let reason=monitorControlReason(read("health.json"),read("control.json"),role,busy) {message("Brightness action unavailable",reason);return}
        if action==1 {
            let dialog=PresetDialog(fontSize:CGFloat([16,20,24][textSizeIndex()]),brightnessMonitor:role)
            if let arguments=dialog.run() {execute(arguments)}
        } else if let entry=chooser.selected {
            execute([action==0 ? "brightness-apply":"brightness-remove","--monitor",role,"--preset",entry.name,"--fingerprint",entry.revision])
        }
    }
    @objc func selectMonitor(_ sender:NSPopUpButton) {
        monitorRole=sender.indexOfSelectedItem==0 ? "pg":"benq"
        monitorFeedback?.stringValue="No readback for this selection yet. Read settings to inspect it."
        refresh()
    }
    @objc func adjustMonitor(_ sender:NSButton) {
        guard let key=sender.identifier?.rawValue else{return}
        if key=="read" {execute(["monitor-settings","--monitor",monitorRole]);return}
        let parts=key.split(separator:":").map(String.init)
        guard parts.count==2 else{return}
        execute(["monitor-adjust","--monitor",monitorRole,"--feature",parts[0],"--step",parts[1]])
    }
    @objc func selectSpeaker(_ sender:NSPopUpButton) {
        guard let profile=sender.identifier?.rawValue,let speaker=sender.selectedItem?.representedObject as? String else{return}
        execute(["speaker","--profile",profile,"--speaker",speaker])
    }
    @objc func togglePause(_ sender:NSButton) {execute([automationPaused(read("control.json")) ? "resume":"pause"])}
    @objc func changeTextSize(_ sender:NSSegmentedControl) {
        let index=min(2,max(0,sender.selectedSegment))
        if !demo {UserDefaults.standard.set(index,forKey:"statusTextSize")}
        displayTextIndex=index;applyTextSize(index)
    }
    @objc func openControls(_ sender:NSButton){refresh();item.menu?.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.height),in:sender)}
    @objc func panelAction(_ sender:NSButton){if let action=sender.identifier?.rawValue {
        if action=="preview-keep" || action=="preview-revert" {if let token=previewToken {execute([action,"--token",token])}}
        else {execute([action])}
    }}
    @objc func runRecoveryAction(_ sender:NSButton) {
        guard let args=currentRecoveryArguments(presentedRecoveryAction,read("health.json"),read("control.json"),busy) else {
            operationResult="Recovery status changed or a command is still running. Review the current action before retrying."
            refresh();return
        }
        execute(args)
    }
    func read(_ name:String)->[String:Any] {
        if demo {return demoState(demoScenario,name,Date().timeIntervalSince1970)}
        return readMenuState(root.appendingPathComponent(name),allowMissing:name=="control.json") ?? (name=="control.json" ? ["_read_unavailable":true]:[:])
    }
    func applicationDidFinishLaunching(_ notification:Notification) {
        if !demo {
            ownership=MenuOwnership(path:root.appendingPathComponent("menu.lock").path)
            guard ownership != nil else {
                FileHandle.standardError.write(Data("Menu already running or ownership lock unavailable.\n".utf8))
                if let identifier=Bundle.main.bundleIdentifier {
                    for app in NSRunningApplication.runningApplications(withBundleIdentifier:identifier) where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                        app.activate(options:[.activateIgnoringOtherApps])
                    }
                }
                NSApp.terminate(nil);return
            }
        }
        NSApp.setActivationPolicy(.accessory)
        item=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        item.button?.image=NSImage(systemSymbolName:"display.2",accessibilityDescription:"Display Auto")
        if !demo {
        UNUserNotificationCenter.current().delegate=self
        let repair=UNNotificationAction(identifier:"repair",title:"Repair audio",options:[])
        let inspect=UNNotificationAction(identifier:"inspect",title:"Check health",options:[])
        UNUserNotificationCenter.current().setNotificationCategories([UNNotificationCategory(identifier:"failure",actions:[repair],intentIdentifiers:[],options:[]),UNNotificationCategory(identifier:"state-failure",actions:[inspect],intentIdentifiers:[],options:[])])
        }
        timer=Timer(timeInterval:2,repeats:true){[weak self] _ in self?.refresh()}
        if let timer=timer {RunLoop.main.add(timer,forMode:.common)}
        refresh()
        if demo {showPanel();return}
        checkPresetSupport()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options:[.alert]){_,error in
                    if let error=error {FileHandle.standardError.write(Data((error.localizedDescription+"\n").utf8))}
                }
            }
        }
    }
    func add(_ menu:NSMenu,_ title:String,_ args:[String]?=nil,checked:Bool=false) {
        let entry=NSMenuItem(title:title,action:args == nil ? nil : #selector(act(_:)),keyEquivalent:"")
        entry.target=self;entry.representedObject=args;entry.state=checked ? .on:.off;entry.isEnabled=args != nil && !busy && (controlsUsable || safeWithoutControls(args?.first ?? ""));menu.addItem(entry)
    }
    func refresh() {
        let health=read("health.json"),control=read("control.json")
        controlsUsable=controlsAvailable(control)
        modeStatus?.stringValue=displayReading.notice(health,refreshing:displayRefreshing)
        let fresh=statusFresh(health)
        let prefix=detailPrefix(health,control)
        let state=fresh ? health["status"] as? String ?? "Unknown" : "Controller unavailable"
        item.button?.title=state == "degraded" || state == "state-error" || !fresh || !controlsUsable ? " !" : ""
        item.button?.toolTip="Display Bridge: \(controlsUsable ? state:"Controls unavailable")"
        let tracked=commandSummary(health,control)
        var progress=operationResult
        if let started=operationStarted {
            let elapsed=Int(max(0,ProcessInfo.processInfo.systemUptime-started))
            progress="\(operationName)… \(elapsed)s in this phase. Phase deadline: \(Int(operationDeadline))s."
        }
        if !controlsUsable {progress += "\nSaved controls are unreadable. Setting changes are disabled; check health."}
        let sections=statusSections(health,control)
        for (index,fields) in overviewFields.enumerated() where index<sections.count {
            var body=sections[index].body
            if index==0 {
                if !tracked.isEmpty {body += "\n\n"+tracked}
                if !progress.isEmpty {body += "\n\n"+progress}
            }
            if fields.1.stringValue != body {fields.1.stringValue=body;fields.1.setAccessibilityValue(body)}
        }
        presentedRecoveryAction=recoveryAction(health,control)
        recoveryButton?.isHidden=presentedRecoveryAction==nil
        recoveryButton?.title=presentedRecoveryAction?.title ?? "Check health"
        recoveryButton?.isEnabled = !busy && presentedRecoveryAction != nil
        pauseButton?.title=automationPaused(control) ? "Resume":"Pause"
        pauseButton?.isEnabled = !busy && controlsUsable
        var detail=dashboard(health,control)
        if !tracked.isEmpty {detail=tracked+"\n\n"+detail}
        if !progress.isEmpty {detail=progress+"\n\n"+detail}
        let lastPreview=read("preview-status.json")
        if !state.hasPrefix("preview-"),let error=lastPreview["error"] as? String {detail += "\n\nLast size preview: \(error)"}
        reportSelector?.isEnabled = !busy
        copySummaryButton?.isHidden=detailReport != "support-summary"
        copySummaryButton?.isEnabled = !busy && reviewedSummary.body(for:detailReport) != nil
        reportStatus?.stringValue = busy ? progress : (!copySummaryNotice.isEmpty ? copySummaryNotice:(detailReport=="status" ? "Live controller status":"Snapshot report; use Refresh to inspect again."))
        if detailReport=="status",let text=panelText,text.string != detail {
            let selection=text.selectedRange()
            let origin=text.enclosingScrollView?.contentView.bounds.origin
            text.string=detail
            let length=(detail as NSString).length
            if selection.location<=length {text.setSelectedRange(NSRange(location:selection.location,length:min(selection.length,length-selection.location)))}
            if let origin=origin {text.enclosingScrollView?.contentView.scroll(to:origin)}
        }
        compatibilityLabel?.stringValue=presetCompatibilitySummary(visibleCapabilities,checking:checkingCapabilities)
        compatibilityButton?.isEnabled = !checkingCapabilities && !busy && !demo
        let monitorUnavailable=monitorControlReason(health,control,monitorRole,busy)
        monitorReason?.stringValue=monitorUnavailable ?? "Controls apply only to the selected monitor. Each adjustment waits for hardware confirmation."
        for button in monitorButtons {button.isEnabled=monitorUnavailable==nil}
        monitorSelector?.isEnabled = !busy
        for button in panelActions {
            let action=button.identifier?.rawValue ?? "doctor"
            button.isEnabled = !busy && (controlsUsable || safeWithoutControls(action)) && (action != "brightness-list" || ["brightness-list","brightness-save","brightness-apply","brightness-remove"].allSatisfy{visibleCapabilities?.contains($0)==true})
        }
        let preferences=control["speaker_preferences"] as? [String:String] ?? [:]
        for (profile,popup) in speakerPopups {
            if !controlsUsable {popup.selectItem(at:-1);popup.isEnabled=false;continue}
            let wanted=preferences[profile] ?? (profile=="away" ? "fallback":profile=="benq" ? "benq":"pg")
            if let entry=popup.itemArray.first(where:{$0.representedObject as? String==wanted}) {popup.select(entry)}
            else {popup.selectItem(at:-1)}
            popup.isEnabled = !busy && controlsUsable
        }
        let currentAudio=health["audio"] as? [String:Any] ?? [:]
        let selectedOutput=currentAudio["selected"] as? [String:Any] ?? [:]
        var audioDescription=prefix+"Selected output: \(selectedOutput["name"] as? String ?? "Not reported")\nSpeaker preferences apply to each profile. External headsets remain under your control."
        if let until=control["audio_manual_until"] as? Double,until>Date().timeIntervalSince1970 {
            audioDescription += "\nManual preservation ends at \(Date(timeIntervalSince1970:until).formatted(date:.omitted,time:.shortened))."
        }
        if !controlsUsable {audioDescription="Saved controls are unreadable. Check health before changing audio preferences.\n\n"+audioDescription}
        audioInfo?.stringValue=audioDescription
        let reason=audioRepairReason(health,control,busy)
        audioRepair?.isEnabled=reason==nil
        audioReason?.stringValue=reason ?? "Repair uses the existing recovery policy. Listen afterward to confirm sound."

        let preview=health["preview"] as? [String:Any] ?? [:]
        previewToken=preview["token"] as? String
        for button in previewActions {
            let action=button.identifier?.rawValue
            if action=="preview-options" {button.isEnabled = !busy && controlsUsable && fresh && state=="ready" && health["profile"] as? String == "extended" && !automationPaused(control)}
            else {
                if action=="preview-keep" {button.title="Keep (\(previewRemaining(health))s)"}
                button.isHidden = preview["state"] as? String != "preview";button.isEnabled = !busy && (controlsUsable || action=="preview-revert") && fresh && previewToken != nil && preview["state"] as? String == "preview" && previewRemaining(health)>0}
        }
        if !demo {
        notify(health,fresh:fresh)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let data:[String:Any]=["updated_at":Date().timeIntervalSince1970,"pid":ProcessInfo.processInfo.processIdentifier,"app_version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","notification_authorization":settings.authorizationStatus.rawValue,"status":state]
            if let bytes=try? JSONSerialization.data(withJSONObject:data){try? bytes.write(to:self.root.appendingPathComponent("menu-health.json"),options:.atomic)}
        }
        }
        if menuOpen{return}
        let compact=NSMenu();compact.delegate=self
        add(compact,"Display Bridge · Mac \(health["host"] as? String ?? "?")")
        add(compact,dashboard(health,control).components(separatedBy:"\n").first ?? "Status unavailable")
        add(compact,statusAge(health))
        for section in sections where section.title=="PG42UQ" || section.title=="BenQ RD280UG" {
            add(compact,section.title+": "+(section.body.components(separatedBy:"\n").first ?? "Unknown"))
        }
        let audio=health["audio"] as? [String:Any] ?? [:],selected=audio["selected"] as? [String:Any] ?? [:]
        add(compact,"\(prefix)Speaker: \(selected["name"] as? String ?? "—")")
        if !progress.isEmpty {add(compact,progress)}
        compact.addItem(.separator())
        add(compact,"Open Display Bridge…",["panel"])
        let paused=automationPaused(control)
        add(compact,paused ? "Resume automation":"Pause automation",[paused ? "resume":"pause"])
        if fresh,let token=previewToken,preview["state"] as? String == "needs-repair" {
            add(compact,"Retry size restoration",["preview-repair","--token",token])
        }
        if let token=previewToken,previewRemaining(health)>0 {
            add(compact,"Keep preview size (\(previewRemaining(health))s)",["preview-keep","--token",token])
            add(compact,"Revert preview size",["preview-revert","--token",token])
        }
        let menu=NSMenu();menu.delegate=self
        let rotation=health["rotation"] as? [String:Any] ?? [:]
        add(menu,"Pause for 15 minutes",["pause-for","--minutes","15"])
        if rotation["enabled"] as? Bool == true {
            let automatic=control["auto_rotate"] as? Bool ?? true
            add(menu,"Automatic BenQ rotation",[automatic ? "rotation-manual":"rotation-auto"],checked:controlsUsable && automatic)
        }
        if paused,let until=control["pause_until"] as? Double,until>0 {
            add(menu,"Resumes at \(Date(timeIntervalSince1970:until).formatted(date:.omitted,time:.shortened))")
        }
        let manual=(control["audio_manual_until"] as? Double ?? 0)>Date().timeIntervalSince1970
        add(menu,"Preserve current audio for 30 minutes",["audio-manual","--minutes","30"],checked:manual)
        add(menu,"Resume automatic audio",["audio-auto"])
        add(menu,"Repair audio",audioRepairReason(health,control,busy)==nil ? ["repair-audio"]:nil)
        for (profile,label,defaultSpeaker) in [("extended","Both monitors here","pg"),("pg","Only PG here","pg"),("benq","Only BenQ here","benq"),("away","Both monitors away","fallback")] {
            let entry=NSMenuItem(title:"Speaker: \(label)",action:nil,keyEquivalent:"");let sub=NSMenu()
            for (speaker,title) in speakerChoices(profile) {
                add(sub,title,["speaker","--profile",profile,"--speaker",speaker],checked:controlsUsable && (preferences[profile] ?? defaultSpeaker)==speaker)
            };entry.submenu=sub;menu.addItem(entry)
        }
        menu.addItem(.separator())
        add(menu,"Preview display size…",fresh && state=="ready" && health["profile"] as? String == "extended" && !paused ? ["preview-options"]:nil)
        let inputs=health["inputs"] as? [String:Int] ?? [:]
        let hostB=health["host"] as? String == "B"
        for (role,label,localInput) in [("pg","PG42UQ",hostB ? 18:17),("benq","BenQ",hostB ? 15:19)] {
            let entry=NSMenuItem(title:"\(label) brightness and volume",action:nil,keyEquivalent:"")
            let sub=NSMenu()
            let enabled=monitorControlReason(health,control,role,busy)==nil
            add(sub,"Read current settings…",fresh && inputs[role]==localInput ? ["monitor-settings","--monitor",role]:nil)
            if !enabled {add(sub,"Available when this monitor shows this Mac and is ready")}
            for (feature,name) in [("luminance","Brightness"),("volume","Speaker volume")] {
                for step in [-5,5] {
                    add(sub,"\(name) \(step>0 ? "+5":"−5")%",enabled ? ["monitor-adjust","--monitor",role,"--feature",feature,"--step",String(step)]:nil)
                }
            }
            entry.submenu=sub;menu.addItem(entry)
        }
        add(menu,"Preview support summary…",["support-summary"])
        add(menu,"Save private diagnostic report…",["diagnostics"])
        add(menu,"Check system health…",["doctor"])
        add(menu,"Show transition timing summary…",["history"])
        add(menu,"Show monitor communication history…",["ddc-history"])
        add(menu,"Enable failure notifications…",["notifications"])
        let advanced=NSMenuItem(title:"Advanced",action:nil,keyEquivalent:"")
        advanced.submenu=menu;compact.addItem(advanced)
        compact.addItem(.separator())
        add(compact,"Quit menu bar (automation continues)",["quit"])
        item.menu=compact
    }
    func menuWillOpen(_ menu:NSMenu){openMenus.insert(ObjectIdentifier(menu))}
    func menuDidClose(_ menu:NSMenu){openMenus.remove(ObjectIdentifier(menu))}
    @objc func act(_ sender:NSMenuItem){if let args=sender.representedObject as? [String]{execute(args)}}
    func execute(_ args:[String]) {
        if !controlsAvailable(read("control.json")),!safeWithoutControls(args.first ?? "") {
            message("Saved controls unavailable","Check health and restore valid control settings before changing preferences or starting a preview. Recovery journals were preserved.");return
        }
        if args==["panel"]{showPanel();return}
        if args==["quit"]{NSApp.terminate(nil);return}
        if demo,args.first=="brightness-list" {
            let role=args.last ?? "pg"
            var report:[String:Any]=["read_only":true,"monitor":role,"presets":[["name":"Reading","monitor":role,"value":30,"maximum":100,"revision":String(repeating:"a",count:64)],["name":"Evening","monitor":role,"value":15,"maximum":100,"revision":String(repeating:"b",count:64)]]]
            if demoScenario=="brightness-empty" {report["presets"]=[] }
            if let data=try? JSONSerialization.data(withJSONObject:report),let json=String(data:data,encoding:.utf8) {chooseBrightness(json,expectedMonitor:role)}
            return
        }
        if demo,args==["setup"] {
            let report:[String:Any]=["read_only":true,"status":"warning","checks":[["name":"Host enrollment","status":"ok","detail":"Mac A; expected local inputs PG=17, BenQ=19. Synthetic enrollment."],["name":"Rotation enrollment","status":"info","detail":"Portrait profile is missing.","action":"Capture the missing orientation on this Mac through the installer; keep existing profiles."]],"limits":"Synthetic fixture. Nothing was read, changed or uploaded."]
            if let data=try? JSONSerialization.data(withJSONObject:report),let json=String(data:data,encoding:.utf8) {showReport("setup",setupSummary(json,["BetterDisplay.app","Unrelated.app"]))}
            return
        }
        if demo,args.count==1,detailReports.contains(where:{$0.0==args[0]}) {
            showReport(args[0],"Synthetic report for interface inspection. No hardware or local diagnostic data was read.\n\nExample: two completed transitions; application time 2.0 seconds. These are demo values, not measurements.")
            return
        }
        if args==["preset-save-prompt"] {savePresetPrompt();return}
        if demo && args==["preview-options"] {
            let modes:[String:Any] = ["pg":["width":1920,"height":1080,"pixelWidth":3840,"pixelHeight":2160],"benq":["width":1920,"height":1280,"pixelWidth":3840,"pixelHeight":2560]]
            var report:[String:Any] = ["rotation":0,"options":[["label":"Current size","size":"current","fingerprint":"demo","modes":modes],["label":"Larger interface","size":"larger","fingerprint":"demo-larger","modes":["pg":["width":1536,"height":864,"pixelWidth":3072,"pixelHeight":1728],"benq":["width":1536,"height":1024,"pixelWidth":3072,"pixelHeight":2048]]]],
                "presets":[["name":"Reading","rotation":0,"revision":"demo","available":true,"fingerprint":"demo","modes":modes],
                           ["name":"Reading","rotation":90,"revision":"demo","available":false,"reason":"Preset belongs to the other orientation"]]]
            if demoScenario=="presets-error" {report["presets"]=[];report["preset_error"]="Saved presets are unreadable. The original file was preserved. Ordinary size previews remain available."}
            if let data=try? JSONSerialization.data(withJSONObject:report),let text=String(data:data,encoding:.utf8) {chooseSize(text)}
            return
        }
        if demo && args==["display-info"] {
            if demoScenario=="display-refresh-failed" {displayReading.failed=true;refresh();return}
            acceptDisplayReading(#"{"read_only":true,"inputs":{"pg":17,"benq":15},"logical_layout":{"state":"pg-source","monitors":[{"monitor":"pg","owner":"A","rotation":0},{"monitor":"benq","owner":"B","rotation":90}]},"displays":[{"monitor":"pg","available":true,"current":{"width":1920,"height":1080,"pixelWidth":3840,"pixelHeight":2160},"saved":{"width":1920,"height":1080,"pixelWidth":3840,"pixelHeight":2160},"hz":120,"hidpi":true,"fixed_refresh":true,"hdr_preference":false,"saved_mode_matches":true},{"monitor":"benq","available":false,"reason":"Synthetic example: monitor showing the other Mac"}],"limits":"Demo data only. No monitor was inspected or changed."}"#)
            return
        }
        if demo {message("Hardware-free demo","This preview uses synthetic status. Monitor, audio, diagnostic and notification actions are disabled.");return}
        if args==["notifications"] {
            UNUserNotificationCenter.current().requestAuthorization(options:[.alert]){granted,error in
                DispatchQueue.main.async {self.message(granted ? "Failure notifications enabled":"Notifications are disabled",error?.localizedDescription ?? "You can change this in System Settings → Notifications → Display Auto.")}
            };return
        }
        guard !busy else{return}
        if args.first=="support-summary" {reviewedSummary.clear();copySummaryNotice=""}
        displayRefreshing=args.first=="display-info"
        busy=true;operationStarted=ProcessInfo.processInfo.systemUptime
        operationName="Preparing command";operationDeadline=45;operationResult=""
        showPanel()
        DispatchQueue.global().async {
            let response=runCompatibleMenuCommand(args==["setup"] ? ["doctor"]:args,onPhase:{name,deadline in
                let started=ProcessInfo.processInfo.systemUptime
                DispatchQueue.main.async {
                    self.operationName=name;self.operationDeadline=deadline;self.operationStarted=started;self.refresh()
                }
            }){arguments,timeout,limit in runMenuCommand(self.command,arguments,timeout:timeout,outputLimit:limit)}
            let result=response.output,code=response.code
            DispatchQueue.main.async {
                self.busy=false;self.operationStarted=nil
                if args.first=="display-info" {self.displayRefreshing=false;if code != 0 {self.displayReading.failed=true}}
                if code != 0 {self.operationResult=code==124 ? "Command timed out; inspect status before retrying.":"Command failed; see the error for details."}
                else if let data=result.data(using:.utf8),let response=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],response["requested"] != nil {
                    self.operationResult=response["request_id"] == nil ? "Request saved; this controller does not report command completion.":""
                } else {self.operationResult="Command returned. See the result and current status below."}
                self.refresh()
                if code != 0 {self.message("Action could not complete",result)}
                else if args.first=="diagnostics" {NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:result.trimmingCharacters(in:.whitespacesAndNewlines))])}
                else if args.first=="support-summary" {self.showReport("support-summary","Review before sharing. This report is not uploaded automatically.\n\n"+result)}
                else if args.first=="history" {self.showReport("history",timingSummary(result))}
                else if args.first=="display-info" {self.acceptDisplayReading(result)}
                else if args.first=="doctor" {self.showReport("doctor",healthSummary(result))}
                else if args.first=="setup" {self.showReport("setup",setupSummary(result,NSWorkspace.shared.runningApplications.compactMap{$0.bundleURL?.lastPathComponent}))}
                else if args.first=="ddc-history" {self.showReport("ddc-history",ddcSummary(result))}
                else if args.first=="preset-remove",let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value["removed"] as? Bool == true {
                    self.operationResult="Preset ‘\(value["name"] as? String ?? "")’ removed for \(value["rotation"] as? Int == 90 ? "portrait":"landscape"). Display settings were not changed."
                }
                else if args.first=="preset-save",let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value["saved"] as? Bool == true {
                    self.operationResult="Preset ‘\(value["name"] as? String ?? "")’ saved for \(value["rotation"] as? Int == 90 ? "portrait":"landscape"). Display settings were not changed."
                }
                else if args.first=="brightness-list" {self.chooseBrightness(result,expectedMonitor:args.last ?? "")}
                else if ["brightness-save","brightness-remove"].contains(args.first ?? ""),let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value[args.first=="brightness-save" ? "saved":"removed"] as? Bool == true {
                    self.showMonitorResult("Brightness preset ‘\(value["name"] as? String ?? "")’ \(args.first=="brightness-save" ? "saved":"removed"). No brightness change was requested.",value["monitor"] as? String)
                }
                else if args.first=="preview-options" {self.chooseSize(result)}
                else if args.first?.hasPrefix("preview-")==true {self.showPanel()}
                else if ["monitor-adjust","brightness-apply"].contains(args.first ?? ""),let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] {
                    let name=value["feature"] as? String == "luminance" ? "Brightness":"Speaker volume"
                    let monitor=value["monitor"] as? String == "pg" ? "PG42UQ":"BenQ RD280UG"
                    if let percent=value["percent"] as? Int,(0...100).contains(percent) {
                        self.showMonitorResult("\(monitor) · \(name): \(percent)%\nConfirmed at \(Date().formatted(date:.omitted,time:.standard)). Refresh after using the monitor's own controls.",value["monitor"] as? String)
                    } else {self.monitorFeedback?.stringValue="Adjustment returned an unreadable value. Read settings again; do not assume it succeeded."}
                }
                else if args.first=="monitor-settings",let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let settings=value["settings"] as? [String:[String:Int]] {
                    let monitor=value["monitor"] as? String == "pg" ? "PG42UQ":"BenQ RD280UG"
                    var lines=["Read-only snapshot · \(monitor)"]
                    for (key,label) in [("luminance","Brightness"),("volume","Speaker volume")] {
                        if let setting=settings[key] {lines.append("\(label): \(setting["percent"] ?? 0)% (\(setting["value"] ?? 0) / \(setting["maximum"] ?? 0))")}
                    }
                    lines.append("\nThese are monitor hardware settings. Speaker volume does not select the macOS audio output. Nothing was changed.")
                    self.showMonitorResult(lines.joined(separator:"\n"),value["monitor"] as? String)
                }
                self.refresh()
            }
        }
    }
    func message(_ title:String,_ body:String){
        NSApp.activate(ignoringOtherApps:true);let alert=NSAlert();alert.messageText=title
        if body.count>1000 {
            let scroll=NSScrollView(frame:NSRect(x:0,y:0,width:480,height:340));scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
            let text=NSTextView(frame:scroll.bounds);text.isEditable=false;text.isSelectable=true;text.font=NSFont.systemFont(ofSize:13);text.string=body
            text.isVerticallyResizable=true;text.isHorizontallyResizable=false;text.textContainer?.widthTracksTextView=true
            scroll.documentView=text;alert.accessoryView=scroll
        } else {alert.informativeText=body}
        alert.runModal()
    }
    func savePresetPrompt() {
        let dialog=PresetDialog(fontSize:CGFloat([16,20,24][textSizeIndex()]))
        if let arguments=dialog.run() {execute(arguments)}
    }
    func removePresetPrompt(_ presets:[[String:Any]]) {
        guard !presets.isEmpty else{return}
        let dialog=PresetDialog(fontSize:CGFloat([16,20,24][textSizeIndex()]),presets:presets)
        if let arguments=dialog.run() {execute(arguments)}
    }
    func chooseSize(_ json:String){
        guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let relative=report["options"] as? [[String:Any]] else {message("Size preview unavailable","No qualified size choices were returned.");return}
        let presetError=report["preset_error"] as? String
        var choices=relative
        var unavailable:[String]=[]
        for preset in report["presets"] as? [[String:Any]] ?? [] {
            let name=preset["name"] as? String ?? "Unnamed"
            if preset["available"] as? Bool == true {
                var option=preset;option["label"]="Preset: "+name;option["preset"]=name;choices.append(option)
            } else {unavailable.append(name+" — "+(preset["rotation"] as? Int == 90 ? "Portrait":"Landscape")+": "+(preset["reason"] as? String ?? "Unavailable"))}
        }
        guard !choices.isEmpty else {message("Size preview unavailable","No qualified choices are currently available.");return}
        NSApp.activate(ignoringOtherApps:true)
        let presets=report["presets"] as? [[String:Any]] ?? []
        let current=relative.first(where:{$0["size"] as? String == "current"}) ?? [:]
        var notes:[String]=[]
        if let error=presetError {notes.append("Saved presets unavailable\n"+error)}
        if !unavailable.isEmpty {notes.append("Unavailable presets\n"+unavailable.joined(separator:"\n"))}
        let canSave=visibleCapabilities?.contains("preset-save")==true
        let canRemove=visibleCapabilities?.contains("preset-remove")==true
        if !canSave || !canRemove {notes.append(presetCompatibilitySummary(visibleCapabilities,checking:checkingCapabilities)+" Check support in Controls.")}
        let chooser=SizeChooser(choices:choices,current:current,notes:notes.joined(separator:"\n\n"),orientation:report["rotation"] as? Int == 90 ? "Portrait":"Landscape",fontSize:CGFloat([16,20,24][textSizeIndex()]),canSave:presetError==nil && canSave,canRemove:presetError==nil && !presets.isEmpty && canRemove)
        let response=chooser.run()
        if response==1,presetError==nil {savePresetPrompt();return}
        if response==2,presetError==nil {removePresetPrompt(presets);return}
        let index=chooser.selectedIndex
        guard response==0,index>=0,index<choices.count,let fingerprint=choices[index]["fingerprint"] as? String else {return}
        if let preset=choices[index]["preset"] as? String {execute(["preview-start","--preset",preset,"--fingerprint",fingerprint])}
        else if let size=choices[index]["size"] as? String {execute(["preview-start","--size",size,"--fingerprint",fingerprint])}
    }
    func notify(_ health:[String:Any],fresh:Bool) {
        guard fresh else{return}
        let defaults=UserDefaults.standard
        let state=health["status"] as? String ?? ""
        let center=UNUserNotificationCenter.current()
        if state=="ready" || state=="inactive-setup" {
            if !failureAlerts.sent.isEmpty || failureAlerts.pending != nil {
                failureAlerts.clear();defaults.removeObject(forKey:"failureIncidents")
                center.removePendingNotificationRequests(withIdentifiers:["display-recovery"])
                center.removeDeliveredNotifications(withIdentifiers:["display-recovery"])
            }
            return
        }
        guard let incident=failureIncident(health),let attempt=failureAlerts.reserve(incident) else{return}
        let r=health["recovery"] as? [String:Any] ?? [:]
        let content=UNMutableNotificationContent();content.title="Display Auto needs attention"
        content.body=health["error"] as? String ?? r["error"] as? String ?? "Recovery stopped after three attempts. Open the display menu for details."
        content.categoryIdentifier=state=="state-error" || state=="preview-needs-repair" ? "state-failure":"failure"
        content.userInfo=["incident":incident]
        center.getNotificationSettings{settings in
            DispatchQueue.main.async {
                guard self.failureAlerts.current(attempt) else{return}
                let current=self.read("health.json")
                guard settings.authorizationStatus == .authorized,statusFresh(current),failureIncident(current)==incident else {
                    self.failureAlerts.finish(attempt,success:false);return
                }
                center.add(UNNotificationRequest(identifier:"display-recovery",content:content,trigger:nil)){error in
                    DispatchQueue.main.async {
                        self.failureAlerts.finish(attempt,success:error==nil)
                        defaults.set(self.failureAlerts.sent,forKey:"failureIncidents")
                    }
                }
            }
        }
    }
    func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping ()->Void){
        if let command=notificationCommand(response.actionIdentifier) {
            DispatchQueue.main.async {
                let health=self.read("health.json")
                let incident=response.notification.request.content.userInfo["incident"] as? String
                let staleRepair=command=="repair-audio" && (incident==nil || !statusFresh(health) || failureIncident(health) != incident)
                if self.busy || staleRepair {self.showPanel()}
                else {self.execute([command])}
                completionHandler()
            }
        } else {completionHandler()}
    }
    func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void){completionHandler([.banner,.list])}
}
let app=NSApplication.shared
let delegate=App();app.delegate=delegate;app.run()
