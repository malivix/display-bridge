// SPDX-License-Identifier: MIT
import AppKit
import UserNotifications
import Darwin

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
func previewRemaining(_ health:[String:Any],_ now:Double=Date().timeIntervalSince1970)->Int {
    let age=now-(health["updated_at"] as? Double ?? 0)
    guard age>=0 && age<15,let preview=health["preview"] as? [String:Any],preview["state"] as? String == "preview",let remaining=preview["remaining_seconds"] as? Double,remaining.isFinite else{return 0}
    return Int(max(0,min(20,ceil(remaining-age))))
}
func dashboard(_ health:[String:Any],_ control:[String:Any],_ now:Double=Date().timeIntervalSince1970)->String {
    let age=now-(health["updated_at"] as? Double ?? 0)
    let fresh=age>=0 && age<15
    let state=fresh ? health["status"] as? String ?? "unknown":"unavailable"
    let titles=["ready":"Ready","waiting-for-ddc":"Waiting for monitor response","inactive-setup":"Saved monitor pair is not connected","paused":"Paused","degraded":"Recovery needs attention","state-error":"Saved settings need attention","unavailable":"Controller status unavailable","settling":"Waiting for stable inputs","recovering":"Recovering"]
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
    let trusted=fresh && state=="ready" && !automationPaused(control,now)
    if !trusted {lines.append("\nLast reported details below may be out of date. Run Check health for a fresh inspection.")}
    let inputs=health["inputs"] as? [String:Int] ?? [:]
    for (key,label,a,b) in [("pg","PG42UQ",17,18),("benq","BenQ RD280UG",19,15)] {
        let input=inputs[key]
        let owner=input==a ? "Mac A":input==b ? "Mac B":"Unknown input"
        lines.append("\n\(label): \(owner)")
    }
    let profile=health["profile"] as? String ?? "unknown"
    let profiles=["extended":"Two independent desktops","pg":"PG desktop; hidden BenQ mirrors PG","benq":"BenQ desktop; hidden PG mirrors BenQ","away":"Both away; previous desktop layout preserved"]
    lines.append("\nDesktop: \(profiles[profile] ?? "Not confirmed")")
    let rotation=health["rotation"] as? [String:Any] ?? [:]
    let automatic=control["auto_rotate"] as? Bool ?? true
    let angle=(rotation["sensor_degrees"] as? Int).map{"\($0)°"} ?? "not currently reported"
    lines.append("BenQ rotation: \(automatic ? "automatic":"manual") · sensor \(angle)")
    let audio=health["audio"] as? [String:Any] ?? [:],selected=audio["selected"] as? [String:Any] ?? [:]
    lines.append("Selected speaker: \(selected["name"] as? String ?? "Not reported")")
    let recovery=health["recovery"] as? [String:Any] ?? [:]
    let pending=recovery["pending"] as? Bool == true || health["audio_journal_pending"] as? Bool == true
    lines.append("Recovery: \(pending ? "pending (\(recovery["attempts"] as? Int ?? 0)/3 attempts)":"no pending recovery reported")")
    if let error=health["error"] as? String ?? recovery["error"] as? String {lines.append("\n\(error)")}
    if automationPaused(control,now) {
        if let until=control["pause_until"] as? Double,until>now {lines.append("\nAutomation resumes at \(Date(timeIntervalSince1970:until).formatted(date:.omitted,time:.shortened)).")}
        else {lines.append("\nAutomation is paused until you resume it from Controls.")}
    }
    lines.append("\nSettings and recovery details come from the controller. Speaker selection does not prove audible sound.")
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

func notificationDecision(_ state:String,_ fresh:Bool,_ sent:Bool)->String {
    if !fresh{return "none"}
    if state=="ready" || state=="inactive-setup" {return "clear"}
    return (state=="degraded" || state=="state-error" || state=="preview-needs-repair") && !sent ? "send":"none"
}
if CommandLine.arguments.contains("--self-test") {
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
    precondition(dashboard(live,[:],99).contains("Controller status unavailable"))
    var waiting=live;waiting["status"]="waiting-for-ddc"
    precondition(dashboard(waiting,[:],101).contains("may be out of date"))
    precondition(automationPaused(["paused":true,"pause_until":200.0],100))
    precondition(!automationPaused(["paused":true,"pause_until":200.0],200))
    precondition(automationPaused(["paused":true],200))
    precondition(healthSummary("{\"status\":\"ok\",\"checks\":[]}").contains("Read-only check: ok"))
    precondition(ddcSummary("invalid").contains("could not be read"))
    precondition(ddcSummary("{\"episodes\":[],\"ddc_interruptions\":0}").contains("No interruptions recorded"))
    let ddc=ddcSummary("{\"ddc_interruptions\":1,\"episodes\":[{\"started\":\"now\",\"monitor\":\"benq\",\"seconds\":1.25,\"recovered\":\"later\"}]}")
    precondition(ddc.contains("Read recovered · 1.25 s") && ddc.contains("benq"))
    precondition(notificationDecision("degraded",true,false)=="send")
    precondition(notificationDecision("state-error",true,false)=="send")
    precondition(notificationDecision("state-error",true,true)=="none")
    precondition(notificationDecision("degraded",true,true)=="none")
    precondition(notificationDecision("degraded",false,false)=="none")
    for state in ["recovering","settling","paused","waiting-for-ddc"] {precondition(notificationDecision(state,true,false)=="none")}
    precondition(notificationDecision("ready",true,true)=="clear")
    precondition(notificationDecision("inactive-setup",true,true)=="clear")
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
    var item:NSStatusItem!
    var timer:Timer?
    var panel:NSWindow?
    var panelText:NSTextView?
    var panelActions:[NSButton]=[]
    var previewActions:[NSButton]=[]
    var previewToken:String?
    var busy=false
    var menuOpen=false
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {showPanel();return true}
    func showPanel() {
        if panel==nil {
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:600,height:480),styleMask:[.titled,.closable],backing:.buffered,defer:false)
            window.title="Display Auto";window.isReleasedWhenClosed=false;window.center()
            let scroll=NSScrollView(frame:NSRect(x:20,y:96,width:560,height:362));scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
            let text=NSTextView(frame:scroll.bounds);text.isEditable=false;text.isSelectable=true;text.font=NSFont.systemFont(ofSize:14)
            text.drawsBackground=false;text.isVerticallyResizable=true;text.isHorizontallyResizable=false;text.textContainer?.widthTracksTextView=true
            scroll.documentView=text;window.contentView?.addSubview(scroll);panelText=text;panel=window
            let button=NSButton(title:"Open controls",target:self,action:#selector(openControls(_:)))
            button.frame=NSRect(x:20,y:16,width:140,height:28);window.contentView?.addSubview(button)
            for (index,title,action) in [(0,"Check health","doctor"),(1,"Save diagnostics","diagnostics")] {
                let actionButton=NSButton(title:title,target:self,action:#selector(panelAction(_:)))
                actionButton.identifier=NSUserInterfaceItemIdentifier(action);actionButton.frame=NSRect(x:170+index*180,y:16,width:170,height:28)
                window.contentView?.addSubview(actionButton);panelActions.append(actionButton)
            }
            for (index,title,action) in [(0,"Preview size…","preview-options"),(1,"Keep this size","preview-keep"),(2,"Revert size","preview-revert")] {
                let actionButton=NSButton(title:title,target:self,action:#selector(panelAction(_:)))
                actionButton.identifier=NSUserInterfaceItemIdentifier(action);actionButton.frame=NSRect(x:20+index*180,y:54,width:170,height:28)
                window.contentView?.addSubview(actionButton);previewActions.append(actionButton)
            }
        }
        refresh();panel?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc func openControls(_ sender:NSButton){refresh();item.menu?.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.height),in:sender)}
    @objc func panelAction(_ sender:NSButton){if let action=sender.identifier?.rawValue {
        if action=="preview-keep" || action=="preview-revert" {if let token=previewToken {execute([action,"--token",token])}}
        else {execute([action])}
    }}
    func read(_ name:String)->[String:Any] {
        guard let data=try? Data(contentsOf:root.appendingPathComponent(name)),let value=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else{return [:]};return value
    }
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        item=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        item.button?.image=NSImage(systemSymbolName:"display.2",accessibilityDescription:"Display Auto")
        UNUserNotificationCenter.current().delegate=self
        let repair=UNNotificationAction(identifier:"repair",title:"Repair audio",options:[])
        let inspect=UNNotificationAction(identifier:"inspect",title:"Check health",options:[])
        UNUserNotificationCenter.current().setNotificationCategories([UNNotificationCategory(identifier:"failure",actions:[repair],intentIdentifiers:[],options:[]),UNNotificationCategory(identifier:"state-failure",actions:[inspect],intentIdentifiers:[],options:[])])
        timer=Timer.scheduledTimer(withTimeInterval:2,repeats:true){[weak self] _ in self?.refresh()}
        refresh()
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
        let age=Date().timeIntervalSince1970-(health["updated_at"] as? Double ?? 0)
        let fresh=age>=0 && age<15
        let state=fresh ? health["status"] as? String ?? "Unknown" : "Controller unavailable"
        item.button?.title=state == "degraded" || state == "state-error" || !fresh ? " !" : ""
        item.button?.toolTip="Display Auto: \(state)"
        var detail=dashboard(health,control)
        let lastPreview=read("preview-status.json")
        if !state.hasPrefix("preview-"),let error=lastPreview["error"] as? String {detail += "\n\nLast size preview: \(error)"}
        if panelText?.string != detail {panelText?.string=detail}
        for button in panelActions {button.isEnabled = !busy}
        let preview=health["preview"] as? [String:Any] ?? [:]
        previewToken=preview["token"] as? String
        for button in previewActions {
            let action=button.identifier?.rawValue
            if action=="preview-options" {button.isEnabled = !busy && fresh && state=="ready" && health["profile"] as? String == "extended" && !automationPaused(control)}
            else {button.isEnabled = !busy && fresh && previewToken != nil && preview["state"] as? String == "preview" && previewRemaining(health)>0}
        }
        notify(health,fresh:fresh)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let data:[String:Any]=["updated_at":Date().timeIntervalSince1970,"pid":ProcessInfo.processInfo.processIdentifier,"app_version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","notification_authorization":settings.authorizationStatus.rawValue,"status":state]
            if let bytes=try? JSONSerialization.data(withJSONObject:data){try? bytes.write(to:self.root.appendingPathComponent("menu-health.json"),options:.atomic)}
        }
        if menuOpen{return}
        let menu=NSMenu();menu.delegate=self
        add(menu,"Display Auto \(health["version"] as? String ?? "—") · Mac \(health["host"] as? String ?? "?")")
        add(menu,"Status: \(state)")
        if state=="waiting-for-ddc" {add(menu,"Waiting for monitor response; layout changes held")}
        add(menu,"Profile: \(health["profile"] as? String ?? "—")")
        let rotation=health["rotation"] as? [String:Any] ?? [:]
        if rotation["enabled"] as? Bool == true {
            let angle=(rotation["sensor_degrees"] as? Int).map { "\($0)°" } ?? (rotation["state"] as? String ?? "Checking")
            add(menu,"BenQ rotation: \(angle)")
        }
        let audio=health["audio"] as? [String:Any] ?? [:],selected=audio["selected"] as? [String:Any] ?? [:]
        add(menu,"Speaker: \(selected["name"] as? String ?? "—")")
        let recovery=health["recovery"] as? [String:Any] ?? [:]
        add(menu,"Recovery: \(recovery["attempts"] as? Int ?? 0)/3 attempts")
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
        add(menu,"Repair audio",paused || manual || state=="state-error" ? nil:["repair-audio"])
        let preferences=control["speaker_preferences"] as? [String:String] ?? [:]
        for (profile,label,defaultSpeaker) in [("extended","Both monitors here","pg"),("pg","Only PG here","pg"),("benq","Only BenQ here","benq"),("away","Both monitors away","fallback")] {
            let entry=NSMenuItem(title:"Speaker: \(label)",action:nil,keyEquivalent:"");let sub=NSMenu()
            for (speaker,title) in [("pg","PG42UQ"),("benq","BenQ"),("fallback","Built-in speakers"),("preserve","Preserve current output")] {
                // Do not offer an inactive monitor as an audible destination.
                if speaker == "pg" && (profile == "benq" || profile == "away"){continue}
                if speaker == "benq" && (profile == "pg" || profile == "away"){continue}
                add(sub,title,["speaker","--profile",profile,"--speaker",speaker],checked:(preferences[profile] ?? defaultSpeaker)==speaker)
            };entry.submenu=sub;menu.addItem(entry)
        }
        menu.addItem(.separator())
        add(menu,"Open status window",["panel"])
        add(menu,"Preview display size…",fresh && state=="ready" && health["profile"] as? String == "extended" && !paused ? ["preview-options"]:nil)
        if let token=previewToken,preview["state"] as? String == "needs-repair" {add(menu,"Retry size restoration",["preview-repair","--token",token])}
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
        if args==["notifications"] {
            UNUserNotificationCenter.current().requestAuthorization(options:[.alert]){granted,error in
                DispatchQueue.main.async {self.message(granted ? "Failure notifications enabled":"Notifications are disabled",error?.localizedDescription ?? "You can change this in System Settings → Notifications → Display Auto.")}
            };return
        }
        guard !busy else{return};busy=true
        DispatchQueue.global().async {
            let response=runMenuCommand(self.command,args)
            let result=response.output,code=response.code
            DispatchQueue.main.async {
                self.busy=false
                if code != 0 {self.message("Action could not complete",result)}
                else if args.first=="diagnostics" {NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:result.trimmingCharacters(in:.whitespacesAndNewlines))])}
                else if args.first=="history" {self.message("Transition timing summary",timingSummary(result))}
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
        let decision=notificationDecision(state,fresh,defaults.string(forKey:"failureNotified") != nil)
        if decision=="clear" {defaults.removeObject(forKey:"failureNotified");return}
        guard decision=="send" else{return}
        let r=health["recovery"] as? [String:Any] ?? [:]
        let content=UNMutableNotificationContent();content.title="Display Auto needs attention"
        content.body=health["error"] as? String ?? r["error"] as? String ?? "Recovery stopped after three attempts. Open the display menu for details."
        content.categoryIdentifier=state=="state-error" || state=="preview-needs-repair" ? "state-failure":"failure"
        UNUserNotificationCenter.current().getNotificationSettings{settings in
            guard settings.authorizationStatus == .authorized else{return}
            defaults.set("sent",forKey:"failureNotified")
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"display-recovery",content:content,trigger:nil)){error in
                if error != nil {defaults.removeObject(forKey:"failureNotified")}
            }
        }
    }
    func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping ()->Void){
        if response.actionIdentifier=="repair"{DispatchQueue.main.async{self.execute(["repair-audio"])}};completionHandler()
        if response.actionIdentifier=="inspect"{DispatchQueue.main.async{self.execute(["doctor"])}}
    }
    func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void){completionHandler([.banner,.list])}
}
let app=NSApplication.shared
let delegate=App();app.delegate=delegate;app.run()
