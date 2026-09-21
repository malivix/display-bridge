// SPDX-License-Identifier: MIT
import AppKit

// Native rounded push buttons use a fixed bezel height. Flexible bezels and an
// explicit minimum target height let larger text retain padding and focus space.
func sizeInterfaceControl(_ control:NSControl,fontSize:CGFloat) {
    control.font = .systemFont(ofSize:fontSize)
    control.controlSize = fontSize>=20 ? .large:.regular
    var interactive=false
    if let button=control as? NSButton {
        if button.isBordered {button.bezelStyle = .regularSquare}
        interactive=true
    } else if let segments=control as? NSSegmentedControl {
        segments.segmentStyle = .rounded
        interactive=true
    } else if let field=control as? NSTextField,field.isEditable {
        interactive=true
    }
    if interactive {
        let identifier="display-bridge-control-height"
        let height=control.constraints.first(where:{$0.identifier==identifier}) ?? {
            let constraint=control.heightAnchor.constraint(greaterThanOrEqualToConstant:0)
            constraint.identifier=identifier;constraint.isActive=true;return constraint
        }()
        height.constant=ceil(fontSize+20)
        control.setContentCompressionResistancePriority(.required,for:.vertical)
    }
    control.invalidateIntrinsicContentSize()
}

// A native segmented picker with padded targets replaces the fixed-height tab strip.
// NSTabView continues to own selection and content; this is only its navigation view.
final class SizedTabPicker:NSObject,NSTabViewDelegate {
    let control:NSSegmentedControl
    private let tabs:NSTabView
    init(tabs:NSTabView) {
        self.tabs=tabs
        control=NSSegmentedControl(labels:tabs.tabViewItems.map{$0.label},trackingMode:.selectOne,target:nil,action:nil)
        super.init()
        control.target=self;control.action=#selector(selectTab)
        control.setAccessibilityLabel("Display Bridge sections")
        control.setAccessibilityHelp("Command 1 through 5 selects a section. Use arrow keys to move between sections.")
        tabs.tabViewType = .noTabsNoBorder;tabs.delegate=self
        control.selectedSegment=tabs.selectedTabViewItem.map{tabs.indexOfTabViewItem($0)} ?? 0
    }
    @objc private func selectTab() {
        guard tabs.tabViewItems.indices.contains(control.selectedSegment) else{return}
        tabs.selectTabViewItem(at:control.selectedSegment)
    }
    func tabView(_ tabView:NSTabView,didSelect tabViewItem:NSTabViewItem?) {
        control.selectedSegment=tabViewItem.map{tabView.indexOfTabViewItem($0)} ?? -1
    }
}
