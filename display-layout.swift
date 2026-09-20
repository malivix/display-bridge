// SPDX-License-Identifier: MIT
// Local-only display configuration using public CoreGraphics APIs.
import Foundation
import CoreGraphics

struct Screen: Codable {
    let key: String
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let hz: Double
    let rotation: Double
    let x: Int
    let y: Int
    let mirrorOf: String?
    let modeID: Int32?
    let ioFlags: UInt32?
    let strictMode: Bool?
}
struct Layout: Codable { let screens: [Screen] }
struct ModeDescription: Codable {
    let modeID: Int32
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let hz: Double
    let ioFlags: UInt32
    let usableForDesktop: Bool
}
struct ModeInventory: Codable {
    let current: Screen
    let modes: [ModeDescription]
    let refreshCaveat: String
}
func inventory(_ id: CGDirectDisplayID) throws -> ModeInventory {
    let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
    let modes = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] ?? []
    return ModeInventory(current: try screen(id), modes: modes.map {
        ModeDescription(modeID: $0.ioDisplayModeID, width: $0.width, height: $0.height,
                        pixelWidth: $0.pixelWidth, pixelHeight: $0.pixelHeight,
                        hz: $0.refreshRate, ioFlags: $0.ioFlags,
                        usableForDesktop: $0.isUsableForDesktopGUI())
    }, refreshCaveat: "CoreGraphics refresh rate alone does not distinguish fixed refresh from VRR. Mode IDs are machine-local. HDR is not reported here.")
}
struct Failure: Error, CustomStringConvertible { let description: String }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw Failure(description: message) }
}
func check(_ result: CGError, _ operation: String) throws {
    try require(result == .success, "\(operation): CGError \(result.rawValue)")
}
func online() throws -> [CGDirectDisplayID] {
    var ids = [CGDirectDisplayID](repeating: 0, count: 32)
    var count: UInt32 = 0
    try check(CGGetOnlineDisplayList(32, &ids, &count), "list displays")
    return Array(ids.prefix(Int(count)))
}
func key(_ id: CGDirectDisplayID) -> String {
    "\(CGDisplayVendorNumber(id)):\(CGDisplayModelNumber(id)):\(CGDisplaySerialNumber(id))"
}
func screen(_ id: CGDirectDisplayID) throws -> Screen {
    guard let mode = CGDisplayCopyDisplayMode(id) else { throw Failure(description: "Missing display mode") }
    let bounds = CGDisplayBounds(id)
    let master = CGDisplayMirrorsDisplay(id)
    return Screen(key: key(id), width: mode.width, height: mode.height,
                  pixelWidth: mode.pixelWidth, pixelHeight: mode.pixelHeight,
                  hz: mode.refreshRate, rotation: CGDisplayRotation(id),
                  x: Int(bounds.origin.x), y: Int(bounds.origin.y),
                  mirrorOf: master == 0 ? nil : key(master),
                  modeID: mode.ioDisplayModeID, ioFlags: mode.ioFlags, strictMode:nil)
}
func transaction(_ body: (CGDisplayConfigRef) throws -> Void) throws {
    var reference: CGDisplayConfigRef?
    try check(CGBeginDisplayConfiguration(&reference), "begin display configuration")
    guard let config = reference else { throw Failure(description: "Missing configuration") }
    do { try body(config) }
    catch { CGCancelDisplayConfiguration(config); throw error }
    // Complete consumes the reference. Session scope survives helper exit,
    // while leaving the user's permanent login defaults alone.
    try check(CGCompleteDisplayConfiguration(config, .forSession), "complete display configuration")
}
func matchingMode(_ id: CGDirectDisplayID, _ saved: Screen) throws -> CGDisplayMode {
    let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
    let modes = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] ?? []
    func matches(_ mode: CGDisplayMode) -> Bool {
        mode.width == saved.width && mode.height == saved.height &&
        mode.pixelWidth == saved.pixelWidth && mode.pixelHeight == saved.pixelHeight &&
        abs(mode.refreshRate - saved.hz) < 0.2 && (saved.ioFlags == nil || saved.ioFlags == mode.ioFlags)
    }
    let candidates = modes.filter(matches)
    if let modeID = saved.modeID, let preferred = candidates.first(where: { $0.ioDisplayModeID == modeID }) { return preferred }
    try require(saved.strictMode != true, "Saved fixed-refresh mode unavailable for \(saved.key); reselect fixed 120 Hz and save a new baseline; no changes applied")
    if let current = CGDisplayCopyDisplayMode(id), matches(current) { return current }
    guard let selected = candidates.first else {
        throw Failure(description: "Saved mode unavailable for \(saved.key); no changes applied")
    }
    return selected
}
func run() throws {
    let args = CommandLine.arguments
    if args.count == 2 && args[1] == "status" {
        let data = try JSONEncoder().encode(Layout(screens: online().map(screen)))
        print(String(decoding: data, as: UTF8.self)); return
    }
    if args.count == 2 && args[1] == "modes" {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(online().map(inventory)), as: UTF8.self)); return
    }
    try require(args.count == 4 && args[1] == "apply", "Usage: display-layout status | modes | apply BASELINE.json extended|SOURCE_KEY")
    let baseline = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
    let ids = try online()
    let keys = ids.map(key)
    try require(Set(keys).count == ids.count, "Ambiguous display identities; no changes applied")
    let byKey = Dictionary(uniqueKeysWithValues: zip(keys, ids))
    try require(ids.count == 2 && baseline.screens.count == 2 && Set(baseline.screens.map(\.key)) == Set(keys),
                "Display topology differs from saved two-monitor setup; no changes applied")
    let source = args[3]
    try require(source == "extended" || byKey[source] != nil, "Unknown source; no changes applied")
    for saved in baseline.screens {
        try require(saved.width > 0 && saved.height > 0 && saved.pixelWidth > 0 && saved.pixelHeight > 0 &&
                    saved.hz.isFinite && saved.hz >= 0 && saved.mirrorOf == nil &&
                    Int32(exactly: saved.x) != nil && Int32(exactly: saved.y) != nil,
                    "Invalid saved layout; no changes applied")
        try require(CGDisplayRotation(byKey[saved.key]!) == saved.rotation,
                    "Rotation changed for \(saved.key); restore it and recapture; no changes applied")
    }
    let selected = baseline.screens.filter { source == "extended" || $0.key == source }
    // Preflight every requested mode BEFORE releasing the current mirror.
    let modes = try selected.map { try matchingMode(byKey[$0.key]!, $0) }
    let before = try ids.map(screen)
    let beforeModes = try ids.map { id -> CGDisplayMode in
        guard let mode = CGDisplayCopyDisplayMode(id) else { throw Failure(description: "Cannot snapshot current mode") }
        return mode
    }
    var releasedMirror = false
    do {
        let mirrors = ids.filter { CGDisplayMirrorsDisplay($0) != 0 }
        if !mirrors.isEmpty {
            try transaction { config in
                for id in mirrors { try check(CGConfigureDisplayMirrorOfDisplay(config, id, kCGNullDirectDisplay), "unmirror") }
            }
            releasedMirror = true
            Thread.sleep(forTimeInterval: 0.15)
        }
        try transaction { config in
            for (saved, mode) in zip(selected, modes) {
                let id = byKey[saved.key]!
                try check(CGConfigureDisplayWithDisplayMode(config, id, mode, nil), "restore source mode")
                try check(CGConfigureDisplayOrigin(config, id, source == "extended" ? Int32(saved.x) : 0,
                                                   source == "extended" ? Int32(saved.y) : 0), "position display")
            }
            if source != "extended" {
                for id in ids where id != byKey[source]! {
                    try check(CGConfigureDisplayMirrorOfDisplay(config, id, byKey[source]!), "mirror")
                }
            }
        }
    } catch {
        if releasedMirror {
            do {
                try transaction { config in
                    for (index, saved) in before.enumerated() where saved.mirrorOf == nil {
                        try check(CGConfigureDisplayWithDisplayMode(config, ids[index], beforeModes[index], nil), "rollback mode")
                        try check(CGConfigureDisplayOrigin(config, ids[index], Int32(saved.x), Int32(saved.y)), "rollback position")
                    }
                    for saved in before {
                        if let master = saved.mirrorOf, let masterID = byKey[master] {
                            try check(CGConfigureDisplayMirrorOfDisplay(config, byKey[saved.key]!, masterID), "rollback mirror")
                        }
                    }
                }
            } catch let rollbackError {
                throw Failure(description: "\(error); rollback also failed: \(rollbackError)")
            }
        }
        throw error
    }
}
do { try run() }
catch {
    FileHandle.standardError.write(Data(("\(error)\n").utf8)); exit(1)
}
