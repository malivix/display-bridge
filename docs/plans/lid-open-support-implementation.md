# Lid-open support implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror the built-in display onto the landscape external while the laptop lid is open,
instead of letting any third display stop reconciliation.

**Architecture:** Stage A makes `mirrorOf` in the baseline the single description of layout
intent, moves the duplicated layout comparison out of Python into a pure Swift function, and
makes `display-layout apply` idempotent and self-verifying. Stage B enrolls the built-in panel
by identity through a separate installer step and appends one mirror row to the derived
baseline, so the lid needs no new saved baselines.

**Tech Stack:** Python 3.10+ standard library only, Swift 5 with CoreGraphics, `unittest`,
`swiftc` self-test binaries, `./scripts/test` and `./scripts/verify --native`.

**Spec:** `docs/plans/lid-open-support.md`

## Global Constraints

- Python 3.10+, standard library only. No new dependencies.
- Apple silicon, macOS 13+. Swift target `arm64-apple-macos13.0`.
- Conventional Commits: `type(scope): imperative summary`.
- Hardware mutations require saved display identities. Never mirror or mode-set a display
  whose key is not in the baseline.
- Unknown or failed reads defer changes. Preserve recovery journals and original configuration.
- Never weaken a check to make a run green.
- `./scripts/verify --native` must pass before each commit; `./scripts/public-check` runs on
  staged content via the pre-commit hook.
- Author commits as `Malivix <20479554+malivix@users.noreply.github.com>`.
- The derived baseline file keeps the name `rotation-active.json`. Do not rename it.
- Stage A is behavior-preserving. Any observable change in Stage A is a bug.

---

## Stage A: one source of truth for layout intent

### Task 1: Pure, testable layout comparison in Swift

The Swift apply path has no automated coverage today — `scripts/verify --native` only compiles
`display-layout.swift`. Build the safety net before changing behavior.

**Files:**
- Modify: `native/display-layout.swift` (add after `matchingMode`, ends line 99)
- Modify: `scripts/verify:51` (run the new self-test)

**Interfaces:**
- Produces: `struct Mismatch { let key: String; let reason: String }`,
  `func mismatches(baseline: [Screen], live: [Screen]) -> [Mismatch]`,
  `func runLayoutSelfTests()`. Task 2 and Task 3 consume `mismatches`.

- [ ] **Step 1: Write the failing self-test**

Add to `native/display-layout.swift`:

```swift
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

    let rotated = screen("benq", 853, 1280, rotation: 90, x: -853)
    expect(!mismatches(baseline: [pg, benq], live: [pg, rotated]).isEmpty,
           "rotation is compared")
    let moved = screen("benq", 1280, 853, x: -999)
    expect(!mismatches(baseline: [pg, benq], live: [pg, moved]).isEmpty,
           "position is compared")

    let mirroredRotated = screen("benq", 853, 1280, rotation: 90, x: -853, mirrorOf: "pg")
    expect(mismatches(baseline: [pg, screen("benq", 1280, 853, mirrorOf: "pg")],
                      live: [pg, mirroredRotated]).isEmpty,
           "a mirrored screen ignores its own geometry and rotation")

    print("PASS layout comparison: topology, mirroring, rotation, position")
}
```

Add the entry point immediately above `do { try run() }` at line 181:

```swift
if CommandLine.arguments.contains("--self-test") { runLayoutSelfTests(); exit(0) }
```

- [ ] **Step 2: Run it to verify it fails**

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -O native/display-layout.swift -o /tmp/dl-test
```

Expected: FAIL to compile, `cannot find 'mismatches' in scope`.

- [ ] **Step 3: Write the minimal implementation**

Add to `native/display-layout.swift` after `matchingMode` (line 99):

```swift
struct Mismatch { let key: String; let reason: String }

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
```

- [ ] **Step 4: Run it to verify it passes**

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -O native/display-layout.swift -o /tmp/dl-test
/tmp/dl-test --self-test
```

Expected: `PASS layout comparison: topology, mirroring, rotation, position`, exit 0.

- [ ] **Step 5: Wire it into verify**

In `scripts/verify`, change line 51 from:

```python
        run(str(build / "display-setup"), "--self-test")
```

to:

```python
        run(str(build / "display-layout"), "--self-test")
        run(str(build / "display-setup"), "--self-test")
```

- [ ] **Step 6: Run the full verification**

```bash
./scripts/verify --native
```

Expected: exit 0, including the new `PASS layout comparison` line.

- [ ] **Step 7: Commit**

```bash
git add native/display-layout.swift scripts/verify
git commit -m "test(layout): cover layout comparison with an isolated self-test"
```

---

### Task 2: Accept a mirror relationship in a saved baseline

**Files:**
- Modify: `native/display-layout.swift:117-127`

**Interfaces:**
- Consumes: `mismatches` from Task 1.
- Produces: `apply` accepts baselines whose screens declare `mirrorOf`; the topology guard is
  set equality with no hardcoded count.

- [ ] **Step 1: Write the failing self-test**

Append inside `runLayoutSelfTests`, immediately before its final `print`:

```swift
    // A baseline may name a master, which must be another key in the same baseline.
    expect(unknownMasters(baseline: [pg, screen("benq", 1280, 853, mirrorOf: "pg")]).isEmpty,
           "a master present in the baseline is accepted")
    expect(unknownMasters(baseline: [pg, screen("benq", 1280, 853, mirrorOf: "absent")])
               == ["benq"],
           "a master absent from the baseline is rejected")
    expect(unknownMasters(baseline: [screen("a", 100, 100, mirrorOf: "b"),
                                     screen("b", 100, 100, mirrorOf: "a")]) == ["a", "b"],
           "a display may not mirror another mirror")
```

- [ ] **Step 2: Run it to verify it fails**

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -O native/display-layout.swift -o /tmp/dl-test
```

Expected: FAIL to compile, `cannot find 'unknownMasters' in scope`.

- [ ] **Step 3: Write the minimal implementation**

Add after `mismatches` in `native/display-layout.swift`:

```swift
/// Keys whose `mirrorOf` does not name a non-mirrored screen in the same baseline.
/// A chain of mirrors has no meaning to CoreGraphics, so it is rejected as data.
func unknownMasters(baseline: [Screen]) -> [String] {
    let sources = Set(baseline.filter { $0.mirrorOf == nil }.map(\.key))
    return baseline.filter { screen in
        guard let master = screen.mirrorOf else { return false }
        return !sources.contains(master)
    }.map(\.key).sorted()
}
```

Replace lines 117-127 of `native/display-layout.swift`:

```swift
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
```

with:

```swift
    // Set equality pins the topology exactly; it is strictly as strong as also
    // hardcoding a count, and it does not assume how many displays are enrolled.
    try require(Set(baseline.screens.map(\.key)) == Set(keys),
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
```

- [ ] **Step 4: Run it to verify it passes**

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -O native/display-layout.swift -o /tmp/dl-test
/tmp/dl-test --self-test
```

Expected: PASS lines, exit 0. Compilation will still fail at `let source = args[3]` removal in
Task 3 only if you removed it here; leave `source` in place for now.

- [ ] **Step 5: Commit**

```bash
git add native/display-layout.swift
git commit -m "feat(layout): accept a mirror relationship declared in a saved baseline"
```

---

### Task 3: Make apply idempotent, self-verifying, and source-free

**Files:**
- Modify: `native/display-layout.swift:112-180`

**Interfaces:**
- Consumes: `mismatches`, `unknownMasters`.
- Produces: CLI `display-layout apply BASELINE.json` printing `{"changed":true|false}`.
  The third positional argument is gone. Task 4 consumes this contract.

- [ ] **Step 1: Write the failing self-test**

Append inside `runLayoutSelfTests`, before its final `print`:

```swift
    // The usage string is the contract Task 4 depends on; assert it has no source argument.
    expect(!applyUsage.contains("SOURCE_KEY") && applyUsage.contains("apply BASELINE.json"),
           "apply usage takes a baseline and no source")
```

- [ ] **Step 2: Run it to verify it fails**

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -O native/display-layout.swift -o /tmp/dl-test
```

Expected: FAIL to compile, `cannot find 'applyUsage' in scope`.

- [ ] **Step 3: Write the minimal implementation**

Add near `Mismatch`:

```swift
let applyUsage = "Usage: display-layout status | modes | apply BASELINE.json"
```

In `run()`, replace line 112:

```swift
    try require(args.count == 4 && args[1] == "apply", "Usage: display-layout status | modes | apply BASELINE.json extended|SOURCE_KEY")
```

with:

```swift
    try require(args.count == 3 && args[1] == "apply", applyUsage)
```

Delete `let source = args[3]` and its `require` (now handled in Task 2). Replace the
`selected` and mutation block (lines 129-157) with:

```swift
    let live = try ids.map(screen)
    if mismatches(baseline: baseline.screens, live: live).isEmpty {
        print("{\"changed\":false}"); return
    }
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
```

Keep the existing `catch` rollback body unchanged. After the closing brace of the
`do`/`catch`, before the end of `run()`, add the verification:

```swift
    for _ in 0..<5 {
        let after = try ids.map(screen)
        if mismatches(baseline: baseline.screens, live: after).isEmpty {
            print("{\"changed\":true}"); return
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    let remaining = mismatches(baseline: baseline.screens, live: try ids.map(screen))
    throw Failure(description: "Layout readback differs: " +
                  remaining.map { "\($0.key) \($0.reason)" }.joined(separator: "; "))
```

- [ ] **Step 4: Run it to verify it passes**

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -O native/display-layout.swift -o /tmp/dl-test
/tmp/dl-test --self-test
/tmp/dl-test apply
```

Expected: self-test PASS, exit 0. Bare `apply` prints the usage string and exits 1.

- [ ] **Step 5: Verify the no-change path against real hardware, read-only**

```bash
/tmp/dl-test status > /tmp/live.json
python3 -c "
import json; d=json.load(open('/tmp/live.json'))
json.dump({'screens':[dict(s, strictMode=True) for s in d['screens']]}, open('/tmp/bl.json','w'))
"
/tmp/dl-test apply /tmp/bl.json
```

Expected: `{"changed":false}` and no visible display change, because the baseline was built
from the live layout. If it prints `changed:true` or alters the desktop, stop — the comparison
disagrees with what apply produces, and that is the whole risk of this task.

- [ ] **Step 6: Commit**

```bash
git add native/display-layout.swift
git commit -m "refactor(layout)!: describe intent in the baseline and verify apply in place"
```

---

### Task 4: Derive the baseline in Python and delete the duplicated comparison

**Files:**
- Modify: `display-auto.py:196-232` (delete `matches`, rewrite `apply`)
- Modify: `display-auto.py:283-291` (`select_rotation_baseline` becomes the derive step)
- Test: `tests/unit/test_controller.py`

**Interfaces:**
- Consumes: `display-layout apply BASELINE.json` printing `{"changed":bool}` from Task 3.
- Produces: `derive_baseline(config, profile) -> dict` returning `{'screens': [...]}` with
  `mirrorOf` set per profile. Task 9 extends it with the lid row.

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_controller.py` inside `ReliabilityTests`:

```python
    def test_derive_baseline_describes_mirroring_per_profile(self):
        saved = {'screens': [
            {'key': 'PG', 'width': 2048, 'height': 1152, 'x': 0, 'y': 0, 'rotation': 0,
             'pixelWidth': 4096, 'pixelHeight': 2304, 'hz': 120, 'modeID': 1, 'strictMode': True},
            {'key': 'BQ', 'width': 1280, 'height': 853, 'x': -1280, 'y': 0, 'rotation': 0,
             'pixelWidth': 2560, 'pixelHeight': 1706, 'hz': 120, 'modeID': 2, 'strictMode': True}]}
        config = {'keys': {'pg': 'PG', 'benq': 'BQ'}, 'baseline': saved}

        extended = {s['key']: s for s in c.derive_baseline(config, 'extended')['screens']}
        self.assertIsNone(extended['PG'].get('mirrorOf'))
        self.assertIsNone(extended['BQ'].get('mirrorOf'))
        self.assertEqual((extended['BQ']['x'], extended['BQ']['y']), (-1280, 0))

        pg = {s['key']: s for s in c.derive_baseline(config, 'pg')['screens']}
        self.assertEqual(pg['BQ']['mirrorOf'], 'PG')
        # The surviving source moves to the origin, as the native helper used to do itself.
        self.assertEqual((pg['PG']['x'], pg['PG']['y']), (0, 0))
        self.assertIsNone(pg['PG'].get('mirrorOf'))

        benq = {s['key']: s for s in c.derive_baseline(config, 'benq')['screens']}
        self.assertEqual(benq['PG']['mirrorOf'], 'BQ')
        self.assertEqual((benq['BQ']['x'], benq['BQ']['y']), (0, 0))

    def test_derive_baseline_leaves_a_mirrored_screen_without_a_mode(self):
        saved = {'screens': [
            {'key': 'PG', 'width': 2048, 'height': 1152, 'x': 0, 'y': 0, 'rotation': 0,
             'pixelWidth': 4096, 'pixelHeight': 2304, 'hz': 120, 'modeID': 1, 'strictMode': True},
            {'key': 'BQ', 'width': 1280, 'height': 853, 'x': -1280, 'y': 0, 'rotation': 90,
             'pixelWidth': 2560, 'pixelHeight': 1706, 'hz': 120, 'modeID': 2, 'strictMode': True}]}
        config = {'keys': {'pg': 'PG', 'benq': 'BQ'}, 'baseline': saved}
        mirrored = next(s for s in c.derive_baseline(config, 'pg')['screens'] if s['key'] == 'BQ')
        self.assertEqual(mirrored, {'key': 'BQ', 'mirrorOf': 'PG'})
```

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 -m unittest tests.unit.test_controller -k derive_baseline -v
```

Expected: FAIL, `module 'controller' has no attribute 'derive_baseline'`.

- [ ] **Step 3: Write the minimal implementation**

Replace `matches` (lines 196-220) with:

```python
def derive_baseline(config, profile):
    """The layout intent for a profile, as a baseline the native helper can apply.

    A screen keeps its saved mode when it shows its own desktop. A screen that should
    mirror carries only its key and master, because a mirrored display adopts its
    master's mode, geometry and rotation. This is the only description of intent;
    the native helper owns the comparison against the live layout.
    """
    keys = config['keys']
    source = keys.get(profile)
    screens = []
    for saved in config['baseline']['screens']:
        if source is None or saved['key'] == source:
            screens.append(dict(saved, x=saved['x'] if source is None else 0,
                                y=saved['y'] if source is None else 0))
        else:
            screens.append({'key': saved['key'], 'mirrorOf': source})
    return {'screens': screens}
```

Replace `apply` (lines 222-232) with:

```python
def apply(config, profile, deadline=None):
    if profile in ('away', 'unknown'):
        return False
    path = write_active_baseline(config, derive_baseline(config, profile))
    result = command([HELPER, 'apply', str(path)], 8, deadline)
    return json.loads(result).get('changed', False)
```

Replace `select_rotation_baseline` (lines 283-291) with a rotation selector plus a shared
writer:

```python
def write_active_baseline(config, baseline):
    path = ROOT / 'rotation-active.json'
    # Historical name: this file now carries every derived intent, not only rotation.
    # It is referenced by name in the preview snapshot and restore payloads.
    encoded = json.dumps(baseline) + '\n'
    if not path.exists() or path.read_text() != encoded:
        temporary = path.with_suffix('.tmp')
        temporary.write_text(encoded)
        temporary.replace(path)
    config['active_baseline_path'] = path
    return path

def select_rotation_baseline(config, angle):
    try:
        saved = rotation_baseline(config, angle)
    except ValueError as error:
        raise RuntimeError(str(error)) from error
    config['baseline'] = saved
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
python3 -m unittest tests.unit.test_controller -k derive_baseline -v
./scripts/test
```

Expected: the two new tests PASS. `./scripts/test` may report failures in tests that patched
or asserted on `matches`; fix those by asserting on `derive_baseline` output instead. Do not
delete a test to make the run green.

- [ ] **Step 5: Run the full verification**

```bash
./scripts/verify --native
```

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add display-auto.py tests/unit/test_controller.py
git commit -m "refactor(controller): derive layout intent and drop the duplicated comparison"
```

---

### Task 5: Prove Stage A on real hardware

Stage A is behavior-preserving, so the gate is the installer's own physical sweep.

**Files:** none modified.

- [ ] **Step 1: Confirm the preconditions**

```bash
~/.local/bin/display-auto.sh status | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['status'], d.get('profile'), d.get('inputs'))"
```

Expected: `ready extended {'pg': 18, 'benq': 15}`. If it reports `inactive-setup`, close the
laptop lid and re-check; Stage A does not add lid support.

- [ ] **Step 2: Install from the checkout**

```bash
python3 install.py B
```

Expected: exit 0, and four `PASS layout=` lines for `pg`, `extended`, `benq`, `extended` — the
sweep that exercises every mirroring path through the new contract.

- [ ] **Step 3: Confirm health**

```bash
~/.local/bin/display-auto.sh doctor | python3 -c "
import json,sys; d=json.load(sys.stdin)
print('overall:', d['status'])
print('non-ok:', [(c['name'], c['status']) for c in d['checks'] if c['status'] != 'ok'])
"
```

Expected: `overall: ok`, and `non-ok` empty or containing only `Rotation enrollment` as `info`.

- [ ] **Step 4: Confirm idempotence produced no churn**

```bash
grep -c "Layout readback differs" ~/Library/Logs/display-auto-v2.log
```

Expected: `0`. Any occurrence means the Swift comparison and the Swift mutation disagree; stop
and investigate before Stage B.

- [ ] **Step 5: Record the outcome**

Create `docs/log/layout-intent-unification.md` describing what changed, that it is
behavior-preserving, the self-test added, and the physical sweep result. State that the lid is
not yet supported.

- [ ] **Step 6: Commit**

```bash
git add docs/log/layout-intent-unification.md CHANGELOG.md
git commit -m "docs(log): record the layout intent unification and its physical sweep"
```

---

## Stage B: enroll and mirror the lid

### Task 6: Report whether a display is the built-in panel

**Files:**
- Modify: `native/display-layout.swift` (`Screen`, `screen(_:)`)

**Interfaces:**
- Produces: `Screen.builtin: Bool?`, present in `display-layout status` output. Tasks 7 and 9
  consume it.

- [ ] **Step 1: Write the failing test**

Append inside `runLayoutSelfTests`, before its final `print`:

```swift
    // builtin is reported, and never participates in layout equality.
    let lid = Screen(key: "lid", width: 1280, height: 853, pixelWidth: 2560, pixelHeight: 1706,
                     hz: 120, rotation: 0, x: 0, y: 0, mirrorOf: "pg", modeID: 3,
                     ioFlags: nil, strictMode: true, builtin: true)
    expect(mismatches(baseline: [pg, screen("lid", 1280, 853, mirrorOf: "pg")],
                      live: [pg, lid]).isEmpty,
           "builtin does not affect layout equality")
```

- [ ] **Step 2: Run it to verify it fails**

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -O native/display-layout.swift -o /tmp/dl-test
```

Expected: FAIL to compile, `extra argument 'builtin' in call`.

- [ ] **Step 3: Write the minimal implementation**

Add to `struct Screen` after `strictMode`:

```swift
    let builtin: Bool?
```

Add `builtin: true/false` to the `screen(_:)` factory at line 67, using
`CGDisplayIsBuiltin(id) != 0`. Add `builtin: nil` to the `screen` helper default inside
`runLayoutSelfTests` so existing assertions keep compiling.

- [ ] **Step 4: Run it to verify it passes**

```bash
swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target arm64-apple-macos13.0 -O native/display-layout.swift -o /tmp/dl-test
/tmp/dl-test --self-test && /tmp/dl-test status | python3 -c "
import json,sys
for s in json.load(sys.stdin)['screens']: print(s['key'], 'builtin=', s.get('builtin'))
"
```

Expected: self-test PASS, and exactly one display reporting `builtin= True` when the lid is
open, none when it is closed.

- [ ] **Step 5: Commit**

```bash
git add native/display-layout.swift
git commit -m "feat(layout): report whether a display is the built-in panel"
```

---

### Task 7: Enroll the built-in by identity

**Files:**
- Modify: `install.py` (argument group at line 116, capture branch)
- Test: `tests/unit/test_installer.py`

**Interfaces:**
- Consumes: `Screen.builtin` from Task 6.
- Produces: `install.py <host> --capture-lid` writing `config['keys']['builtin']`, and
  `builtin_key(screens) -> str` raising on anything that is not exactly one built-in display.

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_installer.py` inside `InstallerEntryTests`:

```python
    def test_builtin_key_requires_exactly_one_built_in_display(self):
        module = self.load()
        screens = [{'key': 'PG', 'builtin': False}, {'key': 'LID', 'builtin': True}]
        self.assertEqual(module.builtin_key(screens), 'LID')
        with self.assertRaisesRegex(RuntimeError, 'built-in'):
            module.builtin_key([{'key': 'PG', 'builtin': False}])
        with self.assertRaisesRegex(RuntimeError, 'built-in'):
            module.builtin_key([{'key': 'A', 'builtin': True}, {'key': 'B', 'builtin': True}])
        # Absent metadata is not an assertion that a display is internal.
        with self.assertRaisesRegex(RuntimeError, 'built-in'):
            module.builtin_key([{'key': 'PG'}, {'key': 'LID'}])
```

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 -m unittest tests.unit.test_installer -k builtin_key -v
```

Expected: FAIL, `module 'installer' has no attribute 'builtin_key'`.

- [ ] **Step 3: Write the minimal implementation**

Add to `install.py` beside `interpreter_path`:

```python
def builtin_key(screens):
    """The identity of the internal panel, refusing to guess.

    Enrolling the wrong display would mirror a projector or a meeting-room screen,
    so only CoreGraphics' own answer counts and it must be unambiguous.
    """
    found = [s['key'] for s in screens if s.get('builtin') is True]
    if len(found) != 1:
        raise RuntimeError(
            'Open the laptop lid and retry; exactly one built-in display must be online'
        )
    return found[0]
```

Add `--capture-lid` to the mutually exclusive capture group at line 116:

```python
    capture.add_argument("--capture-lid", action="store_true")
```

In the capture branch, add a path that records only the key. It must not run the
exactly-two-displays check, because the lid must be open:

```python
                if args.capture_lid:
                    screens = json.loads(run([str(bin_dir / "display-layout"), "status"],
                                             capture_output=True, text=True,
                                             check=True).stdout)["screens"]
                    key = builtin_key(screens)
                    if key in previous["keys"].values():
                        raise RuntimeError("The built-in display is already enrolled as an external")
                    previous["keys"]["builtin"] = key
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
python3 -m unittest tests.unit.test_installer -k builtin_key -v
./scripts/test
```

Expected: PASS, and the full suite green.

- [ ] **Step 5: Commit**

```bash
git add install.py tests/unit/test_installer.py
git commit -m "feat(install): enroll the built-in display by identity"
```

---

### Task 8: Accept the lid in saved configuration

**Files:**
- Modify: `display-auto.py:456-459` (`validate_config`)
- Test: `tests/unit/test_controller.py`

**Interfaces:**
- Produces: `validate_config` accepting `keys` of `{pg,benq}` or `{pg,benq,builtin}`.

- [ ] **Step 1: Write the failing test**

```python
    def test_validate_config_accepts_an_optional_builtin_key(self):
        def config(keys):
            return {'version': c.VERSION, 'host': 'B', 'poll_interval': .25, 'keys': keys,
                    'baseline': {'screens': [{'key': 'PG'}, {'key': 'BQ'}]}}
        c.validate_config(config({'pg': 'PG', 'benq': 'BQ'}))
        c.validate_config(config({'pg': 'PG', 'benq': 'BQ', 'builtin': 'LID'}))
        with self.assertRaisesRegex(RuntimeError, 'configuration'):
            c.validate_config(config({'pg': 'PG', 'benq': 'BQ', 'builtin': 'PG'}))
        with self.assertRaisesRegex(RuntimeError, 'configuration'):
            c.validate_config(config({'pg': 'PG'}))
```

Wrap each `validate_config` call with `patch.object(c, 'BASELINE', <a path holding the same
baseline JSON>)` following the pattern in `test_mismatched_baseline_is_rejected`.

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 -m unittest tests.unit.test_controller -k optional_builtin -v
```

Expected: FAIL on the `builtin` case, `Invalid two-display configuration`.

- [ ] **Step 3: Write the minimal implementation**

Replace lines 456-459:

```python
    if len(screens) != 2 or set(keys) != {'pg','benq'} or len(set(keys.values())) != 2:
        raise RuntimeError('Invalid two-display configuration')
    if set(x.get('key') for x in screens) != set(keys.values()):
        raise RuntimeError('Display keys differ from baseline')
```

with:

```python
    if len(screens) != 2 or set(keys) not in ({'pg','benq'}, {'pg','benq','builtin'}):
        raise RuntimeError('Invalid display configuration')
    if len(set(keys.values())) != len(keys):
        raise RuntimeError('Invalid display configuration: enrolled keys are not distinct')
    if set(x.get('key') for x in screens) != {keys['pg'], keys['benq']}:
        raise RuntimeError('Display keys differ from baseline')
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
python3 -m unittest tests.unit.test_controller -k optional_builtin -v && ./scripts/test
```

Expected: PASS, suite green.

- [ ] **Step 5: Commit**

```bash
git add display-auto.py tests/unit/test_controller.py
git commit -m "feat(controller): accept an enrolled built-in display in configuration"
```

---

### Task 9: Mirror the lid onto the landscape external

**Files:**
- Modify: `display-auto.py` (`derive_baseline`, and the topology guard that reports
  `inactive-setup`)
- Test: `tests/unit/test_controller.py`

**Interfaces:**
- Consumes: `derive_baseline` from Task 4, `Screen.builtin` from Task 6.
- Produces: `derive_baseline(config, profile, lid_online=False)`.

- [ ] **Step 1: Write the failing test**

```python
    def test_lid_mirrors_the_pg_and_falls_back_to_the_benq(self):
        saved = {'screens': [
            {'key': 'PG', 'width': 2048, 'height': 1152, 'x': 0, 'y': 0, 'rotation': 0,
             'pixelWidth': 4096, 'pixelHeight': 2304, 'hz': 120, 'modeID': 1, 'strictMode': True},
            {'key': 'BQ', 'width': 853, 'height': 1280, 'x': -853, 'y': 0, 'rotation': 90,
             'pixelWidth': 1706, 'pixelHeight': 2560, 'hz': 120, 'modeID': 2, 'strictMode': True}]}
        config = {'keys': {'pg': 'PG', 'benq': 'BQ', 'builtin': 'LID'}, 'baseline': saved}

        def lid(profile):
            rows = {s['key']: s for s in
                    c.derive_baseline(config, profile, lid_online=True)['screens']}
            return rows.get('LID')

        # The PG never rotates, so it is the target whenever it is present.
        self.assertEqual(lid('extended'), {'key': 'LID', 'mirrorOf': 'PG'})
        self.assertEqual(lid('pg'), {'key': 'LID', 'mirrorOf': 'PG'})
        # Only when the PG is away does the BenQ become the target.
        self.assertEqual(lid('benq'), {'key': 'LID', 'mirrorOf': 'BQ'})
        # A closed lid contributes no row at all.
        self.assertNotIn('LID', {s['key'] for s in
                                 c.derive_baseline(config, 'extended')['screens']})

    def test_lid_is_not_mirrored_when_it_is_not_enrolled(self):
        saved = {'screens': [
            {'key': 'PG', 'width': 2048, 'height': 1152, 'x': 0, 'y': 0, 'rotation': 0,
             'pixelWidth': 4096, 'pixelHeight': 2304, 'hz': 120, 'modeID': 1, 'strictMode': True},
            {'key': 'BQ', 'width': 1280, 'height': 853, 'x': -1280, 'y': 0, 'rotation': 0,
             'pixelWidth': 2560, 'pixelHeight': 1706, 'hz': 120, 'modeID': 2, 'strictMode': True}]}
        config = {'keys': {'pg': 'PG', 'benq': 'BQ'}, 'baseline': saved}
        rows = c.derive_baseline(config, 'extended', lid_online=True)['screens']
        self.assertEqual({s['key'] for s in rows}, {'PG', 'BQ'})
```

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 -m unittest tests.unit.test_controller -k lid -v
```

Expected: FAIL, `derive_baseline() got an unexpected keyword argument 'lid_online'`.

- [ ] **Step 3: Write the minimal implementation**

Change `derive_baseline`'s signature and append the lid row before returning:

```python
def derive_baseline(config, profile, lid_online=False):
    keys = config['keys']
    source = keys.get(profile)
    screens = []
    for saved in config['baseline']['screens']:
        if source is None or saved['key'] == source:
            screens.append(dict(saved, x=saved['x'] if source is None else 0,
                                y=saved['y'] if source is None else 0))
        else:
            screens.append({'key': saved['key'], 'mirrorOf': source})
    builtin = keys.get('builtin')
    if lid_online and builtin:
        # The PG never rotates, so it is the target whenever it shows this Mac; the
        # BenQ is the target only when the PG is away.
        target = keys['pg'] if profile in ('extended', 'pg') else keys['benq']
        screens.append({'key': builtin, 'mirrorOf': target})
    return {'screens': screens}
```

Pass `lid_online` from `apply`, computed from the live layout:

```python
def apply(config, profile, deadline=None):
    if profile in ('away', 'unknown'):
        return False
    builtin = config['keys'].get('builtin')
    lid_online = bool(builtin) and any(
        s['key'] == builtin for s in layout(deadline))
    path = write_active_baseline(config, derive_baseline(config, profile, lid_online))
    result = command([HELPER, 'apply', str(path)], 8, deadline)
    return json.loads(result).get('changed', False)
```

Relax the topology guard that produces `inactive-setup` so the enrolled pair plus the
enrolled built-in is an accepted set, while any other extra display still idles. Locate it via:

```bash
grep -n "is not the active two-monitor setup" display-auto.py
```

and widen its accepted key set to include `keys['builtin']` when the built-in is online.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
python3 -m unittest tests.unit.test_controller -k lid -v && ./scripts/test && ./scripts/verify --native
```

Expected: PASS, suite green, verify exit 0.

- [ ] **Step 5: Commit**

```bash
git add display-auto.py tests/unit/test_controller.py
git commit -m "feat(controller): mirror the enrolled built-in onto the landscape external"
```

---

### Task 10: Report lid enrollment in doctor

**Files:**
- Modify: `health_check.py`
- Test: `tests/unit/test_health_check.py`

**Interfaces:**
- Produces: a `Lid enrollment` check, `ok` when enrolled, `info` when not.

- [ ] **Step 1: Write the failing test**

```python
    def test_doctor_reports_lid_enrollment(self):
        enrolled = lid_check({'pg': 'PG', 'benq': 'BQ', 'builtin': 'LID'})
        self.assertEqual(enrolled['status'], 'ok')
        absent = lid_check({'pg': 'PG', 'benq': 'BQ'})
        self.assertEqual(absent['status'], 'info')
        self.assertIn('--capture-lid', absent['action'])
```

Bind `lid_check` to the new function following the import style already used at the top of
`tests/unit/test_health_check.py`.

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 -m unittest tests.unit.test_health_check -k lid -v
```

Expected: FAIL, the function does not exist.

- [ ] **Step 3: Write the minimal implementation**

Add a check returning `ok` with the enrolled state, or `info` with
`detail` explaining the lid is not enrolled and `action` naming
`python3 install.py <host> --capture-lid`, run with the lid open. Register it beside the
existing `Rotation enrollment` check so ordering stays stable.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
python3 -m unittest tests.unit.test_health_check -k lid -v && ./scripts/test
```

Expected: PASS, suite green.

- [ ] **Step 5: Commit**

```bash
git add health_check.py tests/unit/test_health_check.py
git commit -m "feat(health): report built-in display enrollment"
```

---

### Task 11: Enroll this host, verify physically, and document

**Files:**
- Modify: `README.md`, `docs/install.md`, `docs/qualification.md`, `CHANGELOG.md`
- Create: `docs/log/lid-open-support.md`

- [ ] **Step 1: Install and enroll the lid**

```bash
python3 install.py B          # lid closed
# open the laptop lid, then:
python3 install.py B --capture-lid
python3 -c "
import json; print(json.load(open('~/.config/display-auto/config.json'))['keys'])
"
```

Expected: `keys` contains `builtin` with the internal panel's identity.

- [ ] **Step 2: Verify each profile with the lid open**

With the lid open, read the live layout after each input change:

```bash
~/.local/bin/display-auto.sh status | python3 -c "
import json,sys; d=json.load(sys.stdin); print(d['status'], d['profile'], d['inputs'])
"
~/.local/bin/display-ddc display list
/tmp/dl-test status | python3 -c "
import json,sys
for s in json.load(sys.stdin)['screens']:
    print(s['key'], s['width'], 'x', s['height'], 'rot', s['rotation'], 'mirrorOf', s.get('mirrorOf'))
"
```

Expected, per the spec's table: `extended` and `pg` show the built-in mirroring the PG;
`benq` shows it mirroring the BenQ; `away` leaves it alone. Record the actual readings.

- [ ] **Step 3: Verify rotation with the lid open**

Turn the BenQ to portrait with the lid open and confirm the built-in still mirrors the PG and
shows a landscape desktop, and that the controller reports `ready`.

- [ ] **Step 4: Update the documents**

`README.md`: the lid no longer has to be closed during ordinary use; it must still be closed
for capture. `docs/install.md`: document `--capture-lid`, that it needs the lid open, and that
it records only the identity. `docs/qualification.md`: record what was physically observed and
what was not. `CHANGELOG.md`: one bullet for the unification, one for the lid.

- [ ] **Step 5: Write the work log**

Create `docs/log/lid-open-support.md` with the observed readings from Steps 2 and 3, the tests
added, and anything still unqualified.

- [ ] **Step 6: Run the full verification and commit**

```bash
./scripts/verify --native
git add README.md docs/ CHANGELOG.md
git commit -m "docs: document built-in display support and its qualification"
git push origin main
```

Expected: verify exit 0, CI green on `verify`, Python 3.10 and Python 3.14.

---

## Self-review

**Spec coverage.** Intended behavior table → Tasks 4, 9. Stage A unification → Tasks 1-4,
proven by Task 5. `mirrorOf` as single source of truth → Tasks 2, 3, 4. Drop `source` → Task 3.
Delete `matches` → Task 4. Set equality replacing the count → Task 2. Derived file always
applied → Task 4 (`write_active_baseline`). Keeping the `rotation-active.json` name → Task 4
comment and Global Constraints. `keys.builtin` by identity → Task 7. `--capture-lid` separate
and recording only the key → Task 7. `CGDisplayIsBuiltin` guard → Tasks 6, 7. Absent
`builtin` meaning today's behavior → Tasks 8, 9 (second test). Derivation composing rotation
and lid → Task 9. `validate_config` → Task 8. Doctor → Task 10. Docs and rollback → Task 11.

**Gaps found and closed.** The spec says read-only commands must never write the derived
baseline; Task 4 preserves that because only `apply` calls `write_active_baseline`, and
`tests/unit/test_health_check.py:170` already guards it. The spec did not say what happens if
the enrolled built-in appears while `profile` is `away`; Task 9 leaves it untouched, matching
the behavior table.

**Type consistency.** `mismatches(baseline:live:) -> [Mismatch]` and
`unknownMasters(baseline:) -> [String]` are used with those exact signatures in Tasks 1-3.
`derive_baseline(config, profile, lid_online=False)` is introduced in Task 4 with two
parameters and extended in Task 9 with the third; Task 9 restates the whole function so an
executor reading it alone sees the final form. `write_active_baseline(config, baseline) -> Path`
is defined and used in Task 4. `builtin_key(screens) -> str` is defined in Task 7 and used
there only.
