// SPDX-License-Identifier: MIT
import AppKit

// Native responder-chain actions work in any focused text editor, including modal panels.
// No global event monitor or clipboard implementation is needed.
func makeEditingMenu(allowClipboard:Bool)->NSMenu {
    let main=NSMenu()
    let application=NSMenuItem()
    application.submenu=NSMenu(title:"Display Bridge")
    main.addItem(application)
    let edit=NSMenuItem(title:"Edit",action:nil,keyEquivalent:"")
    let submenu=NSMenu(title:"Edit")
    let actions:[(String,Selector,String)]=[
        ("Cut",#selector(NSText.cut(_:)),"x"),
        ("Copy",#selector(NSText.copy(_:)),"c"),
        ("Paste",#selector(NSText.paste(_:)),"v"),
        ("Select All",#selector(NSText.selectAll(_:)),"a")
    ]
    for (title,action,key) in actions where allowClipboard || key=="a" {
        let item=NSMenuItem(title:title,action:action,keyEquivalent:key)
        item.keyEquivalentModifierMask = .command
        submenu.addItem(item)
    }
    edit.submenu=submenu;main.addItem(edit)
    return main
}
