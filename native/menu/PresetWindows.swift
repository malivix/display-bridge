// SPDX-License-Identifier: MIT
import AppKit
import CoreFoundation

func sizeComparison(_ current:[String:Any],_ selected:[String:Any])->String {
    let before=current["modes"] as? [String:[String:Any]] ?? [:]
    let after=selected["modes"] as? [String:[String:Any]] ?? [:]
    func dimension(_ mode:[String:Any],_ key:String)->Double? {
        guard let number=mode[key] as? NSNumber,CFGetTypeID(number) != CFBooleanGetTypeID() else{return nil}
        let value=number.doubleValue
        guard value.isFinite,value>0,value<=32768,value.rounded()==value else{return nil}
        return value
    }
    func dimensions(_ mode:[String:Any],_ a:String,_ b:String)->String {
        guard let width=dimension(mode,a),let height=dimension(mode,b) else{return "unavailable"}
        return "\(Int(width)) × \(Int(height))"
    }
    var lines=[selected["label"] as? String ?? "Selected size"]
    for (role,label) in [("pg","PG42UQ"),("benq","BenQ RD280UG")] {
        let old=before[role] ?? [:],new=after[role] ?? [:]
        var section="\(label)\nCurrent: \(dimensions(old,"width","height"))\nSelected: \(dimensions(new,"width","height"))"
        if let oldWidth=dimension(old,"width"),let newWidth=dimension(new,"width") {
            let delta=(oldWidth/newWidth-1)*100
            section += abs(delta)<0.5 ? "\nInterface size: unchanged":"\nInterface size: about \(String(format:"%.0f",abs(delta)))% \(delta>0 ? "larger":"smaller")"
        } else {section += "\nInterface size estimate unavailable"}
        section += "\nFramebuffer: \(dimensions(old,"pixelWidth","pixelHeight")) → \(dimensions(new,"pixelWidth","pixelHeight"))"
        lines.append(section)
    }
    lines.append("Size estimates compare each monitor with itself in the same orientation. They do not prove equal physical size across monitors or native pixel sharpness.")
    return lines.joined(separator:"\n\n")
}

func previewDurations(_ report:[String:Any])->[Int] {
    guard let values=report["preview_seconds"] as? [NSNumber],!values.isEmpty,values.count<=2,
          values.allSatisfy({CFGetTypeID($0) != CFBooleanGetTypeID() && [20.0,40.0].contains($0.doubleValue)}),
          Set(values.map{$0.intValue}).count==values.count,values.contains(20) else{return [20]}
    return values.map{$0.intValue}.sorted()
}

final class SizeChooser: NSObject, NSWindowDelegate {
    let choices:[[String:Any]]
    let current:[String:Any]
    let notes:String
    let window:NSPanel
    let selector=NSPopUpButton()
    let comparison=NSTextView()
    let durationSelector=NSPopUpButton()
    let durations:[Int]
    var previewSeconds:Int {durations[max(0,min(durations.count-1,durationSelector.indexOfSelectedItem))]}
    var result = -1
    var selectedIndex:Int {selector.indexOfSelectedItem}
    init(choices:[[String:Any]],current:[String:Any],notes:String,orientation:String,fontSize:CGFloat,canSave:Bool,canRemove:Bool,durations:[Int]=[20]) {
        self.choices=choices;self.current=current;self.notes=notes
        self.durations=previewDurations(["preview_seconds":durations])
        window=NSPanel(contentRect:NSRect(x:0,y:0,width:660,height:720),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init()
        window.title="Compare display sizes";window.minSize=NSSize(width:600,height:620);window.delegate=self
        window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-20)])
        let intro=NSTextField(wrappingLabelWithString:"\(orientation) · Fixed 120 Hz · 2× HiDPI · HDR off\nPreview reverts unless you Keep it. Time starts after the new size is verified.")
        intro.font=NSFont.systemFont(ofSize:fontSize);stack.addArrangedSubview(intro)
        intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        selector.font=intro.font;selector.setAccessibilityLabel("Size choice to preview")
        for choice in choices {selector.addItem(withTitle:choice["label"] as? String ?? "Size")}
        selector.target=self;selector.action=#selector(selectionChanged(_:));stack.addArrangedSubview(selector)
        selector.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        durationSelector.font=intro.font
        durationSelector.setAccessibilityLabel("Time to confirm display size")
        durationSelector.addItems(withTitles:self.durations.map{"\($0) seconds to Keep or Revert"})
        durationSelector.isEnabled=self.durations.count>1
        stack.addArrangedSubview(durationSelector)
        durationSelector.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
        comparison.isEditable=false;comparison.isSelectable=true;comparison.font=intro.font
        comparison.isVerticallyResizable=true;comparison.isHorizontallyResizable=false;comparison.textContainer?.widthTracksTextView=true
        comparison.autoresizingMask=[.width];comparison.setAccessibilityLabel("Current and selected size comparison")
        scroll.documentView=comparison;stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:140).isActive=true
        for (index,title) in ["Preview selected size","Save current as preset…","Remove a saved preset…","Cancel"].enumerated() {
            let button=NSButton(title:title,target:self,action:#selector(finish(_:)));button.tag=index;button.font=intro.font
            button.setContentHuggingPriority(.required,for:.vertical)
            if index==0 {button.keyEquivalent="\r"}
            if index==1 {button.isEnabled=canSave}
            if index==2 {button.isEnabled=canRemove}
            if index==3 {button.keyEquivalent="\u{1b}"}
            stack.addArrangedSubview(button)
        }
        window.initialFirstResponder=selector;selectionChanged(selector)
    }
    @objc func selectionChanged(_ sender:NSPopUpButton) {
        guard selectedIndex>=0,selectedIndex<choices.count else{return}
        comparison.string=sizeComparison(current,choices[selectedIndex])+(notes.isEmpty ? "":"\n\n"+notes)
        comparison.scrollRangeToVisible(NSRange(location:0,length:0))
    }
    @objc func finish(_ sender:NSButton) {result=sender.tag;NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {result = -1;NSApp.stopModal();return true}
    func run()->Int {
        window.center();window.recalculateKeyViewLoop();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil)
        return result
    }
}

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

final class PresetDialog: NSObject, NSWindowDelegate {
    let window:NSPanel
    let presets:[[String:Any]]?
    let brightnessMonitor:String?
    let name=NSTextField()
    let replace=NSButton(checkboxWithTitle:"Replace existing preset",target:nil,action:nil)
    let selector=NSPopUpButton()
    let errorLabel=NSTextField(wrappingLabelWithString:"")
    var arguments:[String]?
    init(fontSize:CGFloat,presets:[[String:Any]]?=nil,brightnessMonitor:String?=nil) {
        self.presets=presets;self.brightnessMonitor=brightnessMonitor
        window=NSPanel(contentRect:NSRect(x:0,y:0,width:620,height:480),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init()
        let saving=presets==nil
        window.title=brightnessMonitor==nil ? (saving ? "Save current size preset":"Remove a saved size preset"):"Save current brightness preset"
        window.minSize=NSSize(width:600,height:460);window.delegate=self;window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=16
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(lessThanOrEqualTo:window.contentView!.bottomAnchor,constant:-20)])
        let intro=NSTextField(wrappingLabelWithString:saving ? "Save the sizes currently displayed for this orientation. The highlighted preview choice is not applied. Replacement affects only this name and orientation.":"Select the saved name and orientation to remove. Current display settings and presets for the other orientation are preserved.")
        if let role=brightnessMonitor {intro.stringValue="Save the current hardware brightness of \(role=="pg" ? "PG42UQ":"BenQ RD280UG"). Replacement affects only this name and monitor. Display size and speaker volume are unchanged."}
        let font=NSFont.systemFont(ofSize:fontSize);intro.font=font
        stack.addArrangedSubview(intro);intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        if saving {
            name.font=font;name.placeholderString="Preset name, e.g. Reading";name.setAccessibilityLabel("Preset name")
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
        let submit=NSButton(title:brightnessMonitor==nil ? (saving ? "Save current size":"Remove selected preset"):"Save current brightness",target:self,action:#selector(confirm(_:)))
        submit.font=font
        // Destructive removal is explicit; Return in the selector must not remove a preset.
        if saving {submit.keyEquivalent="\r"}
        submit.isEnabled=saving || !(presets ?? []).isEmpty
        let cancel=NSButton(title:"Cancel",target:self,action:#selector(cancel(_:)));cancel.font=font;cancel.keyEquivalent="\u{1b}"
        stack.addArrangedSubview(submit);stack.addArrangedSubview(cancel)
    }
    @objc func confirm(_ sender:NSButton) {
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
        window.center();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil)
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
    var result = -1
    var selected:BrightnessEntry? {entries.indices.contains(selector.indexOfSelectedItem) ? entries[selector.indexOfSelectedItem]:nil}
    init(monitor:String,entries:[BrightnessEntry],fontSize:CGFloat,unavailable:String?,canRemove:Bool) {
        self.entries=entries
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
        let note=NSTextField(wrappingLabelWithString:unavailable ?? "Saved values are not live readings. Apply checks the current input and range, then verifies the result. Nothing runs automatically.")
        note.font=font;stack.addArrangedSubview(note);note.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        for (index,title) in ["Apply selected brightness","Save current brightness…","Remove selected preset","Cancel"].enumerated() {
            let button=NSButton(title:title,target:self,action:#selector(finish(_:)));button.tag=index;button.font=font
            if index==0 {button.isEnabled=unavailable==nil && !entries.isEmpty}
            if index==1 {button.isEnabled=unavailable==nil}
            if index==2 {button.isEnabled=canRemove && !entries.isEmpty}
            if index==3 {button.keyEquivalent="\u{1b}"}
            stack.addArrangedSubview(button)
        }
        window.initialFirstResponder=selector;selectEntry(selector)
    }
    @objc func selectEntry(_ sender:NSPopUpButton) {detail.stringValue=selected?.description ?? "No saved brightness presets for this monitor."}
    @objc func finish(_ sender:NSButton) {result=sender.tag;NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {result = -1;NSApp.stopModal();return true}
    func run()->Int {window.center();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil);return result}
}

enum PanelShortcut: Equatable {
    case tab(String)
    case refresh
}
func panelShortcut(_ key:String,_ modifiers:NSEvent.ModifierFlags,_ repeating:Bool)->PanelShortcut? {
    guard !repeating,modifiers.intersection([.command,.option,.control,.shift]) == .command else{return nil}
    let tabs=["1":"overview","2":"details","3":"displays","4":"audio","5":"monitor-controls"]
    if let tab=tabs[key] {return .tab(tab)}
    return key.lowercased()=="r" ? .refresh:nil
}
func panelRefreshArguments(_ tab:String,_ report:String,_ monitor:String)->[String]? {
    switch tab {
    case "details":return ["setup","doctor","history","ddc-history","support-summary"].contains(report) ? [report]:nil
    case "displays":return ["display-info"]
    case "monitor-controls":return ["pg","benq"].contains(monitor) ? ["monitor-settings","--monitor",monitor]:nil
    default:return nil // Overview, live status and Audio reread local controller state.
    }
}
final class DisplayPanel: NSWindow {
    var onShortcut:((PanelShortcut)->Void)?
    override func performKeyEquivalent(with event:NSEvent)->Bool {
        guard isKeyWindow,NSApp.modalWindow==nil,attachedSheet==nil,
              let shortcut=panelShortcut(event.charactersIgnoringModifiers ?? "",event.modifierFlags,event.isARepeat),
              let handler=onShortcut else{return super.performKeyEquivalent(with:event)}
        handler(shortcut);return true
    }
}
