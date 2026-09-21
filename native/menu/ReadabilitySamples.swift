// SPDX-License-Identifier: MIT
import AppKit

// Visual references delegate preview navigation to the app; no hardware commands here.
final class ReadabilitySamples:NSObject {
    private var windows:[NSWindow]=[]
    private var onPreview:(()->Void)?
    @objc private func preview() {onPreview?()}
    func show(onPreview:@escaping ()->Void) {
        self.onPreview=onPreview
        if windows.isEmpty {
            windows=(1...2).map { number in
                let window=NSWindow(contentRect:NSRect(x:0,y:0,width:540,height:570),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
                window.title="Readability comparison · Sample \(number)"
                window.isReleasedWhenClosed=false;window.minSize=NSSize(width:420,height:460)
                let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=18
                let scroll=NSScrollView(frame:window.contentView!.bounds);scroll.hasVerticalScroller=true;scroll.autoresizingMask=[.width,.height]
                window.contentView!.addSubview(scroll);scroll.documentView=stack
                stack.edgeInsets=NSEdgeInsets(top:24,left:24,bottom:24,right:24);stack.translatesAutoresizingMaskIntoConstraints=false
                NSLayoutConstraint.activate([stack.widthAnchor.constraint(equalTo:scroll.contentView.widthAnchor),stack.topAnchor.constraint(equalTo:scroll.contentView.topAnchor)])
                func label(_ value:String,_ size:CGFloat,monospaced:Bool=false) {
                    let text=NSTextField(wrappingLabelWithString:value)
                    text.font=monospaced ? .monospacedSystemFont(ofSize:size,weight:.regular):.systemFont(ofSize:size)
                    text.isSelectable=true;stack.addArrangedSubview(text)
                    text.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-48).isActive=true
                }
                label("Place one sample on each monitor. Compare them from your usual viewing position.",22)
                label("Both samples use identical macOS point sizes. Their physical size follows each display's scaling; no settings are changed here.",18)
                let ruler=NSBox();ruler.boxType = .custom
                ruler.borderColor = .labelColor;ruler.fillColor = .quaternaryLabelColor;ruler.borderWidth=1
                ruler.setAccessibilityElement(true);ruler.setAccessibilityLabel("Reference rectangle, 200 macOS points wide and 32 points high")
                stack.addArrangedSubview(ruler)
                NSLayoutConstraint.activate([ruler.widthAnchor.constraint(equalToConstant:200),ruler.heightAnchor.constraint(equalToConstant:32)])
                label("200-point reference · not a millimeter ruler",16)
                label("14 pt · Example tab   Settings   Search",14)
                label("18 pt · Example tab   Settings   Search",18)
                label("24 pt · Readable text and panels",24)
                label("18 pt code · Aa0O 1lI {} []",18,monospaced:true)
                label("Compare first, then preview a qualified size. Keep/Revert stays in the main window; these samples stay open for comparison.",18)
                let previewButton=NSButton(title:"Choose a size to preview…",target:self,action:#selector(preview))
                previewButton.font = .systemFont(ofSize:20)
                stack.addArrangedSubview(previewButton)
                window.center();window.setFrameOrigin(NSPoint(x:window.frame.origin.x+CGFloat(number-1)*40,y:window.frame.origin.y-CGFloat(number-1)*40))
                return window
            }
        }
        for window in windows {window.makeKeyAndOrderFront(nil)}
        NSApp.activate(ignoringOtherApps:true)
    }
}
