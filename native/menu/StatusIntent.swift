// SPDX-License-Identifier: MIT
import Foundation
import AppIntents

extension ShortcutFreshness:AppEnum {
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Observation freshness"
    static var caseDisplayRepresentations:[Self:DisplayRepresentation] = [
        .fresh:"Fresh",.stale:"Stale",.unavailable:"Unavailable"]
}
extension ShortcutControllerState:AppEnum {
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Reported controller state"
    static var caseDisplayRepresentations:[Self:DisplayRepresentation] = [
        .ready:"Ready",.starting:"Starting",.settling:"Settling",.paused:"Paused",
        .recovering:"Recovering",.degraded:"Degraded",.waitingForInput:"Waiting for known input",
        .waitingForDDC:"Waiting for monitor communication",.inactiveSetup:"Setup inactive",
        .stateError:"Saved state error",.previewPreparing:"Preparing size preview",.preview:"Size preview",
        .previewRestorePending:"Size restoration pending",.previewRestoreDeferred:"Size restoration deferred",
        .previewNeedsRepair:"Size restoration needs repair",.previewError:"Size preview error",
        .previewRejected:"Size preview request rejected",.previewKept:"Size kept",
        .previewReverted:"Size reverted",.previewIdle:"Size preview idle",.unknown:"Unknown"]
}
extension ShortcutArrangement:AppEnum {
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Reported monitor arrangement"
    static var caseDisplayRepresentations:[Self:DisplayRepresentation] = [
        .extended:"Both monitors here",.pg:"Only PG here",.benq:"Only BenQ here",
        .away:"Both monitors away",.unknown:"Unknown"]
}
extension ShortcutPauseRequest:AppEnum {
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Requested pause state"
    static var caseDisplayRepresentations:[Self:DisplayRepresentation] = [
        .paused:"Pause requested",.notPaused:"No active pause request",.unknown:"Unknown"]
}
extension ShortcutRecovery:AppEnum {
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Reported recovery state"
    static var caseDisplayRepresentations:[Self:DisplayRepresentation] = [
        .pending:"Pending",.clear:"None reported",.unknown:"Unknown"]
}

struct DisplayBridgeStatusResult:AppEntity {
    // Resolving this entity later deliberately obtains the latest observation.
    var id:String {"latest"}
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Display Bridge status"
    static var defaultQuery=DisplayBridgeStatusQuery()
    var displayRepresentation:DisplayRepresentation {
        switch freshness {
        case .fresh:return "Latest controller observation"
        case .stale:return "Stale controller observation"
        case .unavailable:return "Controller observation unavailable"
        }
    }
    @Property(title:"Observation freshness") var freshness:ShortcutFreshness
    @Property(title:"Reported controller state") var controller:ShortcutControllerState
    @Property(title:"Reported arrangement") var arrangement:ShortcutArrangement
    @Property(title:"Requested pause state") var pauseRequest:ShortcutPauseRequest
    @Property(title:"Reported recovery state") var recovery:ShortcutRecovery
    @Property(title:"Observation age in seconds") var ageSeconds:Double?

    init(snapshot:ShortcutStatusSnapshot) {
        freshness=snapshot.freshness;controller=snapshot.controller;arrangement=snapshot.arrangement
        pauseRequest=snapshot.pauseRequest;recovery=snapshot.recovery;ageSeconds=snapshot.ageSeconds
    }
    static func readLatest(
        root:URL=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/display-auto"),
        now:Double=Date().timeIntervalSince1970
    )->Self {
        // A signed demo can also be discovered by Shortcuts; it must not read real state.
        if menuDemoMode() {
            return Self(snapshot:ShortcutStatusSnapshot(health:nil,control:nil,now:now))
        }
        return Self(snapshot:ShortcutStatusSnapshot.read(root:root,now:now))
    }
}
struct DisplayBridgeStatusQuery:EntityQuery {
    func entities(for identifiers:[String]) async throws -> [DisplayBridgeStatusResult] {
        identifiers.contains("latest") ? [DisplayBridgeStatusResult.readLatest()]:[]
    }
}
struct GetDisplayBridgeStatus:AppIntent {
    static var title:LocalizedStringResource = "Get Display Bridge Status"
    static var description=IntentDescription("Read the latest local controller observation. Check freshness before using reported states. Does not inspect monitors or change settings.")
    static var openAppWhenRun:Bool = false
    func perform() async throws -> some IntentResult & ReturnsValue<DisplayBridgeStatusResult> {
        .result(value:DisplayBridgeStatusResult.readLatest())
    }
}
struct DisplayBridgeShortcuts:AppShortcutsProvider {
    static var appShortcuts:[AppShortcut] {
        AppShortcut(intent:GetDisplayBridgeStatus(),phrases:["Get status in \(.applicationName)"],
                    shortTitle:"Display status",systemImageName:"display")
    }
}
