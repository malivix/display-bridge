// SPDX-License-Identifier: MIT
import AppKit
import CoreFoundation

func listeningAnswerLabel(_ choice:Int?)->String {
    choice==1 ? "heard":choice==2 ? "not heard":"uncertain"
}

final class ListeningPanel:NSPanel {
    var onCancel:(()->Void)?
    override func cancelOperation(_ sender:Any?) {onCancel?()}
}

final class ListeningDialog:NSObject,NSWindowDelegate {
    let window:ListeningPanel
    var choice:Int?
    init(title:String,body:String,buttons:[String],fontSize:CGFloat) {
        window=ListeningPanel(contentRect:NSRect(x:0,y:0,width:640,height:420),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        super.init()
        window.title=title;window.delegate=self;window.isReleasedWhenClosed=false
        window.onCancel={ [weak self] in self?.choice=nil;NSApp.stopModal() }
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=18
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20)])
        let text=NSTextField(wrappingLabelWithString:body);text.font=NSFont.systemFont(ofSize:fontSize)
        stack.addArrangedSubview(text);text.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        for (index,title) in buttons.enumerated() {
            let button=NSButton(title:title,target:self,action:#selector(select(_:)));button.tag=index;button.font=text.font
            if index==0 {button.keyEquivalent="\r";window.initialFirstResponder=button}
            stack.addArrangedSubview(button)
        }
    }
    @objc func select(_ sender:NSButton){choice=sender.tag;NSApp.stopModal()}
    func windowShouldClose(_ sender:NSWindow)->Bool {choice=nil;NSApp.stopModal();return true}
    func run()->Int? {window.center();window.recalculateKeyViewLoop();window.makeKeyAndOrderFront(nil);NSApp.runModal(for:window);window.orderOut(nil);return choice}
}

func listeningOutput(_ json:String)->String? {
    guard json.utf8.count<=1_048_576,let data=json.data(using:.utf8),
          let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
          let played=report["playback_completed"] as? NSNumber,CFGetTypeID(played)==CFBooleanGetTypeID(),played.boolValue,
          report["audibility"] as? String=="unconfirmed",let output=report["output"] as? String else{return nil}
    return ["pg":"PG42UQ","benq":"BenQ RD280UG","fallback":"Built-in speakers","external":"Selected external output"][output]
}
