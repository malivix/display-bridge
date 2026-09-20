# UI and feature priorities after the menu refactor

Review date: 2026-09-21. Source baseline: `bfce4a4`. This document supersedes the ordering
in earlier UI roadmaps; their observations and work logs remain historical evidence.
No live display configuration was changed. The app is still experimental, and source
features must not be described as installed or physically qualified.

## Decision

The next implementation is **validated monitor command results**: a control must never
label a missing or unexpected response as a confirmed value for a different monitor.
Then complete the accessible preview workflow and guided independent setup. Existing
handoff, audio recovery and rotation remain the core product.

## Review findings

| Priority | Evidence | Required improvement |
| --- | --- | --- |
| High | `native/menu/MenuApp.swift`, `execute`: unknown monitor becomes BenQ; any feature other than luminance becomes volume; missing settings numbers become zero | Decode monitor responses once into validated types. Match the requested role and feature; reject booleans, invalid ranges, missing fields and unsupported values. Show unavailable or invalid response instead of a plausible default. Backend mutation guards remain authoritative. |
| High | `docs/qualification.md`: deployed source and current checkout differ; Mac B and concurrent controllers remain unqualified | Present app/controller revision agreement and deployment readiness together. Keep source tests, installed readback and physical outcomes separately visible. Do not imply an update has activated merely because it compiled. |
| High | Largest brightness dialog inspected in the isolated demo; all labels and actions visible. Existing logs cover other selected screens, not a full matrix | Qualify keyboard traversal, focus restoration, Escape/Return behavior, VoiceOver order and light/dark appearance across healthy, stale, busy, preview and recovery screens at minimum size. Fix observed failures before adding new modal workflows. |
| Medium | Setup is a read-only report; enrollment still uses installer steps | Provide independent Mac A/B setup with explicit role/input review, backup, calibration checklist and interrupted-setup recovery. Unknown and replacement monitors stay unmanaged until enrolled. |
| Medium | `MenuApp.execute` still mixes demo fixtures, command dispatch and result presentation after the source split | Introduce typed response/effect dispatch as part of the first result-validation slice. Move demo fixtures out when touching this path. Do not merely split the same conditional chain into arbitrary files. |
| Medium | Multiple older roadmap documents contain superseded missing-feature lists | Use this dated plan as the entry point; retain old records as historical. Update usage when a feature ships and link its evidence rather than repeating a second current checklist. |

The malformed-response issue is a source-level defect: this review does not establish that
it occurred on the user's hardware. The menu does not authorize hardware writes; Python
continues to check identity, topology and fresh ownership.

## What already exists

Preserve and qualify these instead of implementing duplicates: compact menu and five-tab
window; interface-size preference; contextual recovery actions; input ownership and logical
mirror diagram; mode snapshot freshness; separate compatibility/command deadlines; named
orientation-specific size presets and reversible previews; per-monitor brightness presets;
profile speaker preferences and manual override; setup checklist and app-conflict advisory;
incident notifications; local history and private diagnostics; reviewed support-summary copy;
window-scoped keyboard shortcuts; bounded process execution and recovery journals.

## Implementation sequence and acceptance

### 1. Trustworthy monitor result presentation — next

Add a small typed decoder in the menu command boundary, with explicit success, invalid
response and command failure outcomes. Start with `monitor-settings`, `monitor-adjust`
and `brightness-apply`; do not rewrite every report simultaneously. Validate role, feature,
value, maximum and percent against the actual CLI contract, including older supported
responses. The UI renders effects; it never invents values. Preserve the last verified
reading and mark a failed refresh instead of replacing it with zero.

Acceptance: wrong-role/feature, missing fields, JSON booleans in numeric positions,
out-of-range numbers, malformed/oversized output, nonzero exit and valid responses.
A failed parse never displays Confirmed, never retries the mutation and never erases a
recovery journal. Native isolated tests and a synthetic UI error scenario are required.
Rollback: coordinated source/menu deployment; no runtime schema migration.

### 2. Accessible preview and size matching

First finish the accessibility matrix above for current dialogs. Then offer a user-selected
longer preview duration (for example 20 or 40 seconds) through the controller transaction,
not only the UI countdown. Keep/Revert must remain prominent and work independently of
window visibility. A later physical-size matching guide can show estimated relative size
and let the user calibrate visually; it cannot promise native sharpness at every scale.

Acceptance: default unchanged; selected deadline survives menu exit/controller restart;
expired Keep rejected; ownership or orientation changes defer safely; rollback remains
bounded. Test enlarged text and keyboard-only use. Optical/readability evaluation is a
separate opt-in physical check. Never depend on accessibility text size enlarging Chrome.

### 3. Guided enrollment and upgrade

Build on the existing read-only setup/preflight and coordinated installer. Show prerequisite,
identity, input-map, orientation and version agreement before enabling activation. Review
and capture each host independently. Persist setup progress separately from recovery
journals; validate and atomically write configuration only after a concrete review.

Acceptance: extra monitors untouched; no device IDs copied from the other Mac; interrupted
capture leaves current configuration usable; queued previews block activation; failed
activation restores the coordinated release. Mac B physical tests remain a later session.

### 4. Useful convenience after those gates

| Feature | Value and boundary |
| --- | --- |
| Optional Shortcuts integration | Invoke existing bounded commands with explicit monitor target and useful results. No HTTP server or new hardware policy. Start with read-only status and manual preset apply. |
| Coalesced brightness control | A slider may improve repeated steps, but submit the final intent through the existing lock, recheck ownership and read back. Measure write/lock timing before choosing a debounce interval. |
| History timeline | Show phase duration, failures and waiting separately; label sample count and distinguish detection latency from application time. Existing text history remains available. |
| Calibrated physical-size matching | Compare logical points against trustworthy panel dimensions and orientation; user calibration overrides an estimate. Preview through existing rollback, never replay stale mode IDs. |

## Deliberately deferred

Adaptive brightness/ambient synchronization, automatic color/Focus modes, MoonHalo writes,
gamma overlays, arbitrary virtual displays and custom mode injection need distinct evidence
and a user need. Automatic input switching, software disconnection, cloud sync and network
control conflict with this project's current boundaries. A feature being available in another
app does not establish a safe protocol, license to copy its code, or compatibility here.

## Verification and release gate

For each implementation slice: focused regression tests, `scripts/verify`, native checks for
Swift/native changes, synthetic UI inspection and staged privacy review. Current refactor
validation: 233 Python tests plus native builds/self-tests; the private named pasteboard
integration also passed. These checks do not prove audio, flicker, rotation latency or
simultaneous-Mac behavior. Installed qualification follows [the separate checklist](../qualification.md).

Research evidence and competitor distinctions: [fresh comparison](../research/feature-comparison-2026-09-21.md).
