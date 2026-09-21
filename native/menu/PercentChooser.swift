// SPDX-License-Identifier: MIT
import AppKit

final class PercentChooser:NSObject,NSWindowDelegate {
    let window=NSPanel(contentRect:NSRect(x:0,y:0,width:600,height:560),styleMask:[.titled,.closable],backing:.buffered,defer:false)
    let feature=NSPopUpButton(),slider=NSSlider(value:50,minValue:0,maxValue:100,target:nil,action:nil)
    let requested=NSTextField(labelWithString:""),reason=NSTextField(wrappingLabelWithString:""),applyButton=NSButton()
    let role:String,availability:()->String?
    var accepted=false,invalidated=false
    init(role:String,previous:String?,fontSize:CGFloat,availability:@escaping ()->String?) {
        self.role=role;self.availability=availability;super.init()
        window.title="Set monitor percentage";window.delegate=self;window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=14
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-20)])
        let intro=NSTextField(wrappingLabelWithString:"\(role == "pg" ? "PG42UQ":"BenQ RD280UG") · Moving the slider changes only the requested value. Apply sends one command; hardware rounding may change the confirmed percentage.")
        intro.font = .systemFont(ofSize:fontSize);stack.addArrangedSubview(intro);intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        feature.addItems(withTitles:["Brightness","Monitor speaker volume"]);feature.setAccessibilityLabel("Setting to change");feature.font=intro.font;stack.addArrangedSubview(feature)
        slider.target=self;slider.action=#selector(changed);slider.isContinuous=true;slider.altIncrementValue=1;slider.toolTip="Option-Left/Right adjusts by one percentage point.";slider.setAccessibilityHelp("Option-Left/Right adjusts by one percentage point.");slider.setAccessibilityLabel("Requested percentage")
        stack.addArrangedSubview(slider);slider.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        requested.font=intro.font;stack.addArrangedSubview(requested)
        let scroll=NSScrollView();scroll.hasVerticalScroller=true
        let history=NSTextView();history.isEditable=false;history.isSelectable=true;history.font=intro.font
        history.isVerticallyResizable=true;history.isHorizontallyResizable=false;history.textContainer?.widthTracksTextView=true;history.autoresizingMask=[.width]
        history.string=previous ?? "No confirmed reading for this monitor. The slider starts at a proposed 50%; it is not a current reading."
        scroll.documentView=history;stack.addArrangedSubview(scroll);scroll.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true;scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:90).isActive=true
        reason.font=intro.font;stack.addArrangedSubview(reason);reason.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        applyButton.title="Apply requested percentage";applyButton.target=self;applyButton.action=#selector(apply);applyButton.font=intro.font;stack.addArrangedSubview(applyButton)
        let cancel=NSButton(title:"Cancel",target:self,action:#selector(cancel));cancel.keyEquivalent="\u{1b}";cancel.font=intro.font;stack.addArrangedSubview(cancel)
        window.initialFirstResponder=slider;changed()
    }
    @objc func changed() {slider.doubleValue=slider.doubleValue.rounded();requested.stringValue="Requested: \(slider.integerValue)% · not applied";checkAvailability()}
    @objc func checkAvailability() {let unavailable=availability();if unavailable != nil {invalidated=true};reason.stringValue=invalidated ? "Availability changed. Cancel and reopen after the monitor is ready.":"Confirmed settings will appear in Controls after Apply.";applyButton.isEnabled = !invalidated}
    @objc func apply() {checkAvailability();guard !invalidated else{return};accepted=true;NSApp.stopModal()}
    @objc func cancel() {NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {NSApp.stopModal();return true}
    func run()->[String]? {
        let timer=Timer(timeInterval:1,target:self,selector:#selector(checkAvailability),userInfo:nil,repeats:true)
        RunLoop.main.add(timer,forMode:.modalPanel)
        defer {timer.invalidate();window.orderOut(nil)}
        window.center();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window)
        guard accepted else{return nil}
        return ["monitor-set","--monitor",role,"--feature",feature.indexOfSelectedItem==0 ? "luminance":"volume","--percent",String(slider.integerValue)]
    }
}
