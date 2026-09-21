// SPDX-License-Identifier: MIT
// Synthetic integration probe, deliberately excluded from the runtime source list.
import AppKit
import AppIntents

enum BridgeProbeState:String,AppEnum {
    case ready,stale,unavailable
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Status freshness"
    static var caseDisplayRepresentations:[Self:DisplayRepresentation] = [.ready:"Ready",.stale:"Stale",.unavailable:"Unavailable"]
}
struct BridgeProbeResult:AppEntity {
    var id:String = "synthetic"
    static var typeDisplayRepresentation:TypeDisplayRepresentation = "Synthetic bridge status"
    static var defaultQuery=BridgeProbeQuery()
    var displayRepresentation:DisplayRepresentation {"Synthetic status — no hardware read"}
    @Property(title:"State") var state:BridgeProbeState
    @Property(title:"Read only") var readOnly:Bool
    init() {self.state = .ready;self.readOnly = true}
}
struct BridgeProbeQuery:EntityQuery {
    func entities(for identifiers:[String]) async throws -> [BridgeProbeResult] {
        identifiers.contains("synthetic") ? [BridgeProbeResult()]:[]
    }
}
struct BridgeProbeStatus:AppIntent {
    static var title:LocalizedStringResource = "Read Synthetic Bridge Status"
    static var description=IntentDescription("Returns synthetic status for integration qualification. No monitor access.")
    static var openAppWhenRun:Bool = false
    func perform() async throws -> some IntentResult & ReturnsValue<BridgeProbeResult> {
        return .result(value:BridgeProbeResult())
    }
}
struct BridgeProbeShortcuts:AppShortcutsProvider {
    static var appShortcuts:[AppShortcut] {
        AppShortcut(intent:BridgeProbeStatus(),phrases:["Read status in \(.applicationName)"],shortTitle:"Read bridge status",systemImageName:"display")
    }
}
let app=NSApplication.shared
app.setActivationPolicy(.accessory)
if CommandLine.arguments.contains("--self-test") {
    Task {
        let result=try await BridgeProbeStatus().perform()
        precondition(result.value?.state == .ready && result.value?.readOnly == true)
        let unknown=try await BridgeProbeQuery().entities(for:["unknown"])
        precondition(unknown.isEmpty)
        print("PASS typed synthetic intent result and unknown entity lookup; no hardware accessed")
        exit(0)
    }
}
app.run()
