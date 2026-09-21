// SPDX-License-Identifier: MIT
import AppKit
import UserNotifications
import Darwin

func runMenuSelfTests() {
    func installationJSON(_ report:[String:Any])->String {String(decoding:try! JSONSerialization.data(withJSONObject:report),as:UTF8.self)}
    let installed=demoInstallationReport("ready",200)
    precondition(installationSummary(installationJSON(installed),200).contains("Reported outcome: Completed"))
    let stoppedInstallation=installationSummary(installationJSON(demoInstallationReport("stale",200)),200)
    precondition(stoppedInstallation.contains("process was not found"))
    precondition(stoppedInstallation.components(separatedBy:"\n\n")[1]=="Outcome unknown · recorded process not found")
    precondition(installationSummary(installationJSON(demoInstallationReport("recovery",200)),200).contains("Recovery completion is unconfirmed"))
    precondition(installationSummary(installationJSON(demoInstallationReport("recovery-wait",200)),200).contains("does not verify its identity"))
    for (key,value) in [("read_only",1 as Any),("schema",true as Any),("updated_at",true as Any),("updated_at",201.0 as Any),("started_at",199.0 as Any),("phase","private error" as Any),("host","unknown" as Any),("recovery","pending" as Any)] {
        var report=installed;report[key]=value
        precondition(installationSummary(installationJSON(report),200).hasPrefix("No valid installation report"))
    }
    var recovered=installed;recovered["status"]="failed";recovered["phase"]="recovery-finished";recovered["recovery"]="completed-unverified"
    recovered["unexpected"]="private machine data"
    let recoveryText=installationSummary(installationJSON(recovered),200)
    precondition(recoveryText.contains("Recovery commands completed") && !recoveryText.contains("private machine data"))
    precondition(installationSummary("{}",200).contains("No valid"))
    var installationCalls:[[String]]=[]
    let oldInstaller=runCompatibleMenuCommand(["installation-status"]) { args,_,_ in
        installationCalls.append(args);return CommandResult(output:"{}",code:0)
    }
    precondition(oldInstaller.code==78 && installationCalls==[["capabilities"]])
    precondition(safeWithoutControls("installation-status"))

    let rotationHealth:[String:Any]=["updated_at":100.0,"status":"ready","profile":"extended","rotation":["enabled":true,"state":"tracking","confirmed":true,"sensor_degrees":90,"sensor_observed_at":99.0,"macos_degrees":0,"macos_observed_at":80.0]]
    let rotationText=rotationSummary(rotationHealth,[:],100)
    precondition(rotationText.contains("sensor confirmed") && rotationText.contains("Last sensor: 90° · read 1 second ago"))
    precondition(rotationText.contains("macOS last readback: 0° · read 20 seconds ago"))
    var phaseHealth=rotationHealth;phaseHealth["status"]="recovering"
    phaseHealth["transition"]=["phase":"layout_apply"];phaseHealth["updated_at"]=98.0
    precondition(rotationSummary(phaseHealth,[:],100).contains("Applying desktop layout · 2s"))
    precondition(rotationSummary(phaseHealth,["paused":true],100).contains("Rotation paused"))
    for invalid:Any in [true,Double.nan,Double.infinity,101.0,80.0,"98"] {
        phaseHealth["updated_at"]=invalid
        precondition(!rotationSummary(phaseHealth,[:],100).contains("Controller phase:"))
    }
    phaseHealth["transition"]=["phase":"private untrusted text"];phaseHealth["updated_at"]=98.0
    precondition(!rotationSummary(phaseHealth,[:],100).contains("private untrusted text"))
    precondition(rotationSummary(rotationHealth,[:],120).contains("status stale"))
    precondition(rotationSummary(rotationHealth,["paused":true],100).contains("Rotation paused"))
    precondition(rotationSummary(rotationHealth,["auto_rotate":false],100).contains("Rotation manual"))
    for (profile,expected) in [("pg","BenQ to show this Mac"),("away","BenQ to show this Mac"),("unknown","known input ownership")] {
        var health=rotationHealth;health["profile"]=profile
        precondition(rotationSummary(health,[:],100).contains(expected))
    }
    for invalid in [true as Any,"99",Double.nan,Double.infinity,101.0,1.0] {
        var health=rotationHealth;var rotation=health["rotation"] as! [String:Any]
        rotation["sensor_observed_at"]=invalid;health["rotation"]=rotation
        let text=rotationSummary(health,[:],100)
        precondition(text.contains("freshness unavailable") && !text.contains("sensor confirmed"))
    }
    for (key,value,expected) in [("sensor_degrees",true as Any,"freshness unavailable"),("confirmed",1 as Any,"matching sensor confirmation"),("state","sensor-unavailable" as Any,"calibrated sensor reading")] {
        var health=rotationHealth;var rotation=health["rotation"] as! [String:Any]
        rotation[key]=value;health["rotation"]=rotation
        precondition(rotationSummary(health,[:],100).contains(expected))
    }
    precondition(rotationSummary(demoState("stale","health.json",100),[:],100).contains("read 91 seconds ago"))
    var previewRotation=rotationHealth;previewRotation["status"]="preview-preview"
    precondition(rotationSummary(previewRotation,[:],100).contains("held during size preview"))
    var waitingRotation=rotationHealth;waitingRotation["status"]="waiting-for-ddc"
    precondition(rotationSummary(waitingRotation,[:],100).contains("valid setup and input readings"))
    var olderRotation=rotationHealth;olderRotation["rotation"]=["enabled":true,"sensor_degrees":90]
    precondition(rotationSummary(olderRotation,[:],100).contains("reading age unavailable"))

    precondition(listeningAnswerLabel(nil)=="uncertain" && listeningAnswerLabel(0)=="uncertain" && listeningAnswerLabel(1)=="heard" && listeningAnswerLabel(2)=="not heard" && listeningAnswerLabel(9)=="uncertain")
    precondition(listeningOutput(#"{"playback_completed":true,"audibility":"unconfirmed","output":"pg"}"#)=="PG42UQ")
    for json in [#"{"playback_completed":1,"audibility":"unconfirmed","output":"pg"}"#,#"{"playback_completed":true,"audibility":"confirmed","output":"pg"}"#,#"{"playback_completed":true,"audibility":"unconfirmed","output":"unknown"}"#] {precondition(listeningOutput(json)==nil)}

    for (scenario,available,layout) in [("ready",2,"extended"),("pg-only",1,"pg-source"),("benq-only",1,"benq-source"),("away",0,"unknown"),("unknown-input",0,"unknown")] {
        let report=demoDisplayReport(scenario)
        precondition((report["inputs"] as? [String:Int]) == (demoState(scenario,"health.json",100)["inputs"] as? [String:Int]))
        precondition((report["logical_layout"] as? [String:Any])?["state"] as? String == layout)
        precondition((report["displays"] as! [[String:Any]]).filter{$0["available"] as? Bool == true}.count==available)
        let json=String(decoding:try! JSONSerialization.data(withJSONObject:report),as:UTF8.self)
        var reading=DisplayReading();precondition(reading.accept(json))
        if scenario=="ready" {precondition(reading.notice(demoState(scenario,"health.json",100),refreshing:false,now:100).contains("Inputs still match"))}
    }
    var oldDemo=DisplayReading()
    precondition(oldDemo.accept(String(decoding:try! JSONSerialization.data(withJSONObject:demoDisplayReport("ready")),as:UTF8.self)))
    precondition(oldDemo.notice(demoState("pg-only","health.json",100),refreshing:false,now:100).contains("Inputs changed"))

    precondition(enrollmentHost(0)==nil && enrollmentHost(1)=="A" && enrollmentHost(2)=="B" && enrollmentHost(3)==nil)
    let enrollmentRows:[[String:Any]]=["pg","benq"].map{role in ["monitor":role,"local_input":role=="pg" ? 18:15,"width":1280,"height":720,"pixelWidth":2560,"pixelHeight":1440,"rotation":0]}
    let enrollment:[String:Any]=["read_only":true,"status":"review-ready","host":"B","monitors":enrollmentRows,"audio_routes":["pg","benq","built-in"]]
    func enrollmentJSON(_ report:[String:Any])->String {String(decoding:try! JSONSerialization.data(withJSONObject:report),as:UTF8.self)}
    precondition(enrollmentReviewSummary(enrollmentJSON(enrollment),"B").contains("local input 18"))
    precondition(enrollmentReviewSummary(enrollmentJSON(enrollment),"A").contains("could not be validated"))
    for (key,value) in [("read_only",1 as Any),("monitors",[]),("host","unknown"),("audio_routes",["pg"])] {
        var invalid=enrollment;invalid[key]=value
        precondition(enrollmentReviewSummary(enrollmentJSON(invalid),"B").contains("could not be validated"))
    }
    var enrollmentCalls:[[String]]=[]
    let unsupportedReview=runCompatibleMenuCommand(["capture-review","--host","B"]){args,_,_ in
        enrollmentCalls.append(args);return CommandResult(output:"{}",code:0)
    }
    precondition(unsupportedReview.code==78 && enrollmentCalls==[["capabilities"]])
    precondition(safeWithoutControls("capture-review") && safeWithoutControls("enrollment-review"))

    let unknownInputs:[String:Any]=["updated_at":100.0,"status":"waiting-for-known-input","inputs":["pg":15,"benq":19]]
    let guidance=unknownInputGuidance(unknownInputs,105)!
    precondition(guidance.contains("PG42UQ reports input 15"))
    precondition(guidance.contains("Mac A = 17, Mac B = 18"))
    precondition(!guidance.contains("BenQ RD280UG reports"))
    precondition(unknownInputGuidance(unknownInputs,120)==nil)
    var recognized=unknownInputs;recognized["inputs"]=["pg":17,"benq":19]
    precondition(unknownInputGuidance(recognized,105)==nil)
    var unavailable=unknownInputs;unavailable["inputs"]=["pg":true,"benq":19]
    precondition(unknownInputGuidance(unavailable,105)!.contains("no valid input number"))

    let recentText=recentTimingSummary([["profile":"benq","result":"failed","seconds":["total":true]],["profile":"pg","result":"ready","seconds":["total":2.5]]])
    precondition(recentText.contains("1. Only BenQ here · Failed attempt"))
    precondition(recentText.contains("Application total: not recorded"))
    precondition(recentText.contains("2. Only PG here · Completed"))
    precondition(recentText.contains("Application total: 2.50 s"))
    precondition(recentTimingSummary([["profile":"pg","result":"ready","seconds":["observed_to_outcome":4.25]]]).contains("First observation to outcome: 4.25 s"))
    precondition(!recentTimingSummary([["profile":"pg","result":"ready","seconds":["observed_to_outcome":true]]]).contains("First observation to outcome: 1.00"))
    let interrupted=recentTimingSummary([["profile":"pg","result":"failed","seconds":["layout_apply":0.2],"failed_phase":"audio","failed_phase_seconds":2.0]])
    precondition(interrupted.contains("Interrupted during Audio after 2.00 s") && interrupted.contains("phase did not complete"))
    precondition(!recentTimingSummary([["profile":"pg","result":"failed","seconds":[:],"failed_phase":"private error","failed_phase_seconds":2.0]]).contains("private error"))
    precondition(recentTimingSummary(nil).contains("unavailable"))
    precondition(recentTimingSummary([]).contains("No recent"))

    let warning:[String:Any]=["name":"Rotation enrollment","status":"warning","detail":"Portrait is missing.","action":"Capture the missing orientation on this Mac."]
    let failure:[String:Any]=["name":"Configuration","status":"error","detail":"Configuration is invalid.","action":"Restore a known-good backup."]
    func healthJSON(_ fields:[String:Any])->String {String(decoding:try! JSONSerialization.data(withJSONObject:fields),as:UTF8.self)}
    let healthFields:[String:Any]=["read_only":true,"status":"error","checks":[warning,failure]]
    let parsedHealth=HealthReport(healthJSON(healthFields))!
    precondition(parsedHealth.nextStep.contains("Start with: Configuration"))
    precondition(parsedHealth.nextStep.contains("Errors: 1 · Warnings: 1"))
    precondition(parsedHealth.nextStep.contains("Restore a known-good backup."))
    precondition(setupSummary(healthJSON(healthFields)).contains("Not reported: Host enrollment"))
    for (key,value) in [("read_only",1 as Any),("status","ok"),("checks",[])] {
        var fields=healthFields;fields[key]=value;precondition(HealthReport(healthJSON(fields))==nil)
    }
    for key in ["name","status","detail"] {
        var row=failure;row.removeValue(forKey:key)
        precondition(HealthReport(healthJSON(["read_only":true,"status":"error","checks":[row]]))==nil)
    }
    let info:[String:Any]=["name":"Rotation enrollment","status":"info","detail":"Rotation disabled."]
    let informational=HealthReport(healthJSON(["read_only":true,"status":"ok","checks":[info]]))!
    precondition(informational.nextStep.contains("not physical setup qualification"))
    var noAction=failure;noAction.removeValue(forKey:"action")
    precondition(HealthReport(healthJSON(["read_only":true,"status":"error","checks":[noAction]]))!.nextStep.contains("Preserve current settings"))

    precondition(previewDurations([:])==[20])
    precondition(previewDurations(["preview_seconds":[40,20]])==[20,40])
    for invalid:Any in [[true,40],[20,60],[40],[20,20],"40"] {
        precondition(previewDurations(["preview_seconds":invalid])==[20])
    }
    precondition(previewRemaining(["updated_at":100.0,"preview":["state":"preview","remaining_seconds":40.0]],105)==35)

    let monitorArgs=["monitor-adjust","--monitor","pg","--feature","luminance","--step","5"]
    let validMonitor:[String:Any]=["monitor":"pg","feature":"luminance","before":25,"value":30,"maximum":100,"percent":30,"changed":true]
    func monitorResult(_ value:[String:Any],_ args:[String]?=nil,_ code:Int32=0)->MonitorResponse? {
        let data=try! JSONSerialization.data(withJSONObject:value)
        return MonitorResponse.decode(CommandResult(output:String(decoding:data,as:UTF8.self),code:code),arguments:args ?? monitorArgs)
    }
    precondition(monitorResult(validMonitor)?.role=="pg")
    precondition(monitorResult(validMonitor,nil,1)==nil)
    let percentArgs=["monitor-set","--monitor","pg","--feature","luminance","--percent","30"]
    precondition(monitorResult(validMonitor,percentArgs) != nil)
    precondition(monitorResult(validMonitor,Array(percentArgs.dropLast())+["31"])==nil)
    precondition(monitorResult(validMonitor,Array(percentArgs.dropLast(2)))==nil)
    var percentCalls:[[String]]=[]
    let unsupportedPercent=runCompatibleMenuCommand(percentArgs) { args,_,_ in
        percentCalls.append(args);return CommandResult(output:"{}",code:0)
    }
    precondition(unsupportedPercent.code==78 && percentCalls==[["capabilities"]])

    precondition(monitorResult(validMonitor,["brightness-apply","--monitor","pg"]) != nil)
    for field in ["monitor","feature","before","value","maximum","percent","changed"] {
        var missing=validMonitor;missing.removeValue(forKey:field)
        precondition(monitorResult(missing)==nil)
    }
    for (field,value) in [("monitor","benq" as Any),("feature","volume"),("value",true),("maximum",true),("percent",true),("before",false),("changed",1),("maximum",0),("maximum",65536),("value",101),("value",-1),("value",30.5),("before",101),("percent",31),("changed",false)] {
        var invalid=validMonitor;invalid[field]=value;precondition(monitorResult(invalid)==nil)
    }
    let setting:[String:Any]=["value":30,"maximum":100,"percent":30]
    let snapshot:[String:Any]=["monitor":"benq","read_only":true,"settings":["luminance":setting,"volume":setting]]
    let snapshotArgs=["monitor-settings","--monitor","benq"]
    precondition(monitorResult(snapshot,snapshotArgs)?.summary(at:Date()).contains("Brightness: 30%") == true)
    var readings=MonitorReadings()
    let readDate=Date(timeIntervalSince1970:1000)
    _=readings.accept(monitorResult(validMonitor)!,at:readDate)
    precondition(readings.previous(for:"pg")?.contains("PG42UQ")==true)
    precondition(readings.previous(for:"benq")==nil)
    let benqSummary=readings.accept(monitorResult(snapshot,snapshotArgs)!,at:readDate)
    precondition(benqSummary.contains("Read at "+readDate.formatted(date:.abbreviated,time:.standard)))
    precondition(readings.previous(for:"benq")?.contains("Previous reading (not refreshed):")==true)
    precondition(readings.previous(for:"benq")?.contains("PG42UQ")==false)
    precondition(readings.previous(for:"pg")?.contains("BenQ")==false)
    precondition(readings.previous(for:"unmanaged")==nil)
    for (field,value) in [("read_only",1 as Any),("settings",["luminance":setting]),("monitor","pg")] {
        var invalid=snapshot;invalid[field]=value;precondition(monitorResult(invalid,snapshotArgs)==nil)
    }
    for invalid in ["{broken","[]",String(repeating:" ",count:1_048_577)] {
        precondition(MonitorResponse.decode(CommandResult(output:invalid,code:0),arguments:monitorArgs)==nil)
    }
    precondition(monitorResult(validMonitor,monitorArgs+["--monitor","pg"])==nil)
    precondition(MonitorSetting(["value":1,"maximum":8,"percent":12]) != nil)
    precondition(MonitorSetting(["value":3,"maximum":8,"percent":38]) != nil)

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
    precondition(sections.map{$0.title}==["Overview","Recovery","PG42UQ","BenQ RD280UG","Audio"])
    precondition(sections[2].body=="Showing Mac A" && sections[3].body.contains("Showing Mac B"))
    precondition(statusSections([:],[:])[2].body.contains("Last known"))
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
    precondition(sizeComparison(["physical_size_percent":154.3],["physical_size_percent":98.5]).contains("PG about 98% of BenQ"))
    precondition(sizeComparison(["physical_size_percent":true],["physical_size_percent":Double.infinity]).contains("Current: unavailable"))
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
    precondition(setupSummary("{\"read_only\":true,\"checks\":[]}").contains("unavailable"))
    precondition(HealthReport("{\"status\":\"ok\",\"read_only\":true,\"checks\":[]}")==nil)
    precondition(safeWithoutControls("setup"))
    print("PASS setup readiness marks missing enrollment information unknown")
    precondition(panelShortcut("3",.command,false) == .tab("displays"))
    precondition(panelShortcut("R",[.command,.capsLock],false) == .refresh)
    for modifiers:NSEvent.ModifierFlags in [[],.control,[.command,.shift],[.command,.option]] {
        precondition(panelShortcut("1",modifiers,false)==nil)
    }
    precondition(panelShortcut("r",.command,true)==nil)
    precondition(panelShortcut("6",.command,false)==nil)
    for report in detailReportChoices where report.0 != "status" {
        precondition(panelRefreshArguments("details",report.0,"pg")==[report.0])
    }
    precondition(panelRefreshArguments("details","installation-status","pg")==["installation-status"])
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
    precondition(healthSummary("{\"status\":\"ok\",\"checks\":[]}").contains("could not be validated"))
    precondition(ddcSummary("invalid").contains("could not be read"))
    precondition(ddcSummary("{\"episodes\":[],\"ddc_interruptions\":0}").contains("No interruptions recorded"))
    let ddc=ddcSummary("{\"ddc_interruptions\":1,\"episodes\":[{\"started\":\"now\",\"monitor\":\"benq\",\"seconds\":1.25,\"recovered\":\"later\"}]}")
    precondition(ddc.contains("Read recovered · 1.25 s") && ddc.contains("benq"))
    var alerts=FailureAlerts()
    let broken:[String:Any]=["status":"degraded","profile":"pg","recovery":["reason":"audio"]]
    for state in ["degraded","state-error","preview-needs-repair"] {
        let body=failureNotificationBody(["status":state,"error":"PRIVATE-DEVICE-DETAIL","recovery":["error":"PRIVATE-PATH"]])!
        precondition(body.contains("Open Display Bridge") && body.count<200)
        precondition(!body.contains("PRIVATE"))
    }
    for state in ["ready","recovering","settling","waiting-for-ddc","unknown"] {
        precondition(failureNotificationBody(["status":state])==nil)
    }
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
func runPrivatePasteboardTest() {
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
func runNotificationTest() {
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
