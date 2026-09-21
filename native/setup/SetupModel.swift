// SPDX-License-Identifier: MIT
import Foundation
import CoreFoundation

func setupArguments(_ script:URL,host:String,preflight:Bool)->[String] {
    // Keep Python import caches out of the signed source snapshot.
    ["-B",script.path,host]+(preflight ? ["--preflight"]:[])
}

struct SetupReview {
    let ready:Bool
    let text:String
}
func setupReview(_ json:String,host:String)->SetupReview {
    let unavailable=SetupReview(ready:false,text:"Software review could not be validated. Inspect the checkout and its installation guide before continuing.")
    guard ["A","B"].contains(host),json.utf8.count<=1_048_576,let bytes=json.data(using:.utf8),
          let report=(try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any],
          let readOnly=report["read_only"] as? NSNumber,CFGetTypeID(readOnly)==CFBooleanGetTypeID(),readOnly.boolValue,
          report["host"] as? String==host,let checks=report["checks"] as? [[String:Any]] else{return unavailable}
    let names=["Platform","macOS version","Python","Source files","Build tools","Service namespace"]
    guard checks.count==names.count,Set(checks.compactMap{$0["name"] as? String})==Set(names),
          checks.allSatisfy({["ok","error"].contains($0["status"] as? String ?? "")}) else{return unavailable}
    let ready=checks.allSatisfy{$0["status"] as? String=="ok"}
    guard report["status"] as? String==(ready ? "prerequisites-ready":"attention-required") else{return unavailable}
    // The validated check name is the reason code. Render local guidance, never
    // arbitrary subprocess detail (which may include private paths or raw errors).
    let remedies=[
        "Platform":"Run setup on an Apple-silicon Mac. This installer cannot run on Intel Macs or other operating systems.",
        "macOS version":"Use macOS 13 or newer on the supported Mac, then review software again.",
        "Python":"Use Python 3.10 or newer and rebuild this setup app with that interpreter. Reopening the same app retains its original Python location.",
        "Source files":"Rebuild this setup app from a complete, clean project checkout. Do not modify files inside the app bundle.",
        "Build tools":"Install or select Xcode Command Line Tools on this Mac, then review software again. The macOS SDK, Swift, Clang and make must be available.",
        "Service namespace":"Follow the service migration instructions in the installation guide to review older Display Bridge LaunchAgents. Preserve existing settings and backups; do not delete or stop services blindly."
    ]
    let failed=names.filter{name in checks.first{$0["name"] as? String==name}?["status"] as? String=="error"}
    let rows=failed.map{"Needs attention: \($0)\n\(remedies[$0]!)"}
        + names.filter{!failed.contains($0)}.map{"✓ \($0)"}
    return SetupReview(ready:ready,text:([ready ? "Software prerequisites passed":"Resolve these software prerequisites first"]+rows+["Hardware has not been inspected by this review. Installation independently checks the saved setup and current monitor state."]).joined(separator:"\n\n"))
}
// Correlate a report to the child owned by this window, not merely the last
// installer record on disk. A terminated child cannot imply ongoing progress.
func setupAttemptSummary(_ source:[String:Any],pid:Int32,host:String,launchedAt:Double,running:Bool,now:Double)->String? {
    func number(_ key:String)->Double? {
        guard let value=source[key] as? NSNumber,CFGetTypeID(value) != CFBooleanGetTypeID(),value.doubleValue.isFinite else{return nil}
        return value.doubleValue
    }
    guard pid>0,["A","B"].contains(host),launchedAt.isFinite,now.isFinite,
          number("pid")==Double(pid),source["host"] as? String==host,
          let start=number("started_at"),start>=launchedAt,start<=now else{return nil}
    var report=source
    report["read_only"]=true;report["available"]=true
    report["process_observation"]=running ? "present":"not-found"
    guard let bytes=try? JSONSerialization.data(withJSONObject:report),let json=String(data:bytes,encoding:.utf8) else{return nil}
    return installationSummary(json,now)
}

struct SetupSelection {
    var host:String?
    var reviewedHost:String?
    var prepared=false
    var installing=false
    var canInstall:Bool {host != nil && host==reviewedHost && prepared && !installing}
    mutating func select(_ role:String?) {host=["A","B"].contains(role ?? "") ? role:nil;reviewedHost=nil;prepared=false}
}
func runSetupTests() {
    let script=URL(fileURLWithPath:"/tmp/source with spaces/install.py")
    precondition(setupArguments(script,host:"A",preflight:true)==["-B",script.path,"A","--preflight"])
    precondition(setupArguments(script,host:"B",preflight:false)==["-B",script.path,"B"])
    var choice=SetupSelection();precondition(!choice.canInstall)
    choice.select("A");choice.reviewedHost="A";choice.prepared=true;precondition(choice.canInstall)
    choice.select("B");precondition(!choice.canInstall && !choice.prepared)
    choice.reviewedHost="B";choice.prepared=true;choice.installing=true;precondition(!choice.canInstall)
    let names=["Platform","macOS version","Python","Source files","Build tools","Service namespace"]
    var report:[String:Any]=["read_only":true,"host":"A","status":"prerequisites-ready","checks":names.map{["name":$0,"status":"ok"]}]
    func json()->String {String(decoding:try! JSONSerialization.data(withJSONObject:report),as:UTF8.self)}
    precondition(setupReview(json(),host:"A").ready && !setupReview(json(),host:"B").ready)
    for name in names {
        report["status"]="attention-required"
        report["checks"]=names.map{["name":$0,"status":$0==name ? "error":"ok","detail":"PRIVATE-UNTRUSTED-DETAIL"]}
        let result=setupReview(json(),host:"A")
        precondition(!result.ready && result.text.contains("Needs attention: \(name)\n"))
        precondition(!result.text.contains("PRIVATE-UNTRUSTED-DETAIL"))
        precondition(result.text.range(of:"Needs attention:")!.lowerBound < result.text.range(of:"✓")!.lowerBound)
    }
    report["status"]="prerequisites-ready" // Contradictory success cannot enable installation.
    precondition(!setupReview(json(),host:"A").ready)
    report["checks"]=names.map{["name":$0,"status":"ok"]}
    report["read_only"]=1;precondition(!setupReview(json(),host:"A").ready)
    report["read_only"]=true;report["checks"]=[["name":"Platform","status":"ok"]]
    precondition(!setupReview(json(),host:"A").ready)
    precondition(!setupReview("{}",host:"A").ready)
    let now=1000.0
    var attempt=demoInstallationReport("recovery-wait",now)
    attempt["pid"]=42;attempt["started_at"]=900.0
    func observed(_ running:Bool)->String? {setupAttemptSummary(attempt,pid:42,host:"A",launchedAt:899,running:running,now:now)}
    precondition(observed(true)?.contains("A process exists")==true)
    precondition(observed(false)?.contains("Outcome unknown · recorded process not found")==true)
    attempt["pid"]=43;precondition(observed(true)==nil)
    attempt["pid"]=true;precondition(observed(true)==nil)
    attempt["pid"]=42;attempt["started_at"]=898.0;precondition(observed(true)==nil)
    attempt["started_at"]=1001.0;precondition(observed(true)==nil)
    attempt["started_at"]=900.0;attempt["host"]="B";precondition(observed(true)==nil)
    print("PASS setup readiness, failure guidance and current-attempt correlation")
}
