// SPDX-License-Identifier: MIT
import Foundation
import AppIntents

// These describe submission, never completion of controller reconciliation.
enum ShortcutControlOutcome:String,AppEnum,Sendable {
    case requestSaved,notSent,outcomeUnknown
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Automation request outcome"
    static var caseDisplayRepresentations:[Self:DisplayRepresentation] = [
        .requestSaved:DisplayRepresentation(title:"Request saved",subtitle:"The controller applies it after its current operation. Check status for progress."),
        .notSent:DisplayRepresentation(title:"Request not sent",subtitle:"Check controller support, demo mode and the 1–1440 minute pause limit."),
        .outcomeUnknown:DisplayRepresentation(title:"Outcome unknown",subtitle:"Check status before retrying. A timeout does not cancel accepted work.")]
}

enum ShortcutAutomationRequest:Sendable {
    case pause(minutes:Int),resume
    var arguments:[String]? {
        switch self {
        case .pause(let minutes):return (1...1440).contains(minutes) ? ["pause-for","--minutes",String(minutes)]:nil
        case .resume:return ["resume"]
        }
    }
}

func submitShortcutControl(_ request:ShortcutAutomationRequest,demo:Bool,
                           runner:([String],Double,Int)->CommandResult)->ShortcutControlOutcome {
    guard !demo,let arguments=request.arguments,let action=arguments.first else {return .notSent}
    guard menuCapabilities(runner(["capabilities"],5,16_384))?.contains(action)==true else {return .notSent}
    let result=runner(arguments,10,65_536)
    // No retry: the controller might have persisted the request before a failure.
    guard result.code==0,let data=result.output.data(using:.utf8),
          let response=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
          response["requested"] as? String == action,
          let identifier=response["request_id"] as? String,identifier.utf8.count==32,
          identifier.range(of:"^[a-f0-9]{32}$",options:.regularExpression) != nil,
          let control=response["control"] as? [String:Any],
          let saved=control["command_request"] as? [String:Any],
          saved["id"] as? String == identifier,saved["action"] as? String == action else {return .outcomeUnknown}
    return .requestSaved
}

private func executeShortcutControl(_ request:ShortcutAutomationRequest)->ShortcutControlOutcome {
    let command=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/display-auto.sh")
    return submitShortcutControl(request,demo:menuDemoMode()) {
        runMenuCommand(command,$0,timeout:$1,outputLimit:$2)
    }
}

struct PauseDisplayBridge:AppIntent {
    static var title:LocalizedStringResource = "Pause Display Bridge"
    static var description=IntentDescription("Request a timed automation pause for 1–1440 minutes. An operation already in progress can finish before the controller pauses.")
    static var openAppWhenRun:Bool = false
    @Parameter(title:"Minutes",default:30) var minutes:Int
    func perform() async throws -> some IntentResult & ReturnsValue<ShortcutControlOutcome> {
        let duration=minutes
        let outcome=await Task.detached {executeShortcutControl(.pause(minutes:duration))}.value
        return .result(value:outcome)
    }
}
struct ResumeDisplayBridge:AppIntent {
    static var title:LocalizedStringResource = "Resume Display Bridge"
    static var description=IntentDescription("Request resumption of automatic display and audio reconciliation. Enrollment and ownership checks still apply; a manual audio override remains preserved.")
    static var openAppWhenRun:Bool = false
    func perform() async throws -> some IntentResult & ReturnsValue<ShortcutControlOutcome> {
        let outcome=await Task.detached {executeShortcutControl(.resume)}.value
        return .result(value:outcome)
    }
}
