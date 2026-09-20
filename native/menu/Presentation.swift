// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import UserNotifications

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
