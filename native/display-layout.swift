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
func runLayoutSelfTests() {
    func screen(_ key: String, _ w: Int, _ h: Int, rotation: Double = 0,
                x: Int = 0, y: Int = 0, mirrorOf: String? = nil,
                modeID: Int32? = 1, strictMode: Bool? = true) -> Screen {
        Screen(key: key, width: w, height: h, pixelWidth: w * 2, pixelHeight: h * 2,
               hz: 120, rotation: rotation, x: x, y: y, mirrorOf: mirrorOf,
               modeID: modeID, ioFlags: nil, strictMode: strictMode)
    }
    func expect(_ condition: Bool, _ name: String) {
        if !condition {
            FileHandle.standardError.write(Data("FAIL \(name)\n".utf8)); exit(1)
        }
    }
    let pg = screen("pg", 2048, 1152)
    let benq = screen("benq", 1280, 853, x: -1280)

    expect(mismatches(baseline: [pg, benq], live: [pg, benq]).isEmpty,
           "identical layouts match")
    expect(mismatches(baseline: [pg, benq], live: [pg]).map(\.key) == ["topology"],
           "a missing display is a topology mismatch")
    expect(mismatches(baseline: [pg], live: [pg, benq]).map(\.key) == ["topology"],
           "an extra display is a topology mismatch")

    let mirrored = screen("benq", 1280, 853, mirrorOf: "pg")
    expect(mismatches(baseline: [pg, mirrored], live: [pg, mirrored]).isEmpty,
           "a mirrored screen matches when it mirrors its master")
    expect(!mismatches(baseline: [pg, mirrored], live: [pg, benq]).isEmpty,
           "a mirrored screen does not match when it has its own desktop")
    expect(!mismatches(baseline: [pg, benq], live: [pg, mirrored]).isEmpty,
           "an unmirrored screen does not match when it is mirrored")

    let pgMirrorsBenq = screen("pg", 2048, 1152, mirrorOf: "benq")
    expect(!mismatches(baseline: [pg, mirrored], live: [pgMirrorsBenq, screen("benq", 1280, 853)]).isEmpty,
           "a reversed mirror direction is a mismatch")

    let rotated = screen("benq", 853, 1280, rotation: 90, x: -853)
    expect(!mismatches(baseline: [pg, benq], live: [pg, rotated]).isEmpty,
           "rotation is compared")
    let rotatedAlone = screen("benq", 1280, 853, rotation: 90, x: -1280)
    expect(!mismatches(baseline: [pg, benq], live: [pg, rotatedAlone]).isEmpty,
           "rotation alone is compared")
    let moved = screen("benq", 1280, 853, x: -999)
    expect(!mismatches(baseline: [pg, benq], live: [pg, moved]).isEmpty,
           "position is compared")

    let differentMode = screen("benq", 1280, 853, x: -1280, modeID: 2)
    expect(!mismatches(baseline: [pg, benq], live: [pg, differentMode]).isEmpty,
           "a different mode ID is a mismatch in strict mode")
    let differentModeLax = screen("benq", 1280, 853, x: -1280, modeID: 2, strictMode: nil)
    let benqLax = screen("benq", 1280, 853, x: -1280, strictMode: nil)
    expect(mismatches(baseline: [pg, benqLax], live: [pg, differentModeLax]).isEmpty,
           "a different mode ID is ignored when strict mode is off")

    let mirroredRotated = screen("benq", 853, 1280, rotation: 90, x: -853, mirrorOf: "pg")
    expect(mismatches(baseline: [pg, screen("benq", 1280, 853, mirrorOf: "pg")],
                      live: [pg, mirroredRotated]).isEmpty,
           "a mirrored screen ignores its own geometry and rotation")

    // A baseline may name a master, which must be another key in the same baseline.
    expect(unknownMasters(baseline: [pg, screen("benq", 1280, 853, mirrorOf: "pg")]).isEmpty,
           "a master present in the baseline is accepted")
    expect(unknownMasters(baseline: [pg, screen("benq", 1280, 853, mirrorOf: "absent")])
               == ["benq"],
           "a master absent from the baseline is rejected")
    expect(unknownMasters(baseline: [screen("a", 100, 100, mirrorOf: "b"),
                                     screen("b", 100, 100, mirrorOf: "a")]) == ["a", "b"],
           "a display may not mirror another mirror")

    // The usage string is the contract the controller depends on; it has no source argument.
    expect(!usage.contains("SOURCE_KEY") && usage.contains("apply BASELINE.json") &&
           usage.contains("check BASELINE.json"),
           "apply and check take a baseline and no source")

    print("PASS layout comparison: topology, mirroring, rotation, position")
}
struct Mismatch: Codable { let key: String; let reason: String }
struct CheckReport: Codable { let matches: Bool; let mismatches: [Mismatch] }
let usage = "Usage: display-layout status | modes | check BASELINE.json | apply BASELINE.json"

/// Does `live` already satisfy `baseline`? Pure: no CoreGraphics calls, so this is
/// testable without displays and is the only place layout equality is defined.
/// A screen naming `mirrorOf` is compared only on that relationship, because a
/// mirrored display adopts its master's mode, geometry and rotation.
func mismatches(baseline: [Screen], live: [Screen]) -> [Mismatch] {
    let now = Dictionary(uniqueKeysWithValues: live.map { ($0.key, $0) })
    guard Set(now.keys) == Set(baseline.map(\.key)) else {
        return [Mismatch(key: "topology", reason: "online set differs from the saved set")]
    }
    var found: [Mismatch] = []
    for saved in baseline {
        let live = now[saved.key]!
        if let master = saved.mirrorOf {
            if live.mirrorOf != master {
                found.append(Mismatch(key: saved.key, reason: "is not mirroring \(master)"))
            }
            continue
        }
        if live.mirrorOf != nil {
            found.append(Mismatch(key: saved.key, reason: "is mirrored but should not be"))
            continue
        }
        if saved.strictMode == true, let wanted = saved.modeID, live.modeID != wanted {
            found.append(Mismatch(key: saved.key, reason: "mode differs"))
        }
        if live.width != saved.width || live.height != saved.height ||
           live.pixelWidth != saved.pixelWidth || live.pixelHeight != saved.pixelHeight ||
           live.rotation != saved.rotation {
            found.append(Mismatch(key: saved.key, reason: "size or rotation differs"))
        }
        if let flags = saved.ioFlags, live.ioFlags != flags {
            found.append(Mismatch(key: saved.key, reason: "mode flags differ"))
        }
        if abs(live.hz - saved.hz) > 0.2 {
            found.append(Mismatch(key: saved.key, reason: "refresh differs"))
        }
        if live.x != saved.x || live.y != saved.y {
            found.append(Mismatch(key: saved.key, reason: "position differs"))
        }
    }
    return found
}

/// Keys whose `mirrorOf` does not name a non-mirrored screen in the same baseline.
/// A chain of mirrors has no meaning to CoreGraphics, so it is rejected as data.
func unknownMasters(baseline: [Screen]) -> [String] {
    let sources = Set(baseline.filter { $0.mirrorOf == nil }.map(\.key))
    return baseline.filter { screen in
        guard let master = screen.mirrorOf else { return false }
        return !sources.contains(master)
    }.map(\.key).sorted()
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
    try require(args.count == 3 && (args[1] == "apply" || args[1] == "check"), usage)
    let baseline = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
    let ids = try online()
    let keys = ids.map(key)
    try require(Set(keys).count == ids.count, "Ambiguous display identities; no changes applied")
    let live = try ids.map(screen)
    if args[1] == "check" {
        // Read-only: the same comparison apply uses, so no caller keeps its own copy.
        let found = mismatches(baseline: baseline.screens, live: live)
        let data = try JSONEncoder().encode(CheckReport(matches: found.isEmpty, mismatches: found))
        print(String(decoding: data, as: UTF8.self)); return
    }
    let byKey = Dictionary(uniqueKeysWithValues: zip(keys, ids))
    // Set equality pins the topology exactly; it is strictly as strong as also
    // hardcoding a count, and it does not assume how many displays are enrolled.
    try require(baseline.screens.count == Set(baseline.screens.map(\.key)).count &&
                Set(baseline.screens.map(\.key)) == Set(keys),
                "Display topology differs from the saved setup; no changes applied")
    try require(unknownMasters(baseline: baseline.screens).isEmpty,
                "Saved layout mirrors a display that is not a source in the same baseline; no changes applied")
    for saved in baseline.screens where saved.mirrorOf == nil {
        try require(saved.width > 0 && saved.height > 0 && saved.pixelWidth > 0 && saved.pixelHeight > 0 &&
                    saved.hz.isFinite && saved.hz >= 0 &&
                    Int32(exactly: saved.x) != nil && Int32(exactly: saved.y) != nil,
                    "Invalid saved layout; no changes applied")
        try require(CGDisplayRotation(byKey[saved.key]!) == saved.rotation,
                    "Rotation changed for \(saved.key); restore it and recapture; no changes applied")
    }
    if mismatches(baseline: baseline.screens, live: live).isEmpty {
        print("{\"changed\":false}"); return
    }
    // A mirrored screen adopts its master's mode, so only sources are mode-set.
    let sources = baseline.screens.filter { $0.mirrorOf == nil }
    // Preflight every requested mode BEFORE releasing the current mirror.
    let modes = try sources.map { try matchingMode(byKey[$0.key]!, $0) }
    let before = live
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
            for (saved, mode) in zip(sources, modes) {
                let id = byKey[saved.key]!
                try check(CGConfigureDisplayWithDisplayMode(config, id, mode, nil), "restore source mode")
                try check(CGConfigureDisplayOrigin(config, id, Int32(saved.x), Int32(saved.y)), "position display")
            }
            for saved in baseline.screens {
                guard let master = saved.mirrorOf else { continue }
                try check(CGConfigureDisplayMirrorOfDisplay(config, byKey[saved.key]!, byKey[master]!), "mirror")
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
    for _ in 0..<5 {
        if mismatches(baseline: baseline.screens, live: try ids.map(screen)).isEmpty {
            print("{\"changed\":true}"); return
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    let remaining = mismatches(baseline: baseline.screens, live: try ids.map(screen))
    throw Failure(description: "Layout readback differs: " +
                  remaining.map { "\($0.key) \($0.reason)" }.joined(separator: "; "))
}
if CommandLine.arguments.contains("--self-test") { runLayoutSelfTests(); exit(0) }
do { try run() }
catch {
    FileHandle.standardError.write(Data(("\(error)\n").utf8)); exit(1)
}
