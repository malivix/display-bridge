// SPDX-License-Identifier: MIT
import Foundation
import CoreFoundation

enum ShortcutFreshness:String,CaseIterable,Sendable {case fresh,stale,unavailable}
enum ShortcutControllerState:String,CaseIterable,Sendable {
    case ready,starting,settling,paused,recovering,degraded
    case waitingForInput="waiting-for-known-input",waitingForDDC="waiting-for-ddc"
    case inactiveSetup="inactive-setup",stateError="state-error"
    case previewPreparing="preview-preparing",preview="preview-preview"
    case previewRestorePending="preview-restore-pending",previewRestoreDeferred="preview-restore-deferred"
    case previewNeedsRepair="preview-needs-repair",previewError="preview-error"
    case previewRejected="preview-request-rejected",previewKept="preview-kept"
    case previewReverted="preview-reverted",previewIdle="preview-idle",unknown
}
enum ShortcutArrangement:String,CaseIterable,Sendable {case extended,pg,benq,away,unknown}
enum ShortcutPauseRequest:String,CaseIterable,Sendable {case paused,notPaused,unknown}
enum ShortcutRecovery:String,CaseIterable,Sendable {case pending,clear,unknown}

// Allowlisted observation only. This result never authorizes a hardware change.
struct ShortcutStatusSnapshot:Equatable {
    var freshness:ShortcutFreshness = .unavailable
    var controller:ShortcutControllerState = .unknown
    var arrangement:ShortcutArrangement = .unknown
    var pauseRequest:ShortcutPauseRequest = .unknown
    var recovery:ShortcutRecovery = .unknown
    var ageSeconds:Double?

    init(health:[String:Any]?,control:[String:Any]?,now:Double) {
        guard now.isFinite else {return}
        pauseRequest=Self.pauseRequest(control,now:now)
        guard let health,
              let updated=Self.number(health["updated_at"]),updated>=0,updated<=now,
              let rawState=health["status"] as? String else {return}
        guard let state=ShortcutControllerState(rawValue:rawState),state != .unknown else {return}
        let age=now-updated
        guard age.isFinite else {return}
        freshness=age<menuStatusFreshnessInterval ? .fresh:.stale
        ageSeconds=age
        controller=state
        arrangement=ShortcutArrangement(rawValue:health["profile"] as? String ?? "") ?? .unknown
        let recoveryState=health["recovery"] as? [String:Any]
        let pending=Self.boolean(recoveryState?["pending"])
        let journal=Self.boolean(health["audio_journal_pending"])
        if pending==true || journal==true {recovery = .pending}
        else if pending==false && journal==false {recovery = .clear}
    }

    static func read(root:URL,now:Double=Date().timeIntervalSince1970)->Self {
        Self(health:readMenuState(root.appendingPathComponent("health.json")),
             control:readMenuState(root.appendingPathComponent("control.json"),allowMissing:true),now:now)
    }

    private static func number(_ value:Any?)->Double? {
        guard let value=value as? NSNumber,CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite else {return nil}
        return value.doubleValue
    }
    private static func boolean(_ value:Any?)->Bool? {
        guard let value=value as? NSNumber,CFGetTypeID(value)==CFBooleanGetTypeID() else {return nil}
        return value.boolValue
    }
    private static func pauseRequest(_ control:[String:Any]?,now:Double)->ShortcutPauseRequest {
        guard let control else {return .unknown}
        let paused:Bool
        if let value=control["paused"] {
            guard let parsed=boolean(value) else {return .unknown};paused=parsed
        } else {paused=false}
        let until:Double
        if let value=control["pause_until"] {
            guard let parsed=number(value),parsed>=0 else {return .unknown};until=parsed
        } else {until=0}
        return paused && (until==0 || until>now) ? .paused:.notPaused
    }
}
