// SPDX-License-Identifier: MIT
import AppKit
import CoreFoundation

// A short Overview document stays at the top when recovery sections collapse.
final class OverviewStackView:NSStackView {override var isFlipped:Bool {true}}

func presetNameError(_ value:String)->String? {
    let scalars=Array(value.unicodeScalars)
    // Match Python's code-point count and str.strip whitespace contract in size_presets.
    func whitespace(_ scalar:Unicode.Scalar)->Bool {
        let n=scalar.value
        return (9...13).contains(n) || (28...32).contains(n) || (0x2000...0x200A).contains(n) || [0x85,0xA0,0x1680,0x2028,0x2029,0x202F,0x205F,0x3000].contains(n)
    }
    guard !scalars.isEmpty,scalars.count<=48 else{return "Use a name with 1–48 Unicode characters."}
    guard !whitespace(scalars.first!),!whitespace(scalars.last!) else{return "Remove whitespace from the start and end of the name."}
    guard !scalars.contains(where:{$0.value<32 || $0.value==127}) else{return "Remove control characters from the name."}
    return nil
}

final class PresetDialog: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    let window:NSPanel
    let presets:[[String:Any]]?
    let brightnessMonitor:String?
    let availability:()->String?
    private var unavailableReason:String?
    let name=NSTextField()
    let submit=NSButton()
    let replace=NSButton(checkboxWithTitle:"Replace existing preset",target:nil,action:nil)
    let selector=NSPopUpButton()
    let errorLabel=NSTextField(wrappingLabelWithString:"")
    var arguments:[String]?
    init(fontSize:CGFloat,presets:[[String:Any]]?=nil,brightnessMonitor:String?=nil,availability:@escaping ()->String?) {
        self.presets=presets;self.brightnessMonitor=brightnessMonitor;self.availability=availability
        window=NSPanel(contentRect:NSRect(x:0,y:0,width:620,height:480),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init()
        let saving=presets==nil
        window.title=brightnessMonitor==nil ? (saving ? "Save current size preset":"Remove a saved size preset"):"Save current brightness preset"
        window.minSize=NSSize(width:600,height:460);window.delegate=self;window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=16
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(lessThanOrEqualTo:window.contentView!.bottomAnchor,constant:-20)])
        let intro=NSTextField(wrappingLabelWithString:saving ? "Save the sizes currently displayed for this orientation. Opening this dialog does not change display sizes. Replacement affects only this name and orientation.":"Select the saved name and orientation to remove. Current display settings and presets for the other orientation are preserved.")
        if let role=brightnessMonitor {intro.stringValue="Save the current hardware brightness of \(role=="pg" ? "PG42UQ":"BenQ RD280UG"). Replacement affects only this name and monitor. Display size and speaker volume are unchanged."}
        let font=NSFont.systemFont(ofSize:fontSize);intro.font=font
        stack.addArrangedSubview(intro);intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        if saving {
            name.delegate=self;name.font=font;name.placeholderString="Preset name, e.g. Reading";name.setAccessibilityLabel("Preset name")
            stack.addArrangedSubview(name);name.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
            replace.font=font;stack.addArrangedSubview(replace);window.initialFirstResponder=name
        } else {
            selector.font=font;selector.setAccessibilityLabel("Saved preset and orientation to remove")
            for entry in presets ?? [] {
                selector.addItem(withTitle:"\(entry["name"] as? String ?? "Unnamed") — \(entry["rotation"] as? Int == 90 ? "Portrait":"Landscape")")
            }
            stack.addArrangedSubview(selector);selector.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
            window.initialFirstResponder=selector
        }
        errorLabel.font=font;errorLabel.textColor = .systemRed;errorLabel.isSelectable=true
        errorLabel.setAccessibilityLabel("Preset validation error");stack.addArrangedSubview(errorLabel)
        errorLabel.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        submit.title=brightnessMonitor==nil ? (saving ? "Save current size":"Remove selected preset"):"Save current brightness"
        submit.target=self;submit.action=#selector(confirm(_:))
        submit.font=font
        // Destructive removal is explicit; Return in the selector must not remove a preset.
        if saving {submit.keyEquivalent="\r"}
        submit.isEnabled=saving || !(presets ?? []).isEmpty
        let cancel=NSButton(title:"Cancel",target:self,action:#selector(cancel(_:)));cancel.font=font;cancel.keyEquivalent="\u{1b}"
        stack.addArrangedSubview(submit);stack.addArrangedSubview(cancel)
        if saving {validateName(announce:false)}
    }
    func controlTextDidChange(_ notification:Notification) {validateName(announce:true)}
    private func validateName(announce:Bool) {
        guard presets==nil else{return}
        if unavailableReason==nil {unavailableReason=availability()}
        let error=presetNameError(name.stringValue)
        let context=unavailableReason.map{"Earlier check failed: "+$0+" Cancel and reopen to check again."}
        let message=context ?? (name.stringValue.isEmpty ? "Enter a name for this preset.":error ?? "")
        let changed=errorLabel.stringValue != message
        errorLabel.stringValue=message
        errorLabel.textColor=context==nil && name.stringValue.isEmpty ? .secondaryLabelColor:.systemRed
        submit.isEnabled=error==nil && unavailableReason==nil
        if announce && changed {NSAccessibility.post(element:errorLabel,notification:.valueChanged)}
    }
    @objc private func checkAvailability() {validateName(announce:true)}
    @objc func confirm(_ sender:NSButton) {
        if presets==nil {
            validateName(announce:true)
            guard unavailableReason==nil else{return}
        }
        if let presets=presets {
            let index=selector.indexOfSelectedItem
            guard index>=0,index<presets.count,let label=presets[index]["name"] as? String,let rotation=presets[index]["rotation"] as? Int,[0,90].contains(rotation),let revision=presets[index]["revision"] as? String,!revision.isEmpty else {
                errorLabel.stringValue="This entry is incomplete. Cancel and refresh the preset list.";return
            }
            arguments=["preset-remove","--preset",label,"--orientation",String(rotation),"--fingerprint",revision]
        } else {
            if let error=presetNameError(name.stringValue) {
                errorLabel.stringValue=error;window.makeFirstResponder(name)
                NSAccessibility.post(element:errorLabel,notification:.valueChanged);return
            }
            arguments=brightnessMonitor.map{["brightness-save","--monitor",$0,"--preset",name.stringValue]} ?? ["preset-save","--preset",name.stringValue]
            if replace.state == .on {arguments?.append("--replace")}
        }
        NSApp.stopModal()
    }
    @objc func cancel(_ sender:NSButton) {arguments=nil;NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {arguments=nil;NSApp.stopModal();return true}
    func run()->[String]? {
        let timer=Timer(timeInterval:1,target:self,selector:#selector(checkAvailability),userInfo:nil,repeats:true)
        RunLoop.main.add(timer,forMode:.modalPanel)
        defer {timer.invalidate();window.orderOut(nil)}
        checkAvailability()
        window.center();window.recalculateKeyViewLoop();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window)
        return arguments
    }
}

struct BrightnessEntry {
    let name:String
    let value:Int
    let maximum:Int
    let revision:String
    var description:String {"\(name)\nSaved brightness: \(Int((Double(value)*100/Double(maximum)).rounded(.toNearestOrEven)))% (\(value) / \(maximum))"}
}
func brightnessEntries(_ json:String,_ expectedMonitor:String?=nil)->(monitor:String,entries:[BrightnessEntry])? {
    guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],report["read_only"] as? Bool == true,
          let role=report["monitor"] as? String,["pg","benq"].contains(role),let rows=report["presets"] as? [[String:Any]],rows.count<=20,expectedMonitor==nil || expectedMonitor==role else{return nil}
    var entries:[BrightnessEntry]=[];var names=Set<String>()
    for row in rows {
        guard row["monitor"] as? String==role,let name=row["name"] as? String,presetNameError(name)==nil,names.insert(name).inserted,
              let value=row["value"] as? NSNumber,let maximum=row["maximum"] as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),CFGetTypeID(maximum) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite,maximum.doubleValue.isFinite,value.doubleValue.rounded()==value.doubleValue,maximum.doubleValue.rounded()==maximum.doubleValue,
              value.doubleValue>=0,maximum.doubleValue>0,value.doubleValue<=maximum.doubleValue,maximum.doubleValue<=65535,
              let revision=row["revision"] as? String,revision.count==64,revision.allSatisfy({"0123456789abcdef".contains($0)}) else{return nil}
        entries.append(BrightnessEntry(name:name,value:value.intValue,maximum:maximum.intValue,revision:revision))
    }
    return (role,entries)
}
final class BrightnessChooser: NSObject, NSWindowDelegate {
    let window:NSPanel
    let entries:[BrightnessEntry]
    let selector=NSPopUpButton()
    let detail=NSTextField(wrappingLabelWithString:"")
    let availability:()->String?
    let removalAvailable:()->Bool
    let note=NSTextField(wrappingLabelWithString:"")
    private var unavailableReason:String?
    private var actionButtons:[NSButton]=[]
    var result = -1
    var selected:BrightnessEntry? {entries.indices.contains(selector.indexOfSelectedItem) ? entries[selector.indexOfSelectedItem]:nil}
    init(monitor:String,entries:[BrightnessEntry],fontSize:CGFloat,availability:@escaping ()->String?,removalAvailable:@escaping ()->Bool) {
        self.entries=entries;self.availability=availability;self.removalAvailable=removalAvailable
        window=NSPanel(contentRect:NSRect(x:0,y:0,width:640,height:620),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init()
        window.title="\(monitor=="pg" ? "PG42UQ":"BenQ RD280UG") brightness presets"
        window.minSize=NSSize(width:600,height:620);window.delegate=self;window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=14
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(lessThanOrEqualTo:window.contentView!.bottomAnchor,constant:-20)])
        let font=NSFont.systemFont(ofSize:fontSize)
        let intro=NSTextField(wrappingLabelWithString:"Target: \(monitor=="pg" ? "PG42UQ":"BenQ RD280UG"). Apply changes only this monitor's hardware brightness. Save reads its current brightness; it does not apply the selected preset.")
        intro.font=font;stack.addArrangedSubview(intro);intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        selector.font=font;selector.setAccessibilityLabel("Brightness preset")
        for entry in entries {selector.addItem(withTitle:entry.name)}
        selector.isEnabled = !entries.isEmpty;selector.target=self;selector.action=#selector(selectEntry(_:))
        stack.addArrangedSubview(selector);selector.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        detail.font=font;detail.isSelectable=true;stack.addArrangedSubview(detail);detail.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        note.font=font;stack.addArrangedSubview(note);note.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        for (index,title) in ["Apply selected brightness","Save current brightness…","Remove selected preset","Cancel"].enumerated() {
            let button=NSButton(title:title,target:self,action:#selector(finish(_:)));button.tag=index;button.font=font
            if index==3 {button.keyEquivalent="\u{1b}"}
            actionButtons.append(button);stack.addArrangedSubview(button)
        }
        window.initialFirstResponder=selector;selectEntry(selector)
    }
    @objc func selectEntry(_ sender:NSPopUpButton) {
        detail.stringValue=selected?.description ?? "No saved brightness presets for this monitor."
        checkAvailability()
    }
    @objc private func checkAvailability() {
        if unavailableReason==nil {unavailableReason=availability()}
        let message=unavailableReason.map{"Earlier check failed: "+$0+" Cancel and reopen to check again."}
            ?? "Saved values are not live readings. Apply checks the current input and range, then verifies the result. Nothing runs automatically."
        let changed=note.stringValue != message
        note.stringValue=message
        note.textColor=unavailableReason==nil ? .labelColor:.systemRed
        actionButtons[0].isEnabled=unavailableReason==nil && selected != nil
        actionButtons[1].isEnabled=unavailableReason==nil
        actionButtons[2].isEnabled=removalAvailable() && selected != nil
        actionButtons[2].toolTip=actionButtons[2].isEnabled ? nil:"Removal requires a selected preset and readable, idle saved controls."
        if changed {NSAccessibility.post(element:note,notification:.valueChanged)}
    }
    @objc func finish(_ sender:NSButton) {
        checkAvailability()
        guard actionButtons.indices.contains(sender.tag),actionButtons[sender.tag].isEnabled else{return}
        result=sender.tag;NSApp.stopModal()
    }
    func windowShouldClose(_ sender:NSWindow)->Bool {result = -1;NSApp.stopModal();return true}
    func run()->Int {
        let timer=Timer(timeInterval:1,target:self,selector:#selector(checkAvailability),userInfo:nil,repeats:true)
        RunLoop.main.add(timer,forMode:.modalPanel)
        defer {timer.invalidate();window.orderOut(nil)}
        checkAvailability()
        window.center();window.recalculateKeyViewLoop();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window)
        return result
    }
}

enum PanelShortcut: Equatable {
    case tab(String)
    case refresh
    case controls
}
func panelShortcut(_ key:String,_ modifiers:NSEvent.ModifierFlags,_ repeating:Bool)->PanelShortcut? {
    guard !repeating else{return nil}
    let chord=modifiers.intersection([.command,.option,.control,.shift])
    if key.lowercased()=="p",chord == [.command,.shift] {return .controls}
    guard chord == .command else{return nil}
    let tabs=["1":"overview","2":"details","3":"displays","4":"audio","5":"monitor-controls"]
    if let tab=tabs[key] {return .tab(tab)}
    return key.lowercased()=="r" ? .refresh:nil
}
func panelRefreshArguments(_ tab:String,_ report:String,_ monitor:String)->[String]? {
    switch tab {
    case "details":return report != "status" && detailReportChoices.contains(where:{$0.0==report}) ? [report]:nil
    case "displays":return ["display-info"]
    case "monitor-controls":return ["pg","benq"].contains(monitor) ? ["monitor-settings","--monitor",monitor]:nil
    default:return nil // Overview, live status and Audio reread local controller state.
    }
}
final class DisplayPanel: NSWindow {
    var onShortcut:((PanelShortcut)->Void)?
    override func makeFirstResponder(_ responder:NSResponder?)->Bool {
        let accepted=super.makeFirstResponder(responder)
        if accepted,let control=firstResponder as? NSControl,control.enclosingScrollView != nil {
            // Tab can focus controls below the viewport without revealing them.
            contentView?.layoutSubtreeIfNeeded()
            control.scrollToVisible(control.bounds.insetBy(dx:-4,dy:-4))
        }
        return accepted
    }
    override func performKeyEquivalent(with event:NSEvent)->Bool {
        guard isKeyWindow,NSApp.modalWindow==nil,attachedSheet==nil,
              let shortcut=panelShortcut(event.charactersIgnoringModifiers ?? "",event.modifierFlags,event.isARepeat),
              let handler=onShortcut else{return super.performKeyEquivalent(with:event)}
        handler(shortcut);return true
    }
}
