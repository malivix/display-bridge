// SPDX-License-Identifier: MIT
import AppKit

final class PercentChooser:NSObject,NSWindowDelegate,NSTextFieldDelegate {
    let window=NSPanel(contentRect:NSRect(x:0,y:0,width:600,height:600),styleMask:[.titled,.closable],backing:.buffered,defer:false)
    let feature=NSPopUpButton(),slider=NSSlider(value:50,minValue:0,maxValue:100,target:nil,action:nil)
    let requested=NSTextField(wrappingLabelWithString:""),reason=NSTextField(wrappingLabelWithString:""),applyButton=NSButton()
    let role:String,availability:()->String?
    let readings:MonitorReadings
    let history=NSTextView()
    let percentage=NSTextField()
    var proposal:Int? {requestedPercentage(percentage.stringValue)}
    var accepted=false,invalidated=false
    init(role:String,readings:MonitorReadings,fontSize:CGFloat,availability:@escaping ()->String?) {
        self.role=role;self.readings=readings;self.availability=availability;super.init()
        window.title="Set monitor percentage";window.delegate=self;window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=14
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-20)])
        let intro=NSTextField(wrappingLabelWithString:"\(role == "pg" ? "PG42UQ":"BenQ RD280UG") · Typing or moving the slider changes only the requested value. Apply sends one command; hardware rounding may change the confirmed percentage.")
        intro.font = .systemFont(ofSize:fontSize);stack.addArrangedSubview(intro);intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        feature.target=self;feature.action=#selector(featureChanged)
        feature.addItems(withTitles:["Brightness","Monitor speaker volume"]);feature.setAccessibilityLabel("Setting to change");feature.font=intro.font;stack.addArrangedSubview(feature)
        slider.target=self;slider.action=#selector(changed);slider.isContinuous=true;slider.altIncrementValue=1;slider.toolTip="Option-Left/Right adjusts by one percentage point.";slider.setAccessibilityHelp("Option-Left/Right adjusts by one percentage point.");slider.setAccessibilityLabel("Requested percentage")
        stack.addArrangedSubview(slider);slider.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        percentage.font=intro.font;percentage.placeholderString="0–100";percentage.delegate=self
        percentage.setAccessibilityLabel("Requested percentage, whole number from 0 to 100")
        let entryRow=NSStackView(views:[percentage,NSTextField(labelWithString:"%")])
        percentage.widthAnchor.constraint(equalToConstant:110).isActive=true
        stack.addArrangedSubview(entryRow)
        requested.font=intro.font;stack.addArrangedSubview(requested)
        requested.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        let scroll=NSScrollView();scroll.hasVerticalScroller=true
        history.isEditable=false;history.isSelectable=true;history.font=intro.font
        history.isVerticallyResizable=true;history.isHorizontallyResizable=false;history.textContainer?.widthTracksTextView=true;history.autoresizingMask=[.width]
        scroll.documentView=history;stack.addArrangedSubview(scroll);scroll.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true;scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:90).isActive=true
        reason.font=intro.font;stack.addArrangedSubview(reason);reason.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        applyButton.title="Apply requested percentage";applyButton.target=self;applyButton.action=#selector(apply);applyButton.font=intro.font;stack.addArrangedSubview(applyButton)
        let cancel=NSButton(title:"Cancel",target:self,action:#selector(cancel));cancel.keyEquivalent="\u{1b}";cancel.font=intro.font;stack.addArrangedSubview(cancel)
        window.initialFirstResponder=percentage;featureChanged()
    }
    var selectedFeature:String {feature.indexOfSelectedItem==0 ? "luminance":"volume"}
    @objc func featureChanged() {
        let observation=readings.observation(for:role,feature:selectedFeature)
        percentage.stringValue=observation.map{String($0.setting.percent)} ?? ""
        slider.integerValue=observation?.setting.percent ?? 50
        history.string=observation?.description ?? "No confirmed reading for this setting. Type a percentage or move the slider to choose a value; its initial position is not a reading."
        updateProposal()
    }
    @objc func changed() {
        slider.doubleValue=slider.doubleValue.rounded()
        percentage.stringValue=String(slider.integerValue)
        updateProposal()
    }
    func controlTextDidChange(_ notification:Notification) {
        if let value=proposal {slider.integerValue=value}
        updateProposal()
    }
    func updateProposal() {
        let feedback=percentageFeedback(percentage.stringValue)
        requested.stringValue=feedback
        slider.setAccessibilityLabel(proposal==nil ? "Percentage slider — no valid request":"Requested percentage")
        slider.setAccessibilityValueDescription(feedback)
        percentage.setAccessibilityHelp(feedback+". Apply is required to send a setting.")
        checkAvailability()
    }
    @objc func checkAvailability() {let unavailable=availability();if unavailable != nil {invalidated=true};reason.stringValue=invalidated ? "Availability changed. Cancel and reopen after the monitor is ready.":"Confirmed settings will appear in Controls after Apply.";applyButton.isEnabled = !invalidated && proposal != nil}
    @objc func apply() {checkAvailability();guard !invalidated && proposal != nil else{return};accepted=true;NSApp.stopModal()}
    @objc func cancel() {NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {NSApp.stopModal();return true}
    func run()->[String]? {
        let timer=Timer(timeInterval:1,target:self,selector:#selector(checkAvailability),userInfo:nil,repeats:true)
        RunLoop.main.add(timer,forMode:.modalPanel)
        defer {timer.invalidate();window.orderOut(nil)}
        window.center();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window)
        guard accepted,let value=proposal else{return nil}
        return ["monitor-set","--monitor",role,"--feature",selectedFeature,"--percent",String(value)]
    }
}

// Do not use integerValue: it silently converts malformed text to a usable number.
func requestedPercentage(_ text:String)->Int? {
    guard !text.isEmpty,text.utf8.count<=3,
          text.utf8.allSatisfy({$0>=48 && $0<=57}),
          let value=Int(text),(0...100).contains(value) else{return nil}
    return value
}

// Keep invalid or absent intent distinct from the slider's retained position.
func percentageFeedback(_ text:String)->String {
    if let value=requestedPercentage(text) {return "Requested: \(value)% · not applied"}
    return text.isEmpty ? "No percentage chosen · not applied":"Invalid percentage · enter a whole number from 0 to 100"
}
