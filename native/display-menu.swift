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
    statusFresh(health,now) && health["status"] as? String == "ready" && !automationPaused(control,now) ? "":"Last known · "
}
func operationTitle(_ action:String)->String {
    let names=["display-info":"Inspecting display modes","doctor":"Checking health","diagnostics":"Saving diagnostics","history":"Reading transition history",
        "ddc-history":"Reading monitor history","preview-options":"Inspecting size choices","monitor-settings":"Reading monitor settings",
        "monitor-adjust":"Adjusting monitor settings","preview-start":"Requesting size preview","preview-keep":"Requesting saved size",
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
func audioRepairReason(_ health:[String:Any],_ control:[String:Any],_ busy:Bool)->String? {
    if busy {return "Wait for the current command to finish."}
    if !statusFresh(health) {return "Controller status is unavailable; check health first."}
    if automationPaused(control) {return "Resume automation before repairing audio."}
    if (control["audio_manual_until"] as? Double ?? 0)>Date().timeIntervalSince1970 {return "Resume automatic audio before repairing audio."}
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
func dashboard(_ health:[String:Any],_ control:[String:Any],_ now:Double=Date().timeIntervalSince1970)->String {
    let fresh=statusFresh(health,now)
    let state=fresh ? health["status"] as? String ?? "unknown":"unavailable"
    let titles=["starting":"Starting controller","waiting-for-known-input":"Unrecognized monitor input; layout changes held","ready":"Ready","waiting-for-ddc":"Waiting for monitor response","inactive-setup":"Saved monitor pair is not connected","paused":"Paused","degraded":"Recovery needs attention","state-error":"Saved settings need attention","unavailable":"Controller status unavailable","settling":"Waiting for stable inputs","recovering":"Recovering"]
    var lines=["\(titles[state] ?? state) · Mac \(health["host"] as? String ?? "?") · v\(health["version"] as? String ?? "—")"]
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
    let recovery=health["recovery"] as? [String:Any] ?? [:]
    let pending=recovery["pending"] as? Bool == true || health["audio_journal_pending"] as? Bool == true
    lines.append("\(prefix)Recovery: \(pending ? "pending (\(recovery["attempts"] as? Int ?? 0)/3 attempts)":"no pending recovery reported")")
    if let error=health["error"] as? String ?? recovery["error"] as? String {lines.append("\n\(error)")}
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
    let recovery=health["recovery"] as? [String:Any] ?? [:]
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
    let rotationMode=rotation["enabled"] as? Bool != true ? "not calibrated":control["auto_rotate"] as? Bool == false ? "manual":"automatic"
    let routing=automationPaused(control) ? "Automation is paused":audioOverride ? "Manual output preservation is active":"Automatic routing follows profile preferences"
    let pending=recovery["pending"] as? Bool == true || health["audio_journal_pending"] as? Bool == true
    let error=health["error"] as? String ?? recovery["error"] as? String
    let recoveryText=error ?? (pending ? "Recovery pending; inspect Details for attempts and next steps":"No pending recovery reported")
    return [
        StatusSection(title:"Overview",body:(health["status"] as? String ?? "").hasPrefix("preview-") ? dashboard(health,control):headline+"\n"+statusAge(health)+"\n"+prefix+(layouts[profile] ?? "Desktop not confirmed")),
        StatusSection(title:"PG42UQ",body:prefix+owner("pg",17,18)),
        StatusSection(title:"BenQ RD280UG",body:prefix+owner("benq",19,15)+"\n\(prefix)Rotation: \(rotationMode) · sensor \(sensor)"),
        StatusSection(title:"Audio",body:prefix+(selected["name"] as? String ?? "Output not reported")+"\n"+routing+"\nSpeaker selection does not prove audible sound."),
        StatusSection(title:"Recovery",body:prefix+recoveryText)
    ]
}
func displaySummary(_ json:String)->String {
    guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
          report["read_only"] as? Bool == true,let rows=report["displays"] as? [[String:Any]] else{return "Display snapshot could not be read. Refresh after switching settles."}
    var lines=["Read-only mode snapshot — use Refresh after changing inputs or display settings."]
    if let stamp=report["observed_at"] as? Double,stamp.isFinite {
        lines.append("Observed: \(Date(timeIntervalSince1970:stamp).formatted(date:.abbreviated,time:.standard))")
    }
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
    var lines=["Measured application time — median / slowest"]
    for (key,label) in [("extended","Both monitors here"),("pg","Only PG here"),("benq","Only BenQ here"),("away","Both monitors away")] {
        guard let profile=profiles[key],let phases=profile["seconds"] as? [String:[String:Any]] else{continue}
        lines.append("\n\(label)")
        for (phase,name) in [("total","Application total"),("rotation_check","Rotation check and change"),("layout_apply","Layout application"),("input_confirmation","Input recheck"),("audio","Audio recovery"),("settling","Initial stable-read interval")] {
            guard let stats=phases[phase],let median=stats["median"] as? Double,let maximum=stats["max"] as? Double else{continue}
            let count=stats["count"] as? Int ?? profile["count"] as? Int ?? 0
            lines.append(String(format:"%@: %.2f / %.2f s (%d samples)",name,median,maximum,count))
        }
    }
    if profiles.isEmpty{lines.append("\nNo completed transitions recorded yet.")}
    lines.append("\nPhysical input-switch time before the first valid reading is not measured. The stable-read interval is separate from application time. Older records lack the rotation/layout breakdown. Sound still requires listening.")
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
if CommandLine.arguments.contains("--self-test") {
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
    precondition(timingSummary("invalid").contains("could not be read"))
    let timing=timingSummary("{\"profiles\":{\"extended\":{\"count\":4,\"seconds\":{\"total\":{\"median\":2,\"max\":5,\"count\":3}}}}}")
    precondition(timing.contains("Both monitors here") && timing.contains("2.00 / 5.00 s (3 samples)"))
    print("PASS notification policy: persistent failure only, deduplication, freshness and re-arm")
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
final class App: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    let root=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/display-auto")
    let command=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/display-auto.sh")
    let demo=CommandLine.arguments.contains("--demo") || Bundle.main.object(forInfoDictionaryKey:"DisplayBridgeDemo") as? Bool == true
    var ownership:MenuOwnership?
    var item:NSStatusItem!
    var timer:Timer?
    var panel:NSWindow?
    var panelText:NSTextView?
    var modeText:NSTextView?
    var speakerPopups:[String:NSPopUpButton]=[:]
    var audioInfo:NSTextField?
    var audioRepair:NSButton?
    var audioReason:NSTextField?
    var overviewFields:[(NSTextField,NSTextField)]=[]
    var pauseButton:NSButton?
    var displayTextIndex:Int?
    var panelActions:[NSButton]=[]
    var previewActions:[NSButton]=[]
    var previewToken:String?
    var busy=false
    var operationStarted:Double?
    var operationName=""
    var operationResult=""
    var menuOpen=false
    var failureAlerts=FailureAlerts(sent:Array((UserDefaults.standard.stringArray(forKey:"failureIncidents") ?? []).prefix(16)))
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {showPanel();return true}
    func showPanel() {
        if panel==nil {
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:640,height:600),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
            window.title=demo ? "Display Bridge — Demo":"Display Auto";window.isReleasedWhenClosed=false;window.minSize=NSSize(width:600,height:480);window.center()
            let scroll=NSScrollView(frame:NSRect(x:20,y:138,width:600,height:440));scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
            scroll.autoresizingMask=[.width,.height]
            let text=NSTextView(frame:scroll.bounds);text.isEditable=false;text.isSelectable=true;text.font=NSFont.systemFont(ofSize:CGFloat([16,20,24][textSizeIndex()]))
            text.drawsBackground=false;text.isVerticallyResizable=true;text.isHorizontallyResizable=false;text.textContainer?.widthTracksTextView=true
            text.setAccessibilityLabel("Display status and command results")
            scroll.documentView=text;panelText=text;panel=window
            let tabs=NSTabView(frame:NSRect(x:20,y:138,width:600,height:440))
            tabs.autoresizingMask=[.width,.height]
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
            }
            overview.view=overviewScroll;tabs.addTabViewItem(overview)
            let details=NSTabViewItem(identifier:"details");details.label="Details";details.view=scroll;tabs.addTabViewItem(details)
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
            refreshModes.identifier=NSUserInterfaceItemIdentifier("display-info");refreshModes.frame=NSRect(x:12,y:12,width:220,height:32)
            modeView.addSubview(refreshModes);panelActions.append(refreshModes)
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
                let title=NSTextField(wrappingLabelWithString:label);title.widthAnchor.constraint(equalToConstant:190).isActive=true
                let popup=NSPopUpButton();popup.identifier=NSUserInterfaceItemIdentifier(profile)
                popup.target=self;popup.action=#selector(selectSpeaker(_:));popup.setAccessibilityLabel("Speaker when "+label.lowercased())
                for (key,name) in speakerChoices(profile) {popup.addItem(withTitle:name);popup.lastItem?.representedObject=key}
                popup.widthAnchor.constraint(equalToConstant:250).isActive=true;speakerPopups[profile]=popup
                let row=NSStackView(views:[title,popup]);row.orientation = .horizontal;row.spacing=12;audioStack.addArrangedSubview(row)
            }
            for (title,action) in [("Preserve output for 30 minutes","audio-manual"),("Resume automatic audio","audio-auto"),("Repair audio","repair-audio")] {
                let button=NSButton(title:title,target:self,action:#selector(panelAction(_:)));button.identifier=NSUserInterfaceItemIdentifier(action)
                audioStack.addArrangedSubview(button)
                if action=="repair-audio" {audioRepair=button} else {panelActions.append(button)}
            }
            let reason=NSTextField(wrappingLabelWithString:"");audioStack.addArrangedSubview(reason)
            reason.widthAnchor.constraint(equalTo:audioStack.widthAnchor,constant:-32).isActive=true;audioReason=reason
            audioTab.view=audioScroll;tabs.addTabViewItem(audioTab)
            window.contentView?.addSubview(tabs)
            applyTextSize(textSizeIndex())
            let label=NSTextField(labelWithString:"Text size")
            label.frame=NSRect(x:20,y:103,width:130,height:24);window.contentView?.addSubview(label)
            let sizes=NSSegmentedControl(labels:["Standard","Large","Largest"],trackingMode:.selectOne,target:self,action:#selector(changeTextSize(_:)))
            sizes.frame=NSRect(x:170,y:98,width:310,height:32);sizes.selectedSegment=textSizeIndex()
            sizes.setAccessibilityLabel("Status text size");window.contentView?.addSubview(sizes)
            let button=NSButton(title:"More controls",target:self,action:#selector(openControls(_:)))
            button.frame=NSRect(x:20,y:16,width:140,height:28);window.contentView?.addSubview(button)
            for (index,title,action) in [(0,"Check health","doctor"),(1,"Save diagnostics","diagnostics")] {
                let actionButton=NSButton(title:title,target:self,action:#selector(panelAction(_:)))
                actionButton.identifier=NSUserInterfaceItemIdentifier(action);actionButton.frame=NSRect(x:170+index*180,y:16,width:170,height:28)
                window.contentView?.addSubview(actionButton);panelActions.append(actionButton)
            }
            let pause=NSButton(title:"Pause",target:self,action:#selector(togglePause(_:)))
            pause.frame=NSRect(x:540,y:98,width:80,height:32);pause.autoresizingMask=[.minXMargin];window.contentView?.addSubview(pause);pauseButton=pause
            for (index,title,action) in [(0,"Preview size…","preview-options"),(1,"Keep this size","preview-keep"),(2,"Revert size","preview-revert")] {
                let actionButton=NSButton(title:title,target:self,action:#selector(panelAction(_:)))
                actionButton.identifier=NSUserInterfaceItemIdentifier(action);actionButton.frame=NSRect(x:20+index*180,y:54,width:170,height:28)
                window.contentView?.addSubview(actionButton);previewActions.append(actionButton)
            }
        }
        refresh();panel?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    func textSizeIndex()->Int {displayTextIndex ?? min(2,max(0,UserDefaults.standard.integer(forKey:"statusTextSize")))}
    func applyTextSize(_ index:Int) {
        let size=CGFloat([16,20,24][index])
        panelText?.font=NSFont.systemFont(ofSize:size)
        modeText?.font=NSFont.systemFont(ofSize:size)
        audioInfo?.font=NSFont.systemFont(ofSize:size);audioReason?.font=NSFont.systemFont(ofSize:size)
        for (heading,body) in overviewFields {heading.font=NSFont.boldSystemFont(ofSize:size);body.font=NSFont.systemFont(ofSize:size)}
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
    func read(_ name:String)->[String:Any] {
        if demo {
            if name=="health.json" {return ["host":"A","version":"Demo","updated_at":Date().timeIntervalSince1970,
                "status":"ready","profile":"extended","inputs":["pg":17,"benq":19],
                "rotation":["enabled":true,"sensor_degrees":90],"audio":["selected":["name":"Example monitor speakers"]]]}
            return [:]
        }
        guard let data=try? Data(contentsOf:root.appendingPathComponent(name)),let value=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else{return [:]};return value
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
        entry.target=self;entry.representedObject=args;entry.state=checked ? .on:.off;entry.isEnabled=args != nil && !busy;menu.addItem(entry)
    }
    func refresh() {
        let health=read("health.json"),control=read("control.json")
        let fresh=statusFresh(health)
        let prefix=detailPrefix(health,control)
        let state=fresh ? health["status"] as? String ?? "Unknown" : "Controller unavailable"
        item.button?.title=state == "degraded" || state == "state-error" || !fresh ? " !" : ""
        item.button?.toolTip="Display Auto: \(state)"
        let tracked=commandSummary(health,control)
        var progress=operationResult
        if let started=operationStarted {
            let elapsed=Int(max(0,ProcessInfo.processInfo.systemUptime-started))
            progress="\(operationName)… \(elapsed)s elapsed. Command deadline: 45s."
        }
        let sections=statusSections(health,control)
        for (index,fields) in overviewFields.enumerated() where index<sections.count {
            var body=sections[index].body
            if index==0 {
                if !tracked.isEmpty {body += "\n\n"+tracked}
                if !progress.isEmpty {body += "\n\n"+progress}
            }
            if fields.1.stringValue != body {fields.1.stringValue=body;fields.1.setAccessibilityValue(body)}
        }
        pauseButton?.title=automationPaused(control) ? "Resume":"Pause"
        pauseButton?.isEnabled = !busy
        var detail=dashboard(health,control)
        if !tracked.isEmpty {detail=tracked+"\n\n"+detail}
        if !progress.isEmpty {detail=progress+"\n\n"+detail}
        let lastPreview=read("preview-status.json")
        if !state.hasPrefix("preview-"),let error=lastPreview["error"] as? String {detail += "\n\nLast size preview: \(error)"}
        if let text=panelText,text.string != detail {
            let selection=text.selectedRange()
            let origin=text.enclosingScrollView?.contentView.bounds.origin
            text.string=detail
            let length=(detail as NSString).length
            if selection.location<=length {text.setSelectedRange(NSRange(location:selection.location,length:min(selection.length,length-selection.location)))}
            if let origin=origin {text.enclosingScrollView?.contentView.scroll(to:origin)}
        }
        for button in panelActions {button.isEnabled = !busy}
        let preferences=control["speaker_preferences"] as? [String:String] ?? [:]
        for (profile,popup) in speakerPopups {
            let wanted=preferences[profile] ?? (profile=="away" ? "fallback":profile=="benq" ? "benq":"pg")
            if let entry=popup.itemArray.first(where:{$0.representedObject as? String==wanted}) {popup.select(entry)}
            else {popup.selectItem(at:-1)}
            popup.isEnabled = !busy
        }
        let currentAudio=health["audio"] as? [String:Any] ?? [:]
        let selectedOutput=currentAudio["selected"] as? [String:Any] ?? [:]
        var audioDescription=prefix+"Selected output: \(selectedOutput["name"] as? String ?? "Not reported")\nSpeaker preferences apply to each profile. External headsets remain under your control."
        if let until=control["audio_manual_until"] as? Double,until>Date().timeIntervalSince1970 {
            audioDescription += "\nManual preservation ends at \(Date(timeIntervalSince1970:until).formatted(date:.omitted,time:.shortened))."
        }
        audioInfo?.stringValue=audioDescription
        let reason=audioRepairReason(health,control,busy)
        audioRepair?.isEnabled=reason==nil
        audioReason?.stringValue=reason ?? "Repair uses the existing recovery policy. Listen afterward to confirm sound."

        let preview=health["preview"] as? [String:Any] ?? [:]
        previewToken=preview["token"] as? String
        for button in previewActions {
            let action=button.identifier?.rawValue
            if action=="preview-options" {button.isEnabled = !busy && fresh && state=="ready" && health["profile"] as? String == "extended" && !automationPaused(control)}
            else {button.isHidden = preview["state"] as? String != "preview";button.isEnabled = !busy && fresh && previewToken != nil && preview["state"] as? String == "preview" && previewRemaining(health)>0}
        }
        if !demo {
        notify(health,fresh:fresh)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let data:[String:Any]=["updated_at":Date().timeIntervalSince1970,"pid":ProcessInfo.processInfo.processIdentifier,"app_version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","notification_authorization":settings.authorizationStatus.rawValue,"status":state]
            if let bytes=try? JSONSerialization.data(withJSONObject:data){try? bytes.write(to:self.root.appendingPathComponent("menu-health.json"),options:.atomic)}
        }
        }
        if menuOpen{return}
        let menu=NSMenu();menu.delegate=self
        add(menu,"Display Auto \(health["version"] as? String ?? "—") · Mac \(health["host"] as? String ?? "?")")
        add(menu,"Status: \(state)")
        add(menu,statusAge(health))
        if !progress.isEmpty {add(menu,progress)}
        if state=="waiting-for-ddc" {add(menu,"Waiting for monitor response; layout changes held")}
        add(menu,"\(prefix)Profile: \(health["profile"] as? String ?? "—")")
        let rotation=health["rotation"] as? [String:Any] ?? [:]
        if rotation["enabled"] as? Bool == true {
            let angle=(rotation["sensor_degrees"] as? Int).map { "\($0)°" } ?? (rotation["state"] as? String ?? "Checking")
            add(menu,"\(prefix)BenQ rotation: \(angle)")
        }
        let audio=health["audio"] as? [String:Any] ?? [:],selected=audio["selected"] as? [String:Any] ?? [:]
        add(menu,"\(prefix)Speaker: \(selected["name"] as? String ?? "—")")
        let recovery=health["recovery"] as? [String:Any] ?? [:]
        add(menu,"\(prefix)Recovery: \(recovery["attempts"] as? Int ?? 0)/3 attempts")
        if let error=recovery["error"] as? String {add(menu,String(error.prefix(150)))}
        if let error=health["error"] as? String {add(menu,String(error.prefix(150)))}
        menu.addItem(.separator())
        let paused=automationPaused(control)
        add(menu,paused ? "Resume automation":"Pause automation",[paused ? "resume":"pause"])
        add(menu,"Pause for 15 minutes",["pause-for","--minutes","15"])
        if rotation["enabled"] as? Bool == true {
            let automatic=control["auto_rotate"] as? Bool ?? true
            add(menu,"Automatic BenQ rotation",[automatic ? "rotation-manual":"rotation-auto"],checked:automatic)
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
                add(sub,title,["speaker","--profile",profile,"--speaker",speaker],checked:(preferences[profile] ?? defaultSpeaker)==speaker)
            };entry.submenu=sub;menu.addItem(entry)
        }
        menu.addItem(.separator())
        add(menu,"Open status window",["panel"])
        add(menu,"Preview display size…",fresh && state=="ready" && health["profile"] as? String == "extended" && !paused ? ["preview-options"]:nil)
        if fresh,let token=previewToken,preview["state"] as? String == "needs-repair" {add(menu,"Retry size restoration",["preview-repair","--token",token])}
        if let token=previewToken,previewRemaining(health)>0 {
            add(menu,"Keep preview size (\(previewRemaining(health))s)",["preview-keep","--token",token])
            add(menu,"Revert preview size",["preview-revert","--token",token])
        }
        let inputs=health["inputs"] as? [String:Int] ?? [:]
        let hostB=health["host"] as? String == "B"
        for (role,label,localInput) in [("pg","PG42UQ",hostB ? 18:17),("benq","BenQ",hostB ? 15:19)] {
            let entry=NSMenuItem(title:"\(label) brightness and volume",action:nil,keyEquivalent:"")
            let sub=NSMenu()
            let enabled=fresh && state=="ready" && !paused && inputs[role]==localInput
            add(sub,"Read current settings…",fresh && inputs[role]==localInput ? ["monitor-settings","--monitor",role]:nil)
            if !enabled {add(sub,"Available when this monitor shows this Mac and is ready")}
            for (feature,name) in [("luminance","Brightness"),("volume","Speaker volume")] {
                for step in [-5,5] {
                    add(sub,"\(name) \(step>0 ? "+5":"−5")%",enabled ? ["monitor-adjust","--monitor",role,"--feature",feature,"--step",String(step)]:nil)
                }
            }
            entry.submenu=sub;menu.addItem(entry)
        }
        add(menu,"Save diagnostic report…",["diagnostics"])
        add(menu,"Check system health…",["doctor"])
        add(menu,"Show transition timing summary…",["history"])
        add(menu,"Show monitor communication history…",["ddc-history"])
        add(menu,"Enable failure notifications…",["notifications"])
        add(menu,"Quit menu bar (automation continues)",["quit"])
        item.menu=menu
    }
    func menuWillOpen(_ menu:NSMenu){menuOpen=true}
    func menuDidClose(_ menu:NSMenu){menuOpen=false}
    @objc func act(_ sender:NSMenuItem){if let args=sender.representedObject as? [String]{execute(args)}}
    func execute(_ args:[String]) {
        if args==["panel"]{showPanel();return}
        if args==["quit"]{NSApp.terminate(nil);return}
        if demo && args==["display-info"] {
            modeText?.string=displaySummary(#"{"read_only":true,"displays":[{"monitor":"pg","available":true,"current":{"width":1920,"height":1080,"pixelWidth":3840,"pixelHeight":2160},"saved":{"width":1920,"height":1080,"pixelWidth":3840,"pixelHeight":2160},"hz":120,"hidpi":true,"fixed_refresh":true,"hdr_preference":false,"saved_mode_matches":true},{"monitor":"benq","available":false,"reason":"Synthetic example: monitor showing the other Mac"}],"limits":"Demo data only. No monitor was inspected or changed."}"#)
            return
        }
        if demo {message("Hardware-free demo","This preview uses synthetic status. Monitor, audio, diagnostic and notification actions are disabled.");return}
        if args==["notifications"] {
            UNUserNotificationCenter.current().requestAuthorization(options:[.alert]){granted,error in
                DispatchQueue.main.async {self.message(granted ? "Failure notifications enabled":"Notifications are disabled",error?.localizedDescription ?? "You can change this in System Settings → Notifications → Display Auto.")}
            };return
        }
        guard !busy else{return}
        busy=true;operationStarted=ProcessInfo.processInfo.systemUptime
        operationName=operationTitle(args.first ?? "");operationResult=""
        showPanel()
        DispatchQueue.global().async {
            let response=runMenuCommand(self.command,args)
            let result=response.output,code=response.code
            DispatchQueue.main.async {
                self.busy=false;self.operationStarted=nil
                if code != 0 {self.operationResult=code==124 ? "Command timed out; inspect status before retrying.":"Command failed; see the error for details."}
                else if let data=result.data(using:.utf8),let response=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],response["requested"] != nil {
                    self.operationResult=response["request_id"] == nil ? "Request saved; this controller does not report command completion.":""
                } else {self.operationResult="Command returned. See the result and current status below."}
                self.refresh()
                if code != 0 {self.message("Action could not complete",result)}
                else if args.first=="diagnostics" {NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:result.trimmingCharacters(in:.whitespacesAndNewlines))])}
                else if args.first=="history" {self.message("Transition timing summary",timingSummary(result))}
                else if args.first=="display-info" {self.modeText?.string=displaySummary(result)}
                else if args.first=="doctor" {self.message("System health",healthSummary(result))}
                else if args.first=="ddc-history" {self.message("Monitor communication",ddcSummary(result))}
                else if args.first=="preview-options" {self.chooseSize(result)}
                else if args.first?.hasPrefix("preview-")==true {self.showPanel()}
                else if args.first=="monitor-adjust",let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] {
                    let name=value["feature"] as? String == "luminance" ? "Brightness":"Speaker volume"
                    let monitor=value["monitor"] as? String == "pg" ? "PG42UQ":"BenQ RD280UG"
                    self.message(name,"\(monitor): \(value["percent"] as? Int ?? 0)%\nConfirmed by monitor readback. Physical steps depend on the monitor's range.")
                }
                else if args.first=="monitor-settings",let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let settings=value["settings"] as? [String:[String:Int]] {
                    let monitor=value["monitor"] as? String == "pg" ? "PG42UQ":"BenQ RD280UG"
                    var lines=["Read-only snapshot · \(monitor)"]
                    for (key,label) in [("luminance","Brightness"),("volume","Speaker volume")] {
                        if let setting=settings[key] {lines.append("\(label): \(setting["percent"] ?? 0)% (\(setting["value"] ?? 0) / \(setting["maximum"] ?? 0))")}
                    }
                    lines.append("\nThese are monitor hardware settings. Speaker volume does not select the macOS audio output. Nothing was changed.")
                    self.message("Current monitor settings",lines.joined(separator:"\n"))
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
    func chooseSize(_ json:String){
        guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let options=report["options"] as? [[String:Any]],!options.isEmpty else {message("Size preview unavailable","No qualified size choices were returned.");return}
        NSApp.activate(ignoringOtherApps:true)
        let alert=NSAlert();alert.messageText="Preview display size"
        var lines=["Fixed 120 Hz · HiDPI · HDR off", "This orientation only. Preview reverts after 20 seconds unless you Keep it."]
        for option in options {
            let label=option["label"] as? String ?? "Size"
            if let modes=option["modes"] as? [String:[String:Any]] {
                let pg=modes["pg"] ?? [:],benq=modes["benq"] ?? [:]
                lines.append("\n\(label): PG \(pg["width"] ?? "?") × \(pg["height"] ?? "?"); BenQ \(benq["width"] ?? "?") × \(benq["height"] ?? "?")")
            }
            alert.addButton(withTitle:label)
        }
        alert.addButton(withTitle:"Cancel").keyEquivalent="\u{1b}"
        alert.informativeText=lines.joined(separator:"\n")
        let index=alert.runModal().rawValue-NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        if index>=0 && index<options.count,let size=options[index]["size"] as? String,let fingerprint=options[index]["fingerprint"] as? String {
            execute(["preview-start","--size",size,"--fingerprint",fingerprint])
        }
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
