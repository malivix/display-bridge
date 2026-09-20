// SPDX-License-Identifier: MIT
import Foundation
import CoreFoundation

struct HealthFinding {
    let name:String
    let status:String
    let detail:String
    let action:String?
}

struct HealthReport {
    let status:String
    let findings:[HealthFinding]
    let limits:String
    init?(_ json:String) {
        guard json.utf8.count<=1_048_576,let data=json.data(using:.utf8),
              let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
              let readOnly=report["read_only"] as? NSNumber,CFGetTypeID(readOnly)==CFBooleanGetTypeID(),readOnly.boolValue,
              let status=report["status"] as? String,["ok","warning","error"].contains(status),
              let checks=report["checks"] as? [[String:Any]],!checks.isEmpty,checks.count<=128 else{return nil}
        var findings:[HealthFinding]=[]
        for check in checks {
            guard let name=check["name"] as? String,!name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
                  let state=check["status"] as? String,["ok","info","warning","error"].contains(state),
                  let detail=check["detail"] as? String,!detail.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return nil}
            if let action=check["action"],!(action is String) {return nil}
            findings.append(HealthFinding(name:name,status:state,detail:detail,action:check["action"] as? String))
        }
        let expected=findings.contains{$0.status=="error"} ? "error":findings.contains{$0.status=="warning"} ? "warning":"ok"
        guard status==expected else{return nil}
        self.status=status;self.findings=findings
        self.limits=report["limits"] as? String ?? "This is a software inspection. Physical behavior remains unverified. Nothing was changed."
    }
    var nextStep:String {
        let errors=findings.filter{$0.status=="error"},warnings=findings.filter{$0.status=="warning"}
        if let next=errors.first ?? warnings.first {
            let action=next.action?.trimmingCharacters(in:.whitespacesAndNewlines)
            let instruction=action.flatMap{$0.isEmpty ? nil:$0} ?? "Inspect this finding in the full checklist. Preserve current settings and recovery files."
            return "Needs attention · Errors: \(errors.count) · Warnings: \(warnings.count)\nStart with: \(next.name)\n\(next.detail)\nNext action: \(instruction)"
        }
        return "No errors or warnings reported. Review informational checks below; this is not physical setup qualification."
    }
    var summary:String {
        var lines=["Read-only check: \(status)"]
        for finding in findings {
            lines.append("\n\(finding.status.uppercased()) · \(finding.name)\n\(finding.detail)")
            if let action=finding.action,!action.isEmpty {lines.append(action)}
        }
        lines.append("\n"+limits)
        return lines.joined(separator:"\n")
    }
}
