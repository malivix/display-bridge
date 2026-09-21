// SPDX-License-Identifier: MIT
import Foundation
import CoreFoundation

func installationSummary(_ json:String,_ now:Double=Date().timeIntervalSince1970)->String {
    let unavailable="No valid installation report is available. Older installers may not have recorded one. Check system health and the installer command result; this report cannot establish an outcome."
    guard json.utf8.count<=1_048_576,let bytes=json.data(using:.utf8),
          let report=(try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any] else{return unavailable}
    func flag(_ key:String)->Bool? {
        guard let n=report[key] as? NSNumber,CFGetTypeID(n)==CFBooleanGetTypeID() else{return nil}
        return n.boolValue
    }
    func number(_ key:String)->Double? {
        guard let n=report[key] as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),n.doubleValue.isFinite else{return nil}
        return n.doubleValue
    }
    let phases=["preparing":"Preparing installation","building":"Building and testing helpers",
                "backing-up":"Backing up the prior installation","stopping-controller":"Stopping the prior controller",
                "activating":"Activating runtime files","checking-configuration":"Checking or capturing this Mac's configuration",
                "starting-controller":"Starting and checking the controller","installing-menu":"Installing and checking the menu app",
                "recovering":"Recovering the prior installation","recovery-finished":"Recovery commands finished","finished":"Installation checks finished"]
    guard flag("read_only")==true,flag("available")==true,number("schema")==1,
          let host=report["host"] as? String,["A","B"].contains(host),
          let status=report["status"] as? String,["running","completed","failed","incomplete"].contains(status),
          let phase=report["phase"] as? String,let phaseTitle=phases[phase],
          let recovery=report["recovery"] as? String,["not-needed","pending","completed-unverified"].contains(recovery),
          let start=number("started_at"),let updated=number("updated_at"),now.isFinite,
          start>=0,updated>=start,updated<=now,
          status != "completed" || (phase=="finished" && recovery=="not-needed") else{return unavailable}
    let labels=["running":"In progress when last recorded","completed":"Completed","failed":"Failed","incomplete":"Incomplete; final outcome unavailable"]
    let missingProcess=status=="running" && report["process_observation"] as? String == "not-found"
    let outcome=missingProcess ? "Outcome unknown · recorded process not found":"Reported outcome: \(labels[status]!)"
    var lines=["Mac \(host) · last installation",outcome,"Last phase: \(phaseTitle)",
               "Report age: \(Int(min(now-updated,31536000))) seconds"]
    if status=="running" {
        switch report["process_observation"] as? String {
        case "not-found":lines.append("The recorded process was not found. The installation outcome is unknown; it has not been marked successful.")
        case "present":lines.append("A process exists at the recorded PID. This alone does not verify its identity or that installation is progressing.")
        default:lines.append("The installer process could not be checked. Current progress is unknown.")
        }
    }
    switch recovery {
    case "completed-unverified":lines.append("Recovery commands completed. Verify controller health and the desktop before retrying; physical behavior is unverified.")
    case "pending":lines.append("Recovery completion is unconfirmed. Preserve backups and inspect health and the installer result before retrying.")
    default:lines.append("No rollback was reported as needed. This is not a separate check of the installed system.")
    }
    if status=="completed" {lines.append("The installer reported its controller/menu checks completed. Switching, rotation and audible sound still need physical checks.")}
    lines.append("Snapshot only. Refresh for a new reading. An attempt rejected before reporting began can leave an older record here. Nothing is installed, resumed or retried by this view.")
    return lines.joined(separator:"\n\n")
}

func demoInstallationReport(_ scenario:String,_ now:Double)->[String:Any] {
    var report:[String:Any]=["schema":1,"read_only":true,"available":true,"host":"A","status":"completed","phase":"finished","recovery":"not-needed","started_at":now-120,"updated_at":now-60]
    if scenario=="recovery" {report["status"]="failed";report["phase"]="recovering";report["recovery"]="pending"}
    if scenario=="recovery-wait" {report["status"]="running";report["phase"]="installing-menu";report["recovery"]="pending";report["process_observation"]="present"}
    if scenario=="stale" {report["status"]="running";report["phase"]="starting-controller";report["recovery"]="pending";report["process_observation"]="not-found"}
    return report
}
