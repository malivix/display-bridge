// SPDX-License-Identifier: MIT
import AppKit

if CommandLine.arguments.contains("--self-test") {runMenuSelfTests()}
if CommandLine.arguments.contains("--test-private-pasteboard") {runPrivatePasteboardTest()}
if CommandLine.arguments.contains("--test-notification") {runNotificationTest()}

let app=NSApplication.shared
let delegate=App();app.delegate=delegate;app.run()
