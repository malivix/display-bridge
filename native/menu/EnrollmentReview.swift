// SPDX-License-Identifier: MIT
import AppKit
import CoreFoundation

func enrollmentHost(_ index:Int)->String? {index==1 ? "A":index==2 ? "B":nil}

final class EnrollmentReviewDialog:NSObject,NSWindowDelegate {
    let window:NSPanel
    let selector=NSPopUpButton()
    let review=NSButton()
    var host:String?
    init(fontSize:CGFloat) {
        window=NSPanel(contentRect:NSRect(x:0,y:0,width:640,height:560),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        super.init()
        window.title="Review this Mac's enrollment";window.delegate=self;window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=16
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20)])
        let text=NSTextField(wrappingLabelWithString:"Choose the role of this Mac. Both supported monitors must show this Mac in extended mode, with fixed 120-Hz HiDPI and HDR off.\n\nMac A inputs: PG 17 · BenQ 19\nMac B inputs: PG 18 · BenQ 15\n\nReview reads monitor and audio information. It does not save enrollment or change services. Compatible helpers must already be installed.")
        text.font=NSFont.systemFont(ofSize:fontSize);stack.addArrangedSubview(text);text.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        selector.addItems(withTitles:["Choose this Mac's role…","Mac A","Mac B"]);selector.font=text.font
        selector.setAccessibilityLabel("Role of this Mac");selector.target=self;selector.action=#selector(selectionChanged)
        stack.addArrangedSubview(selector)
        review.title="Run read-only review";review.font=text.font;review.target=self;review.action=#selector(confirm);review.isEnabled=false;review.keyEquivalent="\r"
        stack.addArrangedSubview(review)
        let cancel=NSButton(title:"Cancel",target:self,action:#selector(cancel));cancel.font=text.font;cancel.keyEquivalent="\u{1b}";stack.addArrangedSubview(cancel)
        window.initialFirstResponder=selector
    }
    @objc func selectionChanged(){review.isEnabled=enrollmentHost(selector.indexOfSelectedItem) != nil}
    @objc func confirm(){guard let selected=enrollmentHost(selector.indexOfSelectedItem) else{return};host=selected;NSApp.stopModal()}
    @objc func cancel(){host=nil;NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {cancel();return true}
    func run()->String? {window.center();window.recalculateKeyViewLoop();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil);return host}
}

func enrollmentReviewSummary(_ json:String,_ expectedHost:String)->String {
    let unavailable="Enrollment review could not be validated. No enrollment was saved. Check setup readiness and refresh the review."
    guard ["A","B"].contains(expectedHost),json.utf8.count<=1_048_576,let data=json.data(using:.utf8),
          let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
          let readOnly=report["read_only"] as? NSNumber,CFGetTypeID(readOnly)==CFBooleanGetTypeID(),readOnly.boolValue,
          report["status"] as? String=="review-ready",report["host"] as? String==expectedHost,
          let monitors=report["monitors"] as? [[String:Any]],monitors.count==2,
          Set(monitors.compactMap{$0["monitor"] as? String})==Set(["pg","benq"]),
          report["audio_routes"] as? [String]==["pg","benq","built-in"] else{return unavailable}
    func integer(_ value:Any?)->Int? {
        guard let n=value as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),n.doubleValue>=0,n.doubleValue<=65536,n.doubleValue.rounded()==n.doubleValue else{return nil}
        return n.intValue
    }
    var lines=["Mac \(expectedHost) · prospective enrollment reviewed","No enrollment saved. This snapshot is not authorization to apply an old configuration."]
    for role in ["pg","benq"] {
        guard let row=monitors.first(where:{$0["monitor"] as? String==role}),
              let width=integer(row["width"]),width>0,let height=integer(row["height"]),height>0,
              integer(row["pixelWidth"])==2*width,integer(row["pixelHeight"])==2*height,
              let angle=integer(row["rotation"]),[0,90,180,270].contains(angle),
              let input=integer(row["local_input"]),input==(role=="pg" ? (expectedHost=="A" ? 17:18):(expectedHost=="A" ? 19:15)) else{return unavailable}
        lines.append("\(role=="pg" ? "PG42UQ":"BenQ RD280UG"): \(width) × \(height) · \(angle)° · local input \(input)")
    }
    lines.append("PG, BenQ and built-in audio routes were discovered. Audibility is not verified.")
    lines.append("Next: use the coordinated installer from your trusted checkout. It must recheck hardware before saving. Enroll each Mac independently; do not copy identities or recovery journals. Rotation calibration and physical switching tests remain separate.")
    return lines.joined(separator:"\n\n")
}
