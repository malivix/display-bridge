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
    func physicalEstimate(_ option:[String:Any])->String {
        guard let n=option["physical_size_percent"] as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite,n.doubleValue>0,n.doubleValue<=10000 else{return "unavailable"}
        return "PG about \(String(format:"%.0f",n.doubleValue))% of BenQ"
    }
    if current["physical_size_percent"] != nil || selected["physical_size_percent"] != nil {
        lines.insert("Estimated physical UI size\nCurrent: \(physicalEstimate(current))\nSelected: \(physicalEstimate(selected))\n100% means similar physical size. Model-based estimate; viewing distance and optical sharpness are not measured.",at:1)
    }
    lines.append("Size estimates compare each monitor with itself in the same orientation. The separate physical estimate is approximate and does not prove native pixel sharpness.")
    return lines.joined(separator:"\n\n")
}

func previewDurations(_ report:[String:Any])->[Int] {
    guard let values=report["preview_seconds"] as? [NSNumber],!values.isEmpty,values.count<=2,
          values.allSatisfy({CFGetTypeID($0) != CFBooleanGetTypeID() && [20.0,40.0].contains($0.doubleValue)}),
          Set(values.map{$0.intValue}).count==values.count,values.contains(20) else{return [20]}
    return values.map{$0.intValue}.sorted()
}

// Filter only known matching intents. Never infer a reference from a display label.
func matchingChoiceIndices(_ choices:[[String:Any]],reference:String?)->[Int] {
    guard let reference=reference else{return Array(choices.indices)}
    guard ["pg","benq"].contains(reference) else{return []}
    let keys:Set<String>=["match-"+reference,"match-"+reference+"-larger","match-"+reference+"-smaller"]
    return choices.indices.filter { index in
        guard choices[index]["preset"]==nil,let key=choices[index]["size"] as? String else{return false}
        return keys.contains(key)
    }
}

// Once context is lost, old options require a fresh inspection even if readiness returns.
struct SizePreviewValidity {
    private(set) var reason:String?
    mutating func observe(_ unavailable:String?) {
        if reason==nil {reason=unavailable}
    }
}

final class SizeChooser: NSObject, NSWindowDelegate {
    let choices:[[String:Any]]
    let current:[String:Any]
    let notes:String
    let availability:()->String?
    var validity=SizePreviewValidity()
    let availabilityLabel=NSTextField(wrappingLabelWithString:"")
    let window:NSPanel
    let selector=NSPopUpButton()
    let referenceSelector=NSPopUpButton()
    var visibleIndices:[Int]=[]
    var previewButton:NSButton?
    let comparison=NSTextView()
    let durationSelector=NSPopUpButton()
    let durations:[Int]
    var previewSeconds:Int {durations[max(0,min(durations.count-1,durationSelector.indexOfSelectedItem))]}
    var result = -1
    var selectedIndex:Int {
        let index=selector.indexOfSelectedItem
        return visibleIndices.indices.contains(index) ? visibleIndices[index]:-1
    }
    init(choices:[[String:Any]],current:[String:Any],notes:String,orientation:String,fontSize:CGFloat,canSave:Bool,canRemove:Bool,durations:[Int]=[20],availability:@escaping ()->String?) {
        self.choices=choices;self.current=current;self.notes=notes;self.availability=availability
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
        referenceSelector.font=intro.font
        referenceSelector.addItems(withTitles:["All qualified sizes","Keep BenQ size · adjust PG","Keep PG size · adjust BenQ"])
        referenceSelector.setAccessibilityLabel("Reference display to keep unchanged")
        referenceSelector.target=self;referenceSelector.action=#selector(referenceChanged)
        stack.addArrangedSubview(referenceSelector)
        referenceSelector.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
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
        availabilityLabel.font=intro.font;stack.addArrangedSubview(availabilityLabel)
        availabilityLabel.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        for (index,title) in ["Preview selected size","Save current as preset…","Remove a saved preset…","Cancel"].enumerated() {
            let button=NSButton(title:title,target:self,action:#selector(finish(_:)));button.tag=index;button.font=intro.font
            button.setContentHuggingPriority(.required,for:.vertical)
            if index==0 {button.keyEquivalent="\r";previewButton=button}
            if index==1 {button.isEnabled=canSave}
            if index==2 {button.isEnabled=canRemove}
            if index==3 {button.keyEquivalent="\u{1b}"}
            stack.addArrangedSubview(button)
        }
        window.initialFirstResponder=referenceSelector;referenceChanged()
    }
    @objc func referenceChanged() {
        let reference=referenceSelector.indexOfSelectedItem==1 ? "benq":referenceSelector.indexOfSelectedItem==2 ? "pg":nil
        visibleIndices=matchingChoiceIndices(choices,reference:reference)
        selector.removeAllItems()
        for index in visibleIndices {selector.addItem(withTitle:choices[index]["label"] as? String ?? "Size")}
        selector.isEnabled = !visibleIndices.isEmpty
        checkAvailability()
        selectionChanged(selector)
    }
    @objc func selectionChanged(_ sender:NSPopUpButton) {
        guard selectedIndex>=0,selectedIndex<choices.count else {
            comparison.string="No matching choice was offered for this reference. Choose All qualified sizes to inspect other options. No display setting has changed."
            return
        }
        comparison.string=sizeComparison(current,choices[selectedIndex])+(notes.isEmpty ? "":"\n\n"+notes)
        comparison.scrollRangeToVisible(NSRange(location:0,length:0))
    }
    @objc func checkAvailability() {
        validity.observe(availability())
        availabilityLabel.stringValue=validity.reason.map{"Earlier check failed: \($0) Cancel and reopen to inspect fresh choices."} ?? ""
        availabilityLabel.isHidden=validity.reason==nil
        previewButton?.isEnabled=selectedIndex>=0 && validity.reason==nil
    }
    @objc func finish(_ sender:NSButton) {
        if sender.tag==0 {
            checkAvailability()
            guard selectedIndex>=0 && validity.reason==nil else{return}
        }
        result=sender.tag;NSApp.stopModal()
    }
    func windowShouldClose(_ sender:NSWindow)->Bool {result = -1;NSApp.stopModal();return true}
    func run()->Int {
        let timer=Timer(timeInterval:1,target:self,selector:#selector(checkAvailability),userInfo:nil,repeats:true)
        RunLoop.main.add(timer,forMode:.modalPanel)
        defer {timer.invalidate()}
        checkAvailability()
        window.center();window.recalculateKeyViewLoop();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil)
        return result
    }
}
