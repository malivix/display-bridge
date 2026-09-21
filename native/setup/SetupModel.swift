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
    let rows=names.map{name in "\(checks.first{$0["name"] as? String==name}!["status"] as? String=="ok" ? "✓":"Needs attention:") \(name)"}
    return SetupReview(ready:ready,text:([ready ? "Software prerequisites passed":"Resolve these software prerequisites first"]+rows+["Hardware has not been inspected by this review. Installation independently checks the saved setup and current monitor state."]).joined(separator:"\n\n"))
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
    report["read_only"]=1;precondition(!setupReview(json(),host:"A").ready)
    report["read_only"]=true;report["checks"]=[["name":"Platform","status":"ok"]]
    precondition(!setupReview(json(),host:"A").ready)
    precondition(!setupReview("{}",host:"A").ready)
    print("PASS setup role changes, explicit readiness and typed prerequisite review")
}
