// SPDX-License-Identifier: MIT
import AppKit
import UserNotifications

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    let root=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/display-auto")
    let command=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/display-auto.sh")
    let demo=CommandLine.arguments.contains("--demo") || Bundle.main.object(forInfoDictionaryKey:"DisplayBridgeDemo") as? Bool == true
    var demoScenario="ready"
    var ownership:MenuOwnership?
    var item:NSStatusItem!
    var timer:Timer?
    var panel:NSWindow?
    var scalableControls:[NSControl]=[]
    let detailReports=detailReportChoices
    var detailReport="status"
    var reportSelector:NSPopUpButton?
    var reportStatus:NSTextField?
    var reportRefreshButton:NSButton?
    var enrollmentReviewButton:NSButton?
    var copySummaryButton:NSButton?
    var reviewedSummary=ReviewedSupportSummary()
    var copySummaryNotice=""
    @objc func copyReviewedSummary() {
        guard !busy,let body=reviewedSummary.body(for:detailReport) else{return}
        if demo {message("Hardware-free demo","Clipboard copying is disabled in this demo. No clipboard content was changed.");return}
        copySummaryNotice=writeReviewedSummary(body,to:.general) ? "Reviewed summary copied. Nothing was uploaded.":"Could not copy the summary. Select the report text to copy manually."
        refresh()
    }
    var panelText:NSTextView?
    var contentTabs:NSTabView?
    var modeText:NSTextView?
    var modeStatus:NSTextField?
    var displayReading=DisplayReading()
    var displayRefreshing=false
    func acceptDisplayReading(_ json:String) {
        if displayReading.accept(json) {modeText?.string=displaySummary(json)}
        refresh()
    }
    let readabilitySamples=ReadabilitySamples()
    @objc func compareReadability() {readabilitySamples.show()}
    var monitorRole="pg"
    var monitorSelector:NSPopUpButton?
    var monitorButtons:[NSButton]=[]
    var monitorReason:NSTextField?
    var monitorFeedback:NSTextField?
    var monitorReadingSummary:NSTextField?
    var percentageButton:NSButton?
    var percentageReason:NSTextField?
    var monitorSupportDetails:NSStackView?
    var speakerPopups:[String:NSPopUpButton]=[:]
    var audioInfo:NSTextField?
    var audioOverrideButton:NSButton?
    var listeningResponse=""
    var audioRepair:NSButton?
    var audioReason:NSTextField?
    var overviewFields:[(NSTextField,NSTextField)]=[]
    var recoveryButton:NSButton?
    var presentedRecoveryAction:RecoveryAction?
    var pauseButton:NSButton?
    var displayTextIndex:Int?
    var panelActions:[NSButton]=[]
    var previewActions:[NSButton]=[]
    var previewConfirmationRow:NSStackView?
    var previewToken:String?
    var busy=false
    var operationStarted:Double?
    var operationName=""
    var operationDeadline:Double=45
    var operationResult=""
    var openMenus=Set<ObjectIdentifier>()
    var menuOpen:Bool {!openMenus.isEmpty}
    var controlsUsable=true
    var presetCapabilities:Set<String>?
    var checkingCapabilities=false
    var compatibilityLabel:NSTextField?
    var compatibilityButton:NSButton?
    var visibleCapabilities:Set<String>? {demo ? (demoScenario=="older-controller" ? []:PresetCommands.all.union(["monitor-set"])):presetCapabilities}
    @objc func checkPresetSupport() {
        guard !checkingCapabilities,!demo else{return}
        checkingCapabilities=true;presetCapabilities=nil;refresh()
        DispatchQueue.global().async {
            let result=runMenuCommand(self.command,["capabilities"],timeout:5,outputLimit:16_384)
            DispatchQueue.main.async {
                self.presetCapabilities=menuCapabilities(result);self.checkingCapabilities=false;self.refresh()
            }
        }
    }
    var failureAlerts=FailureAlerts(sent:Array((UserDefaults.standard.stringArray(forKey:"failureIncidents") ?? []).prefix(16)))
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {showPanel();return true}
    func showPanel() {
        if panel==nil {
            let window=DisplayPanel(contentRect:NSRect(x:0,y:0,width:640,height:600),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
            window.onShortcut={ [weak self] shortcut in self?.handlePanelShortcut(shortcut) }
            window.title=demo ? "Display Bridge — Demo":"Display Bridge";window.isReleasedWhenClosed=false;window.minSize=NSSize(width:600,height:480);window.center()
            let scroll=NSScrollView(frame:NSRect(x:20,y:138,width:600,height:440));scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
            scroll.autoresizingMask=[.width,.height]
            let text=NSTextView(frame:scroll.bounds);text.isEditable=false;text.isSelectable=true;text.font=NSFont.systemFont(ofSize:CGFloat([16,20,24][textSizeIndex()]))
            text.drawsBackground=false;text.isVerticallyResizable=true;text.isHorizontallyResizable=false;text.textContainer?.widthTracksTextView=true
            text.setAccessibilityLabel("Display status and command results")
            scroll.documentView=text;panelText=text;panel=window
            let tabs=NSTabView(frame:NSRect(x:20,y:138,width:600,height:440))
            tabs.autoresizingMask=[.width,.height];contentTabs=tabs
            tabs.toolTip="⌘1–5 selects a tab. ⌘R refreshes the current view."
            tabs.setAccessibilityHelp("Command 1 through 5 selects a tab. Command R refreshes the current view.")
            let overview=NSTabViewItem(identifier:"overview");overview.label="Overview"
            let overviewScroll=NSScrollView();overviewScroll.hasVerticalScroller=true;overviewScroll.autohidesScrollers=true
            let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=18
            stack.edgeInsets=NSEdgeInsets(top:16,left:16,bottom:16,right:16)
            stack.translatesAutoresizingMaskIntoConstraints=false;overviewScroll.documentView=stack
            NSLayoutConstraint.activate([stack.widthAnchor.constraint(equalTo:overviewScroll.contentView.widthAnchor),stack.topAnchor.constraint(equalTo:overviewScroll.contentView.topAnchor)])
            for section in statusSections(read("health.json"),read("control.json")) {
                let heading=NSTextField(labelWithString:section.title)
                let body=NSTextField(wrappingLabelWithString:section.body);body.isSelectable=true
                body.setAccessibilityElement(true);body.setAccessibilityRole(.staticText)
                body.setAccessibilityLabel(section.title+" details");body.setAccessibilityValue(section.body)
                let group=NSStackView(views:[heading,body]);group.orientation = .vertical;group.alignment = .leading;group.spacing=5
                group.setAccessibilityElement(true);group.setAccessibilityRole(.group);group.setAccessibilityLabel(section.title)
                stack.addArrangedSubview(group)
                group.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-32).isActive=true
                body.widthAnchor.constraint(equalTo:group.widthAnchor).isActive=true
                overviewFields.append((heading,body))
                if section.title=="Recovery" {
                    let button=NSButton(title:"Check health",target:self,action:#selector(runRecoveryAction(_:)))
                    group.insertArrangedSubview(button,at:1);recoveryButton=button;scalableControls.append(button)
                }
            }
            overview.view=overviewScroll;tabs.addTabViewItem(overview)
            let details=NSTabViewItem(identifier:"details");details.label="Details"
            let detailView=NSView();let reportRow=NSStackView();reportRow.spacing=8;reportRow.orientation = .vertical;reportRow.alignment = .leading
            let selectionRow=NSStackView();selectionRow.spacing=12;reportRow.addArrangedSubview(selectionRow)
            let reportPicker=NSPopUpButton();reportPicker.addItems(withTitles:detailReports.map{$0.1})
            reportPicker.target=self;reportPicker.action=#selector(selectReport(_:));reportPicker.setAccessibilityLabel("Detail report")
            reportSelector=reportPicker;selectionRow.addArrangedSubview(reportPicker);scalableControls.append(reportPicker)
            let refreshReport=NSButton(title:"Refresh",target:self,action:#selector(refreshReport))
            selectionRow.addArrangedSubview(refreshReport);scalableControls.append(refreshReport);panelActions.append(refreshReport);reportRefreshButton=refreshReport
            let reviewEnrollment=NSButton(title:"Review this Mac…",target:self,action:#selector(panelAction(_:)))
            reviewEnrollment.identifier=NSUserInterfaceItemIdentifier("enrollment-review")
            reviewEnrollment.toolTip="Choose Mac A or Mac B for a read-only enrollment review. No enrollment is saved."
            reportRow.addArrangedSubview(reviewEnrollment);enrollmentReviewButton=reviewEnrollment
            scalableControls.append(reviewEnrollment);panelActions.append(reviewEnrollment)
            let copySummary=NSButton(title:"Copy reviewed summary",target:self,action:#selector(copyReviewedSummary))
            copySummary.toolTip="Copy only the displayed support-summary body. Review it before sharing."
            reportRow.addArrangedSubview(copySummary);copySummaryButton=copySummary;scalableControls.append(copySummary)
            let more=NSButton(title:"More controls",target:self,action:#selector(openControls(_:)))
            let actions=NSStackView(views:[more]);actions.spacing=12;reportRow.addArrangedSubview(actions);scalableControls.append(more)
            for (title,action) in [("Health","doctor"),("Diagnostics","diagnostics")] {
                let button=NSButton(title:title,target:self,action:#selector(panelAction(_:)))
                button.identifier=NSUserInterfaceItemIdentifier(action);actions.addArrangedSubview(button)
                panelActions.append(button);scalableControls.append(button)
            }
            let reportNote=NSTextField(wrappingLabelWithString:"");reportNote.translatesAutoresizingMaskIntoConstraints=false
            detailView.addSubview(reportNote);reportStatus=reportNote;scalableControls.append(reportNote)
            reportRow.translatesAutoresizingMaskIntoConstraints=false;scroll.translatesAutoresizingMaskIntoConstraints=false
            detailView.addSubview(reportRow);detailView.addSubview(scroll)
            NSLayoutConstraint.activate([reportRow.leadingAnchor.constraint(equalTo:detailView.leadingAnchor,constant:12),reportRow.topAnchor.constraint(equalTo:detailView.topAnchor,constant:12),reportRow.trailingAnchor.constraint(lessThanOrEqualTo:detailView.trailingAnchor,constant:-12),scroll.leadingAnchor.constraint(equalTo:detailView.leadingAnchor,constant:12),scroll.trailingAnchor.constraint(equalTo:detailView.trailingAnchor,constant:-12),reportNote.topAnchor.constraint(equalTo:reportRow.bottomAnchor,constant:8),reportNote.leadingAnchor.constraint(equalTo:detailView.leadingAnchor,constant:12),reportNote.trailingAnchor.constraint(equalTo:detailView.trailingAnchor,constant:-12),scroll.topAnchor.constraint(equalTo:reportNote.bottomAnchor,constant:8),scroll.bottomAnchor.constraint(equalTo:detailView.bottomAnchor,constant:-12)])
            details.view=detailView;tabs.addTabViewItem(details)
            let displays=NSTabViewItem(identifier:"displays");displays.label="Displays"
            let modeView=NSView(frame:NSRect(x:0,y:0,width:580,height:400))
            let modeScroll=NSScrollView(frame:NSRect(x:12,y:52,width:556,height:336))
            modeScroll.hasVerticalScroller=true;modeScroll.autoresizingMask=[.width,.height]
            let modeContent=NSTextView(frame:modeScroll.bounds)
            modeContent.isEditable=false;modeContent.isSelectable=true;modeContent.drawsBackground=false
            modeContent.isVerticallyResizable=true;modeContent.isHorizontallyResizable=false;modeContent.textContainer?.widthTracksTextView=true
            modeContent.string="Refresh to inspect the enrolled displays. This reads current modes without changing settings. Values are a snapshot, not continuous monitoring."
            modeContent.setAccessibilityLabel("Measured display modes")
            modeScroll.documentView=modeContent;modeView.addSubview(modeScroll);modeText=modeContent
            let refreshModes=NSButton(title:"Refresh display details",target:self,action:#selector(panelAction(_:)))
            refreshModes.identifier=NSUserInterfaceItemIdentifier("display-info");refreshModes.translatesAutoresizingMaskIntoConstraints=false;scalableControls.append(refreshModes)
            let displayActions=NSStackView();displayActions.orientation = .vertical;displayActions.alignment = .leading;displayActions.spacing=10
            displayActions.translatesAutoresizingMaskIntoConstraints=false;modeView.addSubview(displayActions)
            displayActions.addArrangedSubview(refreshModes);panelActions.append(refreshModes)
            let previewSize=NSButton(title:"Preview size…",target:self,action:#selector(panelAction(_:)))
            previewSize.identifier=NSUserInterfaceItemIdentifier("preview-options")
            displayActions.addArrangedSubview(previewSize);previewActions.append(previewSize);scalableControls.append(previewSize)
            let samples=NSButton(title:"Compare readability…",target:self,action:#selector(compareReadability))
            displayActions.addArrangedSubview(samples);scalableControls.append(samples)
            let snapshotStatus=NSTextField(wrappingLabelWithString:"");snapshotStatus.isSelectable=true
            snapshotStatus.translatesAutoresizingMaskIntoConstraints=false;modeView.addSubview(snapshotStatus)
            modeStatus=snapshotStatus;scalableControls.append(snapshotStatus)
            NSLayoutConstraint.activate([snapshotStatus.leadingAnchor.constraint(equalTo:modeView.leadingAnchor,constant:12),snapshotStatus.trailingAnchor.constraint(equalTo:modeView.trailingAnchor,constant:-12),snapshotStatus.topAnchor.constraint(equalTo:modeView.topAnchor,constant:12)])
            modeScroll.translatesAutoresizingMaskIntoConstraints=false
            NSLayoutConstraint.activate([displayActions.leadingAnchor.constraint(equalTo:modeView.leadingAnchor,constant:12),displayActions.bottomAnchor.constraint(equalTo:modeView.bottomAnchor,constant:-12),modeScroll.leadingAnchor.constraint(equalTo:modeView.leadingAnchor,constant:12),modeScroll.trailingAnchor.constraint(equalTo:modeView.trailingAnchor,constant:-12),modeScroll.topAnchor.constraint(equalTo:snapshotStatus.bottomAnchor,constant:8),modeScroll.bottomAnchor.constraint(equalTo:displayActions.topAnchor,constant:-12)])
            displays.view=modeView;tabs.addTabViewItem(displays)
            let audioTab=NSTabViewItem(identifier:"audio");audioTab.label="Audio"
            let audioScroll=NSScrollView();audioScroll.hasVerticalScroller=true
            let audioStack=NSStackView();audioStack.orientation = .vertical;audioStack.alignment = .leading;audioStack.spacing=16
            audioStack.edgeInsets=NSEdgeInsets(top:16,left:16,bottom:16,right:16)
            audioStack.translatesAutoresizingMaskIntoConstraints=false;audioScroll.documentView=audioStack
            audioStack.widthAnchor.constraint(equalTo:audioScroll.contentView.widthAnchor).isActive=true
            audioStack.topAnchor.constraint(equalTo:audioScroll.contentView.topAnchor).isActive=true
            let info=NSTextField(wrappingLabelWithString:"Speaker preferences apply to each monitor profile. External headsets remain under your control.")
            audioStack.addArrangedSubview(info);info.widthAnchor.constraint(equalTo:audioStack.widthAnchor,constant:-32).isActive=true;audioInfo=info
            for (title,action) in [("Preserve output for 30 minutes","audio-manual"),("Repair audio","repair-audio"),("Test selected output…","audio-test-prompt")] {
                let button=NSButton(title:title,target:self,action:#selector(panelAction(_:)));button.identifier=NSUserInterfaceItemIdentifier(action)
                audioStack.addArrangedSubview(button);scalableControls.append(button)
                if action=="audio-manual" {audioOverrideButton=button}
                if action=="repair-audio" {audioRepair=button} else {panelActions.append(button)}
            }
            let reason=NSTextField(wrappingLabelWithString:"");audioStack.insertArrangedSubview(reason,at:3)
            reason.widthAnchor.constraint(equalTo:audioStack.widthAnchor,constant:-32).isActive=true;audioReason=reason
            for (profile,label) in [("extended","Both monitors here"),("pg","Only PG here"),("benq","Only BenQ here"),("away","Both monitors away")] {
                let title=NSTextField(wrappingLabelWithString:label);scalableControls.append(title)
                let popup=NSPopUpButton();popup.identifier=NSUserInterfaceItemIdentifier(profile)
                popup.target=self;popup.action=#selector(selectSpeaker(_:));popup.setAccessibilityLabel("Speaker when "+label.lowercased())
                for (key,name) in speakerChoices(profile) {popup.addItem(withTitle:name);popup.lastItem?.representedObject=key}
                speakerPopups[profile]=popup;scalableControls.append(popup)
                let row=NSStackView(views:[title,popup]);row.orientation = .vertical;row.alignment = .leading;row.spacing=6;audioStack.addArrangedSubview(row)
            }
            audioTab.view=audioScroll;tabs.addTabViewItem(audioTab)
            let controlsTab=NSTabViewItem(identifier:"monitor-controls");controlsTab.label="Controls"
            let controlsScroll=NSScrollView();controlsScroll.hasVerticalScroller=true
            let controlsStack=NSStackView();controlsStack.orientation = .vertical;controlsStack.alignment = .leading;controlsStack.spacing=18
            controlsStack.edgeInsets=NSEdgeInsets(top:16,left:16,bottom:16,right:16)
            controlsStack.translatesAutoresizingMaskIntoConstraints=false;controlsScroll.documentView=controlsStack
            controlsStack.widthAnchor.constraint(equalTo:controlsScroll.contentView.widthAnchor).isActive=true
            controlsStack.topAnchor.constraint(equalTo:controlsScroll.contentView.topAnchor).isActive=true
            let selector=NSPopUpButton();selector.addItems(withTitles:["PG42UQ","BenQ RD280UG"])
            selector.target=self;selector.action=#selector(selectMonitor(_:));selector.setAccessibilityLabel("Monitor to adjust")
            controlsStack.addArrangedSubview(selector);monitorSelector=selector;scalableControls.append(selector)
            let readingSummary=NSTextField(wrappingLabelWithString:monitorReadings.compactSummary(for:monitorRole,at:Date()))
            readingSummary.isSelectable=true;scalableControls.append(readingSummary)
            controlsStack.addArrangedSubview(readingSummary)
            readingSummary.widthAnchor.constraint(equalTo:controlsStack.widthAnchor,constant:-32).isActive=true
            monitorReadingSummary=readingSummary
            let availability=NSTextField(wrappingLabelWithString:"");controlsStack.addArrangedSubview(availability)
            availability.widthAnchor.constraint(equalTo:controlsStack.widthAnchor,constant:-32).isActive=true;monitorReason=availability
            let read=NSButton(title:"Read brightness and volume",target:self,action:#selector(adjustMonitor(_:)))
            read.identifier=NSUserInterfaceItemIdentifier("read");controlsStack.addArrangedSubview(read);monitorButtons.append(read);scalableControls.append(read)
            for (name,feature) in [("Brightness","luminance"),("Volume","volume")] {
                let row=NSStackView();row.spacing=12
                for (suffix,step) in [("−5%","-5"),("+5%","5")] {
                    let button=NSButton(title:"\(name) \(suffix)",target:self,action:#selector(adjustMonitor(_:)))
                    button.identifier=NSUserInterfaceItemIdentifier("\(feature):\(step)")
                    button.setAccessibilityLabel("\(name == "Volume" ? "Monitor speaker volume":name) \(suffix)")
                    row.addArrangedSubview(button);monitorButtons.append(button);scalableControls.append(button)
                }
                controlsStack.addArrangedSubview(row)
            }
            let precise=NSButton(title:"Set percentage…",target:self,action:#selector(setMonitorPercentage))
            controlsStack.addArrangedSubview(precise);percentageButton=precise;scalableControls.append(precise)
            let preciseReason=NSTextField(wrappingLabelWithString:"")
            controlsStack.addArrangedSubview(preciseReason);scalableControls.append(preciseReason)
            preciseReason.widthAnchor.constraint(equalTo:controlsStack.widthAnchor,constant:-32).isActive=true
            percentageReason=preciseReason
            let feedback=NSTextField(wrappingLabelWithString:"No confirmed settings yet. Read brightness and volume to inspect this monitor.")
            controlsStack.addArrangedSubview(feedback);feedback.widthAnchor.constraint(equalTo:controlsStack.widthAnchor,constant:-32).isActive=true;monitorFeedback=feedback
            let presetsButton=NSButton(title:"Brightness presets…",target:self,action:#selector(openBrightnessPresets))
            presetsButton.identifier=NSUserInterfaceItemIdentifier("brightness-list");controlsStack.addArrangedSubview(presetsButton);panelActions.append(presetsButton);scalableControls.append(presetsButton)
            let disclosure=NSButton(checkboxWithTitle:"Show support details",target:self,action:#selector(toggleMonitorSupport(_:)))
            controlsStack.addArrangedSubview(disclosure);scalableControls.append(disclosure)
            let support=NSStackView();support.orientation = .vertical;support.alignment = .leading;support.spacing=12
            controlsStack.addArrangedSubview(support);support.widthAnchor.constraint(equalTo:controlsStack.widthAnchor,constant:-32).isActive=true
            monitorSupportDetails=support
            let compatibility=NSTextField(wrappingLabelWithString:"");compatibility.isSelectable=true
            support.addArrangedSubview(compatibility);compatibility.widthAnchor.constraint(equalTo:support.widthAnchor).isActive=true
            compatibilityLabel=compatibility;scalableControls.append(compatibility)
            let checkSupport=NSButton(title:"Check preset support",target:self,action:#selector(checkPresetSupport))
            support.addArrangedSubview(checkSupport);compatibilityButton=checkSupport;scalableControls.append(checkSupport)
            let explanation=NSTextField(wrappingLabelWithString:"Equal brightness percentages do not mean equal light output. Monitor speaker volume does not select the Mac audio output.")
            support.addArrangedSubview(explanation);explanation.widthAnchor.constraint(equalTo:support.widthAnchor).isActive=true;scalableControls.append(explanation)
            support.isHidden=true
            controlsTab.view=controlsScroll;tabs.addTabViewItem(controlsTab)
            guard let content=window.contentView else {return}
            let footer=NSStackView();footer.orientation = .vertical;footer.alignment = .leading;footer.spacing=10
            footer.translatesAutoresizingMaskIntoConstraints=false;content.addSubview(footer)
            tabs.translatesAutoresizingMaskIntoConstraints=false;content.addSubview(tabs)
            NSLayoutConstraint.activate([footer.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:20),footer.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-20),footer.bottomAnchor.constraint(equalTo:content.bottomAnchor,constant:-16),tabs.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:20),tabs.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-20),tabs.topAnchor.constraint(equalTo:content.topAnchor,constant:16),tabs.bottomAnchor.constraint(equalTo:footer.topAnchor,constant:-16)])
            let sizes=NSSegmentedControl(labels:["Standard","Large","Largest"],trackingMode:.selectOne,target:self,action:#selector(changeTextSize(_:)))
            sizes.selectedSegment=textSizeIndex();sizes.setAccessibilityLabel("Interface size")
            let pause=NSButton(title:"Pause",target:self,action:#selector(togglePause(_:)));pauseButton=pause
            let sizeRow=NSStackView(views:[sizes,pause]);sizeRow.spacing=16;footer.addArrangedSubview(sizeRow)
            scalableControls.append(contentsOf:[sizes,pause])
            let previewRow=NSStackView();previewRow.spacing=12;footer.addArrangedSubview(previewRow);previewConfirmationRow=previewRow
            for (title,action) in [("Keep size","preview-keep"),("Revert size","preview-revert")] {
                let button=NSButton(title:title,target:self,action:#selector(panelAction(_:)))
                button.identifier=NSUserInterfaceItemIdentifier(action);previewRow.addArrangedSubview(button)
                previewActions.append(button);scalableControls.append(button)
            }
            if demo {
                let scenarios=NSPopUpButton();scenarios.addItems(withTitles:["ready","pg-only","benq-only","stale","paused","away","unknown-input","preview","recovery","recovery-wait","presets-error","controls-error","brightness-empty","older-controller","display-refresh-failed","monitor-response-error","audio-manual"])
                scenarios.target=self;scenarios.action=#selector(changeDemoScenario(_:));scenarios.setAccessibilityLabel("Synthetic scenario")
                let compact=NSButton(title:"Minimum window",target:self,action:#selector(compactDemo))
                let row=NSStackView(views:[scenarios,compact]);row.spacing=12;footer.addArrangedSubview(row)
                scalableControls.append(contentsOf:[scenarios,compact])
            }
            applyTextSize(textSizeIndex())
        }
        refresh();panel?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    func handlePanelShortcut(_ shortcut:PanelShortcut) {
        switch shortcut {
        case .tab(let identifier):
            contentTabs?.selectTabViewItem(withIdentifier:identifier)
            panel?.makeFirstResponder(contentTabs)
        case .refresh:
            guard !busy else{return}
            let tab=contentTabs?.selectedTabViewItem?.identifier as? String ?? "overview"
            if tab=="monitor-controls",let reason=monitorControlReason(read("health.json"),read("control.json"),monitorRole,busy) {
                monitorFeedback?.stringValue=reason;return
            }
            if let arguments=panelRefreshArguments(tab,detailReport,monitorRole) {execute(arguments)}
            else {refresh()}
        }
    }
    @objc func changeDemoScenario(_ sender:NSPopUpButton) {
        guard demo else {return}
        demoScenario=sender.titleOfSelectedItem ?? "ready";refresh()
    }
    @objc func compactDemo() {
        guard demo,let window=panel else {return}
        var frame=window.frame;frame.size=window.minSize;window.setFrame(frame,display:true)
    }
    @objc func selectReport(_ sender:NSPopUpButton) {
        let index=sender.indexOfSelectedItem
        guard index>=0,index<detailReports.count else {return}
        detailReport=detailReports[index].0
        reviewedSummary.clear();copySummaryNotice=""
        panelText?.setAccessibilityLabel(detailReports[index].1+" report")
        panelText?.string=detailReport=="status" ? "":detailReport=="enrollment-review" ? "Choose Review this Mac to select its role and inspect prospective enrollment. No enrollment is saved; compatible helpers must already be installed.":"Choose Refresh to read this report. Reports are snapshots and do not update in the background."
        refresh()
    }
    @objc func refreshReport() {
        if detailReport=="status" {refresh()} else {execute([detailReport])}
    }
    func showReport(_ action:String,_ text:String) {
        guard let index=detailReports.firstIndex(where:{$0.0==action}) else {return}
        detailReport=action;reportSelector?.selectItem(at:index)
        reviewedSummary.show(action,text);copySummaryNotice=""
        panelText?.setAccessibilityLabel(detailReports[index].1+" report")
        reportStatus?.stringValue="Snapshot report; inspect again for current information."
        panelText?.string="\(detailReports[index].1) · Snapshot at \(Date().formatted(date:.omitted,time:.standard))\n\(action=="enrollment-review" ? "Choose Review this Mac to inspect again.":"Refresh to inspect again.")\n\n"+text
        contentTabs?.selectTabViewItem(withIdentifier:"details")
        refresh()
    }
    func textSizeIndex()->Int {displayTextIndex ?? min(2,max(0,UserDefaults.standard.integer(forKey:"statusTextSize")))}
    func applyTextSize(_ index:Int) {
        let size=CGFloat([16,20,24][index])
        for control in scalableControls {control.font=NSFont.systemFont(ofSize:size);control.invalidateIntrinsicContentSize()}
        contentTabs?.font=NSFont.systemFont(ofSize:size)
        panelText?.font=NSFont.systemFont(ofSize:size)
        modeText?.font=NSFont.systemFont(ofSize:size)
        audioInfo?.font=NSFont.systemFont(ofSize:size);audioReason?.font=NSFont.systemFont(ofSize:size)
        monitorReason?.font=NSFont.systemFont(ofSize:size);monitorFeedback?.font=NSFont.systemFont(ofSize:size)
        for (heading,body) in overviewFields {heading.font=NSFont.boldSystemFont(ofSize:size);body.font=NSFont.systemFont(ofSize:size)}
    }
    var monitorReadings=MonitorReadings()
    func presentMonitorResponse(_ response:CommandResult,_ arguments:[String]) {
        if let reading=MonitorResponse.decode(response,arguments:arguments) {
            let text=monitorReadings.accept(reading,at:Date())
            showMonitorResult(text,reading.role)
        } else {
            operationResult=(response.code==0 ? "Monitor response could not be validated.":"Monitor command failed; see the error for details.")+" Read settings again; do not assume the action succeeded. It was not retried."
            if let role=MonitorResponse.requestedRole(arguments) {
                monitorReadings.markUnconfirmed(for:role)
                showMonitorResult(operationResult + (monitorReadings.previous(for:role).map{"\n\n"+$0} ?? ""),role)
            } else {
                showMonitorResult(operationResult,nil)
            }
        }
    }
    func showMonitorResult(_ text:String,_ role:String?) {
        if let role=role,["pg","benq"].contains(role) {
            monitorRole=role;monitorSelector?.selectItem(at:role=="pg" ? 0:1)
        }
        monitorReadingSummary?.stringValue=monitorReadings.compactSummary(for:monitorRole,at:Date())
        monitorFeedback?.stringValue=text
        contentTabs?.selectTabViewItem(withIdentifier:"monitor-controls")
    }
    @objc func setMonitorPercentage() {
        let role=monitorRole
        let available={ [unowned self] in
            monitorControlReason(self.read("health.json"),self.read("control.json"),role,self.busy)
                ?? percentageSupportReason(self.visibleCapabilities,checking:self.checkingCapabilities)
        }
        guard available()==nil else{return}
        let chooser=PercentChooser(role:role,readings:monitorReadings,fontSize:CGFloat([16,20,24][textSizeIndex()]),availability:available)
        guard let arguments=chooser.run() else{return}
        if let reason=available() {message("Monitor setting unavailable",reason);return}
        execute(arguments)
    }
    @objc func toggleMonitorSupport(_ sender:NSButton) {monitorSupportDetails?.isHidden=sender.state != .on}
    @objc func openBrightnessPresets() {execute(["brightness-list","--monitor",monitorRole])}
    func chooseBrightness(_ json:String,expectedMonitor:String) {
        guard let report=brightnessEntries(json,expectedMonitor) else {message("Brightness presets unavailable","The list could not be validated. No preset was changed; refresh after checking health.");return}
        let role=report.monitor
        let chooser=BrightnessChooser(monitor:role,entries:report.entries,fontSize:CGFloat([16,20,24][textSizeIndex()]),unavailable:monitorControlReason(read("health.json"),read("control.json"),role,busy),canRemove:controlsAvailable(read("control.json")) && !busy)
        let action=chooser.run()
        guard [0,1,2].contains(action) else{return}
        if action != 2,let reason=monitorControlReason(read("health.json"),read("control.json"),role,busy) {message("Brightness action unavailable",reason);return}
        if action==1 {
            let dialog=PresetDialog(fontSize:CGFloat([16,20,24][textSizeIndex()]),brightnessMonitor:role)
            if let arguments=dialog.run() {execute(arguments)}
        } else if let entry=chooser.selected {
            execute([action==0 ? "brightness-apply":"brightness-remove","--monitor",role,"--preset",entry.name,"--fingerprint",entry.revision])
        }
    }
    @objc func selectMonitor(_ sender:NSPopUpButton) {
        monitorRole=sender.indexOfSelectedItem==0 ? "pg":"benq"
        monitorReadingSummary?.stringValue=monitorReadings.compactSummary(for:monitorRole,at:Date())
        monitorFeedback?.stringValue=monitorReadings.previous(for:monitorRole) ?? "No readback for this selection yet. Read settings to inspect it."
        refresh()
    }
    @objc func adjustMonitor(_ sender:NSButton) {
        guard let key=sender.identifier?.rawValue else{return}
        if key=="read" {execute(["monitor-settings","--monitor",monitorRole]);return}
        let parts=key.split(separator:":").map(String.init)
        guard parts.count==2 else{return}
        execute(["monitor-adjust","--monitor",monitorRole,"--feature",parts[0],"--step",parts[1]])
    }
    @objc func selectSpeaker(_ sender:NSPopUpButton) {
        guard let profile=sender.identifier?.rawValue,let speaker=sender.selectedItem?.representedObject as? String else{return}
        execute(["speaker","--profile",profile,"--speaker",speaker])
    }
    @objc func togglePause(_ sender:NSButton) {execute([automationPaused(read("control.json")) ? "resume":"pause"])}
    @objc func changeTextSize(_ sender:NSSegmentedControl) {
        let index=min(2,max(0,sender.selectedSegment))
        if !demo {UserDefaults.standard.set(index,forKey:"statusTextSize")}
        displayTextIndex=index;applyTextSize(index)
    }
    @objc func openControls(_ sender:NSButton){refresh();item.menu?.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.height),in:sender)}
    @objc func panelAction(_ sender:NSButton){if let action=sender.identifier?.rawValue {
        if action=="preview-keep" || action=="preview-revert" {if let token=previewToken {execute([action,"--token",token])}}
        else {execute([action])}
    }}
    @objc func runRecoveryAction(_ sender:NSButton) {
        guard let args=currentRecoveryArguments(presentedRecoveryAction,read("health.json"),read("control.json"),busy) else {
            operationResult="Recovery status changed or a command is still running. Review the current action before retrying."
            refresh();return
        }
        execute(args)
    }
    func read(_ name:String)->[String:Any] {
        if demo {return demoState(demoScenario,name,Date().timeIntervalSince1970)}
        return readMenuState(root.appendingPathComponent(name),allowMissing:name=="control.json") ?? (name=="control.json" ? ["_read_unavailable":true]:[:])
    }
    func applicationDidFinishLaunching(_ notification:Notification) {
        if !demo {
            ownership=MenuOwnership(path:root.appendingPathComponent("menu.lock").path)
            guard ownership != nil else {
                FileHandle.standardError.write(Data("Menu already running or ownership lock unavailable.\n".utf8))
                if let identifier=Bundle.main.bundleIdentifier {
                    for app in NSRunningApplication.runningApplications(withBundleIdentifier:identifier) where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                        app.activate(options:[.activateIgnoringOtherApps])
                    }
                }
                NSApp.terminate(nil);return
            }
        }
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu=makeEditingMenu(allowClipboard:!demo)
        item=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        item.button?.image=NSImage(systemSymbolName:"display.2",accessibilityDescription:"Display Bridge")
        if !demo {
        UNUserNotificationCenter.current().delegate=self
        let repair=UNNotificationAction(identifier:"repair",title:"Repair audio",options:[])
        let inspect=UNNotificationAction(identifier:"inspect",title:"Check health",options:[])
        UNUserNotificationCenter.current().setNotificationCategories([UNNotificationCategory(identifier:"failure",actions:[repair],intentIdentifiers:[],options:[]),UNNotificationCategory(identifier:"state-failure",actions:[inspect],intentIdentifiers:[],options:[])])
        }
        timer=Timer(timeInterval:2,repeats:true){[weak self] _ in self?.refresh()}
        if let timer=timer {RunLoop.main.add(timer,forMode:.common)}
        refresh()
        if demo {showPanel();return}
        checkPresetSupport()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options:[.alert]){_,error in
                    if let error=error {FileHandle.standardError.write(Data((error.localizedDescription+"\n").utf8))}
                }
            }
        }
    }
    func add(_ menu:NSMenu,_ title:String,_ args:[String]?=nil,checked:Bool=false) {
        let entry=NSMenuItem(title:title,action:args == nil ? nil : #selector(act(_:)),keyEquivalent:"")
        entry.target=self;entry.representedObject=args;entry.state=checked ? .on:.off;entry.isEnabled=args != nil && !busy && (controlsUsable || safeWithoutControls(args?.first ?? ""));menu.addItem(entry)
    }
    func refresh() {
        let health=read("health.json"),control=read("control.json")
        controlsUsable=controlsAvailable(control)
        modeStatus?.stringValue=displayReading.notice(health,refreshing:displayRefreshing)
        let fresh=statusFresh(health)
        let prefix=detailPrefix(health,control)
        let state=fresh ? health["status"] as? String ?? "Unknown" : "Controller unavailable"
        item.button?.title=state == "degraded" || state == "state-error" || !fresh || !controlsUsable ? " !" : ""
        item.button?.toolTip="Display Bridge: \(controlsUsable ? state:"Controls unavailable")"
        let tracked=commandSummary(health,control)
        var progress=operationResult
        if let started=operationStarted {
            let elapsed=Int(max(0,ProcessInfo.processInfo.systemUptime-started))
            progress="\(operationName)… \(elapsed)s in this phase. Phase deadline: \(Int(operationDeadline))s."
        }
        if !controlsUsable {progress += "\nSaved controls are unreadable. Setting changes are disabled; check health."}
        let sections=statusSections(health,control)
        for (index,fields) in overviewFields.enumerated() where index<sections.count {
            var body=sections[index].body
            if index==0 {
                if !tracked.isEmpty {body += "\n\n"+tracked}
                if !progress.isEmpty {body += "\n\n"+progress}
            }
            if fields.1.stringValue != body {fields.1.stringValue=body;fields.1.setAccessibilityValue(body)}
        }
        presentedRecoveryAction=recoveryAction(health,control)
        recoveryButton?.isHidden=presentedRecoveryAction==nil
        recoveryButton?.title=presentedRecoveryAction?.title ?? "Check health"
        recoveryButton?.isEnabled = !busy && presentedRecoveryAction != nil
        pauseButton?.title=automationPaused(control) ? "Resume":"Pause"
        pauseButton?.isEnabled = !busy && controlsUsable
        var detail=dashboard(health,control)
        if !tracked.isEmpty {detail=tracked+"\n\n"+detail}
        if !progress.isEmpty {detail=progress+"\n\n"+detail}
        let lastPreview=read("preview-status.json")
        if !state.hasPrefix("preview-"),let error=lastPreview["error"] as? String {detail += "\n\nLast size preview: \(error)"}
        reportRefreshButton?.title=detailReport=="enrollment-review" ? "Review this Mac…":"Refresh"
        enrollmentReviewButton?.isHidden=detailReport != "setup"
        reportSelector?.isEnabled = !busy
        copySummaryButton?.isHidden=detailReport != "support-summary"
        copySummaryButton?.isEnabled = !busy && reviewedSummary.body(for:detailReport) != nil
        reportStatus?.stringValue = busy ? progress : (!copySummaryNotice.isEmpty ? copySummaryNotice:(detailReport=="status" ? "Live controller status":detailReport=="enrollment-review" ? "Read-only enrollment review; no configuration saved":"Snapshot report; use Refresh to inspect again."))
        if detailReport=="status",let text=panelText,text.string != detail {
            let selection=text.selectedRange()
            let origin=text.enclosingScrollView?.contentView.bounds.origin
            text.string=detail
            let length=(detail as NSString).length
            if selection.location<=length {text.setSelectedRange(NSRange(location:selection.location,length:min(selection.length,length-selection.location)))}
            if let origin=origin {text.enclosingScrollView?.contentView.scroll(to:origin)}
        }
        compatibilityLabel?.stringValue=presetCompatibilitySummary(visibleCapabilities,checking:checkingCapabilities)
        compatibilityButton?.isEnabled = !checkingCapabilities && !busy && !demo
        monitorReadingSummary?.stringValue=monitorReadings.compactSummary(for:monitorRole,at:Date())
        let monitorUnavailable=monitorControlReason(health,control,monitorRole,busy)
        monitorReason?.stringValue=monitorUnavailable ?? "Ready to adjust this monitor."
        for button in monitorButtons {button.isEnabled=monitorUnavailable==nil}
        let supportReason=percentageSupportReason(visibleCapabilities,checking:checkingCapabilities)
        percentageButton?.isEnabled=monitorUnavailable==nil && supportReason==nil
        percentageButton?.toolTip=monitorUnavailable ?? supportReason
        percentageReason?.stringValue=supportReason ?? ""
        percentageReason?.isHidden=supportReason==nil
        monitorSelector?.isEnabled = !busy
        for button in panelActions {
            let action=button.identifier?.rawValue ?? "doctor"
            button.isEnabled = !busy && (controlsUsable || safeWithoutControls(action)) && (action != "brightness-list" || PresetCommands.brightness.isSubset(of:visibleCapabilities ?? []))
        }
        let preferences=control["speaker_preferences"] as? [String:String] ?? [:]
        for (profile,popup) in speakerPopups {
            if !controlsUsable {popup.selectItem(at:-1);popup.isEnabled=false;continue}
            let wanted=preferences[profile] ?? (profile=="away" ? "fallback":profile=="benq" ? "benq":"pg")
            if let entry=popup.itemArray.first(where:{$0.representedObject as? String==wanted}) {popup.select(entry)}
            else {popup.selectItem(at:-1)}
            popup.isEnabled = !busy && controlsUsable
        }
        let currentAudio=health["audio"] as? [String:Any] ?? [:]
        let selectedOutput=currentAudio["selected"] as? [String:Any] ?? [:]
        let override=AudioOverridePresentation(control)
        audioOverrideButton?.title=override.title
        audioOverrideButton?.identifier=NSUserInterfaceItemIdentifier(override.action)
        var audioDescription=prefix+"Selected output: \(selectedOutput["name"] as? String ?? "Not reported")\n\(override.summary)\nExternal headsets remain under your control."
        if !controlsUsable {audioDescription="Saved controls are unreadable. Check health before changing audio preferences.\n\n"+audioDescription}
        audioInfo?.stringValue=audioDescription
        let reason=audioRepairReason(health,control,busy)
        audioRepair?.isEnabled=reason==nil
        audioReason?.stringValue=(reason ?? "Repair uses the existing recovery policy. Listen afterward to confirm sound.")+(listeningResponse.isEmpty ? "":"\n\n"+listeningResponse)

        let preview=health["preview"] as? [String:Any] ?? [:]
        previewToken=preview["token"] as? String
        previewConfirmationRow?.isHidden=preview["state"] as? String != "preview"
        for button in previewActions {
            let action=button.identifier?.rawValue
            if action=="preview-options" {button.isEnabled = !busy && controlsUsable && fresh && state=="ready" && health["profile"] as? String == "extended" && !automationPaused(control)}
            else {
                if action=="preview-keep" {button.title="Keep (\(previewRemaining(health))s)"}
                button.isHidden = preview["state"] as? String != "preview";button.isEnabled = !busy && (controlsUsable || action=="preview-revert") && fresh && previewToken != nil && preview["state"] as? String == "preview" && previewRemaining(health)>0}
        }
        if !demo {
        notify(health,fresh:fresh)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            var data:[String:Any]=["updated_at":Date().timeIntervalSince1970,"pid":ProcessInfo.processInfo.processIdentifier,"app_version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","notification_authorization":settings.authorizationStatus.rawValue,"status":state]
            if let fingerprint=Bundle.main.object(forInfoDictionaryKey:"DisplayBridgeSourceFingerprint") as? String {data["source_fingerprint"]=fingerprint}
            if let bytes=try? JSONSerialization.data(withJSONObject:data){try? bytes.write(to:self.root.appendingPathComponent("menu-health.json"),options:.atomic)}
        }
        }
        if menuOpen{return}
        let compact=NSMenu();compact.delegate=self
        add(compact,"Display Bridge · Mac \(health["host"] as? String ?? "?")")
        add(compact,dashboard(health,control).components(separatedBy:"\n").first ?? "Status unavailable")
        add(compact,statusAge(health))
        for section in sections where section.title=="PG42UQ" || section.title=="BenQ RD280UG" {
            add(compact,section.title+": "+(section.body.components(separatedBy:"\n").first ?? "Unknown"))
        }
        let audio=health["audio"] as? [String:Any] ?? [:],selected=audio["selected"] as? [String:Any] ?? [:]
        add(compact,"\(prefix)Speaker: \(selected["name"] as? String ?? "—")")
        if !progress.isEmpty {add(compact,progress)}
        compact.addItem(.separator())
        add(compact,"Open Display Bridge…",["panel"])
        add(compact,"Setup readiness…",["setup"])
        add(compact,"Last installation…",["installation-status"])
        let paused=automationPaused(control)
        add(compact,paused ? "Resume automation":"Pause automation",[paused ? "resume":"pause"])
        if fresh,let token=previewToken,preview["state"] as? String == "needs-repair" {
            add(compact,"Retry size restoration",["preview-repair","--token",token])
        }
        if let token=previewToken,previewRemaining(health)>0 {
            add(compact,"Keep preview size (\(previewRemaining(health))s)",["preview-keep","--token",token])
            add(compact,"Revert preview size",["preview-revert","--token",token])
        }
        let menu=NSMenu();menu.delegate=self
        let rotation=health["rotation"] as? [String:Any] ?? [:]
        add(menu,"Pause for 15 minutes",["pause-for","--minutes","15"])
        if rotation["enabled"] as? Bool == true {
            let automatic=control["auto_rotate"] as? Bool ?? true
            add(menu,"Automatic BenQ rotation",[automatic ? "rotation-manual":"rotation-auto"],checked:controlsUsable && automatic)
        }
        if paused,let until=control["pause_until"] as? Double,until>0 {
            add(menu,"Resumes at \(Date(timeIntervalSince1970:until).formatted(date:.omitted,time:.shortened))")
        }
        let manual=(control["audio_manual_until"] as? Double ?? 0)>Date().timeIntervalSince1970
        add(menu,"Preserve current audio for 30 minutes",["audio-manual","--minutes","30"],checked:manual)
        add(menu,"Resume automatic audio",["audio-auto"])
        add(menu,"Repair audio",audioRepairReason(health,control,busy)==nil ? ["repair-audio"]:nil)
        for (profile,label,defaultSpeaker) in [("extended","Both monitors here","pg"),("pg","Only PG here","pg"),("benq","Only BenQ here","benq"),("away","Both monitors away","fallback")] {
            let entry=NSMenuItem(title:"Speaker: \(label)",action:nil,keyEquivalent:"");let sub=NSMenu()
            for (speaker,title) in speakerChoices(profile) {
                add(sub,title,["speaker","--profile",profile,"--speaker",speaker],checked:controlsUsable && (preferences[profile] ?? defaultSpeaker)==speaker)
            };entry.submenu=sub;menu.addItem(entry)
        }
        menu.addItem(.separator())
        add(menu,"Preview display size…",fresh && state=="ready" && health["profile"] as? String == "extended" && !paused ? ["preview-options"]:nil)
        let inputs=health["inputs"] as? [String:Int] ?? [:]
        let hostB=health["host"] as? String == "B"
        for (role,label,localInput) in [("pg","PG42UQ",hostB ? 18:17),("benq","BenQ",hostB ? 15:19)] {
            let entry=NSMenuItem(title:"\(label) brightness and volume",action:nil,keyEquivalent:"")
            let sub=NSMenu()
            let enabled=monitorControlReason(health,control,role,busy)==nil
            add(sub,"Read current settings…",fresh && inputs[role]==localInput ? ["monitor-settings","--monitor",role]:nil)
            if !enabled {add(sub,"Available when this monitor shows this Mac and is ready")}
            for (feature,name) in [("luminance","Brightness"),("volume","Speaker volume")] {
                for step in [-5,5] {
                    add(sub,"\(name) \(step>0 ? "+5":"−5")%",enabled ? ["monitor-adjust","--monitor",role,"--feature",feature,"--step",String(step)]:nil)
                }
            }
            entry.submenu=sub;menu.addItem(entry)
        }
        add(menu,"Preview support summary…",["support-summary"])
        add(menu,"Save private diagnostic report…",["diagnostics"])
        add(menu,"Check system health…",["doctor"])
        add(menu,"Show transition timing summary…",["history"])
        add(menu,"Show monitor communication history…",["ddc-history"])
        add(menu,"Enable failure notifications…",["notifications"])
        let advanced=NSMenuItem(title:"Advanced",action:nil,keyEquivalent:"")
        advanced.submenu=menu;compact.addItem(advanced)
        compact.addItem(.separator())
        add(compact,"Quit menu bar (automation continues)",["quit"])
        item.menu=compact
    }
    func menuWillOpen(_ menu:NSMenu){openMenus.insert(ObjectIdentifier(menu))}
    func menuDidClose(_ menu:NSMenu){openMenus.remove(ObjectIdentifier(menu))}
    @objc func act(_ sender:NSMenuItem){if let args=sender.representedObject as? [String]{execute(args)}}
    func execute(_ args:[String]) {
        if !controlsAvailable(read("control.json")),!safeWithoutControls(args.first ?? "") {
            message("Saved controls unavailable","Check health and restore valid control settings before changing preferences or starting a preview. Recovery journals were preserved.");return
        }
        if args==["audio-test-prompt"] {
            guard !busy else{return}
            let body=demo ? "Demo only: no sound will play. Continue to inspect the listening-response dialog.":"A short, quiet sample plays through the currently selected output. Its volume and selection will not be changed. You will be asked whether you heard it."
            let dialog=ListeningDialog(title:"Test selected output",body:body,buttons:["Cancel",demo ? "Continue demo":"Play sample"],fontSize:CGFloat([16,20,24][textSizeIndex()]))
            if dialog.run()==1 {
                listeningResponse=""
                if demo {presentListeningResponse("Synthetic output")} else {execute(["audio-test"])}
            }
            return
        }
        if args==["panel"]{showPanel();return}
        if args==["quit"]{NSApp.terminate(nil);return}
        if args==["enrollment-review"] {
            guard !busy else{return}
            let chooser=EnrollmentReviewDialog(fontSize:CGFloat([16,20,24][textSizeIndex()]))
            if let host=chooser.run() {execute(["capture-review","--host",host])}
            return
        }
        if demo,args==["installation-status"] {
            let report=demoInstallationReport(demoScenario,Date().timeIntervalSince1970)
            if let data=try? JSONSerialization.data(withJSONObject:report),let json=String(data:data,encoding:.utf8) {showReport("installation-status","Synthetic installation report; no installer was run.\n\n"+installationSummary(json))}
            return
        }
        if demo,args.first=="capture-review",let host=args.last {
            let monitors:[[String:Any]]=["pg","benq"].map{role in ["monitor":role,"width":1280,"height":720,"pixelWidth":2560,"pixelHeight":1440,"rotation":0,"local_input":role=="pg" ? (host=="A" ? 17:18):(host=="A" ? 19:15)]}
            let report:[String:Any]=["read_only":true,"status":"review-ready","host":host,"monitors":monitors,"audio_routes":["pg","benq","built-in"]]
            if let data=try? JSONSerialization.data(withJSONObject:report),let json=String(data:data,encoding:.utf8) {showReport("enrollment-review","Synthetic review; no hardware inspected.\n\n"+enrollmentReviewSummary(json,host))}
            return
        }
        if demo,demoScenario=="monitor-response-error",args.first=="monitor-settings" {
            let fixture=#"{"monitor":"pg","read_only":true,"settings":{"luminance":{"value":30,"maximum":100,"percent":30},"volume":{"value":40,"maximum":100,"percent":40}}}"#
            presentMonitorResponse(CommandResult(output:fixture,code:0),["monitor-settings","--monitor","pg"])
            presentMonitorResponse(CommandResult(output:#"{"monitor":"unknown","settings":{}}"#,code:0),args)
            refresh();return
        }
        if demo,args.first=="brightness-list" {
            let role=args.last ?? "pg"
            var report:[String:Any]=["read_only":true,"monitor":role,"presets":[["name":"Reading","monitor":role,"value":30,"maximum":100,"revision":String(repeating:"a",count:64)],["name":"Evening","monitor":role,"value":15,"maximum":100,"revision":String(repeating:"b",count:64)]]]
            if demoScenario=="brightness-empty" {report["presets"]=[] }
            if let data=try? JSONSerialization.data(withJSONObject:report),let json=String(data:data,encoding:.utf8) {chooseBrightness(json,expectedMonitor:role)}
            return
        }
        if demo,args==["setup"] {
            let report:[String:Any]=["read_only":true,"status":"warning","checks":[["name":"Host enrollment","status":"ok","detail":"Mac A; expected local inputs PG=17, BenQ=19. Synthetic enrollment."],["name":"Rotation enrollment","status":"warning","detail":"Portrait profile is missing.","action":"Capture the missing orientation on this Mac through the installer; keep existing profiles."]],"limits":"Synthetic fixture. Nothing was read, changed or uploaded."]
            if let data=try? JSONSerialization.data(withJSONObject:report),let json=String(data:data,encoding:.utf8) {showReport("setup",setupSummary(json,["BetterDisplay.app","Unrelated.app"]))}
            return
        }
        if demo,args==["history"] {
            let report:[String:Any]=["history_available":true,"profiles":["pg":["count":1,"failed_attempts":0,"seconds":["total":["count":1,"median":2.5,"max":2.5,"p95":2.5]]],"benq":["count":0,"failed_attempts":1,"seconds":[:]]],"recent_events":[["profile":"benq","result":"failed","seconds":["total":2.4,"layout_apply":0.4],"failed_phase":"audio","failed_phase_seconds":2.0], ["profile":"pg","result":"ready","seconds":["total":2.5,"audio":1.2,"layout_apply":0.8]]]]
            if let data=try? JSONSerialization.data(withJSONObject:report),let json=String(data:data,encoding:.utf8) {showReport("history","Synthetic examples; not measurements.\n\n"+timingSummary(json))}
            return
        }
        if demo,args.count==1,detailReports.contains(where:{$0.0==args[0]}) {
            showReport(args[0],"Synthetic report for interface inspection. No hardware or local diagnostic data was read.\n\nExample: two completed transitions; application time 2.0 seconds. These are demo values, not measurements.")
            return
        }
        if args==["preset-save-prompt"] {savePresetPrompt();return}
        if demo && args==["preview-options"] {
            let modes:[String:Any] = ["pg":["width":1920,"height":1080,"pixelWidth":3840,"pixelHeight":2160],"benq":["width":1920,"height":1280,"pixelWidth":3840,"pixelHeight":2560]]
            var report:[String:Any] = ["preview_seconds":[20,40],"rotation":0,"options":[["label":"Current size","size":"current","fingerprint":"demo","modes":modes],["label":"Larger interface","size":"larger","fingerprint":"demo-larger","modes":["pg":["width":1536,"height":864,"pixelWidth":3072,"pixelHeight":1728],"benq":["width":1536,"height":1024,"pixelWidth":3072,"pixelHeight":2048]]]],
                "presets":[["name":"Reading","rotation":0,"revision":"demo","available":true,"fingerprint":"demo","modes":modes],
                           ["name":"Reading","rotation":90,"revision":"demo","available":false,"reason":"Preset belongs to the other orientation"]]]
            if var options=report["options"] as? [[String:Any]] {
                options[0]["physical_size_percent"]=154.3
                options.append(["label":"Match PG size to BenQ","size":"match-benq","fingerprint":"demo-match","physical_size_percent":98.5,
                    "modes":["pg":["width":3008,"height":1692,"pixelWidth":6016,"pixelHeight":3384],"benq":modes["benq"]!]])
                report["options"]=options
            }
            if demoScenario=="presets-error" {report["presets"]=[];report["preset_error"]="Saved presets are unreadable. The original file was preserved. Ordinary size previews remain available."}
            if let data=try? JSONSerialization.data(withJSONObject:report),let text=String(data:data,encoding:.utf8) {chooseSize(text)}
            return
        }
        if demo && args==["display-info"] {
            if demoScenario=="display-refresh-failed" {displayReading.failed=true;refresh();return}
            if let data=try? JSONSerialization.data(withJSONObject:demoDisplayReport(demoScenario)),let json=String(data:data,encoding:.utf8) {acceptDisplayReading(json)}
            return
        }
        if demo {message("Hardware-free demo","This preview uses synthetic status. Monitor, audio, diagnostic and notification actions are disabled.");return}
        if args==["notifications"] {
            UNUserNotificationCenter.current().requestAuthorization(options:[.alert]){granted,error in
                DispatchQueue.main.async {self.message(granted ? "Failure notifications enabled":"Notifications are disabled",error?.localizedDescription ?? "You can change this in System Settings → Notifications → Display Auto.")}
            };return
        }
        guard !busy else{return}
        if args.first=="support-summary" {reviewedSummary.clear();copySummaryNotice=""}
        displayRefreshing=args.first=="display-info"
        busy=true;operationStarted=ProcessInfo.processInfo.systemUptime
        operationName="Preparing command";operationDeadline=45;operationResult=""
        showPanel()
        DispatchQueue.global().async {
            let response=runCompatibleMenuCommand(args==["setup"] ? ["doctor"]:args,onPhase:{name,deadline in
                let started=ProcessInfo.processInfo.systemUptime
                DispatchQueue.main.async {
                    self.operationName=name;self.operationDeadline=deadline;self.operationStarted=started;self.refresh()
                }
            }){arguments,timeout,limit in runMenuCommand(self.command,arguments,timeout:timeout,outputLimit:limit)}
            let result=response.output,code=response.code
            DispatchQueue.main.async {
                self.busy=false;self.operationStarted=nil
                if args.first=="display-info" {self.displayRefreshing=false;if code != 0 {self.displayReading.failed=true}}
                if code != 0 {self.operationResult=code==124 ? "Command timed out; inspect status before retrying.":"Command failed; see the error for details."}
                else if let data=result.data(using:.utf8),let response=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],response["requested"] != nil {
                    self.operationResult=response["request_id"] == nil ? "Request saved; this controller does not report command completion.":""
                } else {self.operationResult="Command returned. See the result and current status below."}
                self.refresh()
                if MonitorResponse.commands.contains(args.first ?? "") {
                    self.presentMonitorResponse(response,args)
                    if code != 0 {self.message("Action could not complete",result)}
                }
                else if code != 0 {self.message("Action could not complete",result)}
                else if args.first=="audio-test" {
                    guard let output=listeningOutput(result) else {self.message("Listening check unavailable","The result could not be validated. No audible result was recorded.");return}
                    self.presentListeningResponse(output)
                }
                else if args.first=="installation-status" {self.showReport("installation-status",installationSummary(result))}
                else if args.first=="capture-review" {self.showReport("enrollment-review",enrollmentReviewSummary(result,args.last ?? ""))}
                else if args.first=="diagnostics" {NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:result.trimmingCharacters(in:.whitespacesAndNewlines))])}
                else if args.first=="support-summary" {self.showReport("support-summary","Review before sharing. This report is not uploaded automatically.\n\n"+result)}
                else if args.first=="history" {self.showReport("history",timingSummary(result))}
                else if args.first=="display-info" {self.acceptDisplayReading(result)}
                else if args.first=="doctor" {self.showReport("doctor",healthSummary(result))}
                else if args.first=="setup" {self.showReport("setup",setupSummary(result,NSWorkspace.shared.runningApplications.compactMap{$0.bundleURL?.lastPathComponent}))}
                else if args.first=="ddc-history" {self.showReport("ddc-history",ddcSummary(result))}
                else if args.first=="preset-remove",let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value["removed"] as? Bool == true {
                    self.operationResult="Preset ‘\(value["name"] as? String ?? "")’ removed for \(value["rotation"] as? Int == 90 ? "portrait":"landscape"). Display settings were not changed."
                }
                else if args.first=="preset-save",let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value["saved"] as? Bool == true {
                    self.operationResult="Preset ‘\(value["name"] as? String ?? "")’ saved for \(value["rotation"] as? Int == 90 ? "portrait":"landscape"). Display settings were not changed."
                }
                else if args.first=="brightness-list" {self.chooseBrightness(result,expectedMonitor:args.last ?? "")}
                else if ["brightness-save","brightness-remove"].contains(args.first ?? ""),let data=result.data(using:.utf8),let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value[args.first=="brightness-save" ? "saved":"removed"] as? Bool == true {
                    self.showMonitorResult("Brightness preset ‘\(value["name"] as? String ?? "")’ \(args.first=="brightness-save" ? "saved":"removed"). No brightness change was requested.",value["monitor"] as? String)
                }
                else if args.first=="preview-options" {self.chooseSize(result)}
                else if args.first?.hasPrefix("preview-")==true {self.showPanel()}
                self.refresh()
            }
        }
    }
    func presentListeningResponse(_ output:String) {
        let body=demo ? "Demo response only: no audio was played. Choose an answer to inspect how a past observation is displayed.":"Output: \(output). Playback completed, but only your response can confirm whether it was audible."
        let dialog=ListeningDialog(title:"Did you hear the sample?",body:body,buttons:["Not sure","Heard it","No sound"],fontSize:CGFloat([16,20,24][textSizeIndex()]))
        let label=listeningAnswerLabel(dialog.run())
        listeningResponse=(demo ? "Synthetic listening response: ":"Last listening check: ")+"\(output) · \(label) (your response). This is a past observation, not a current audio check."
        refresh()
    }
    func message(_ title:String,_ body:String){
        NSApp.activate(ignoringOtherApps:true);let alert=NSAlert();alert.messageText=title
        if body.count>1000 {
            let scroll=NSScrollView(frame:NSRect(x:0,y:0,width:480,height:340));scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
            let text=NSTextView(frame:scroll.bounds);text.isEditable=false;text.isSelectable=true;text.font=NSFont.systemFont(ofSize:13);text.string=body
            text.isVerticallyResizable=true;text.isHorizontallyResizable=false;text.textContainer?.widthTracksTextView=true
            scroll.documentView=text;alert.accessoryView=scroll
        } else {alert.informativeText=body}
        alert.runModal()
    }
    func savePresetPrompt() {
        let dialog=PresetDialog(fontSize:CGFloat([16,20,24][textSizeIndex()]))
        if let arguments=dialog.run() {execute(arguments)}
    }
    func removePresetPrompt(_ presets:[[String:Any]]) {
        guard !presets.isEmpty else{return}
        let dialog=PresetDialog(fontSize:CGFloat([16,20,24][textSizeIndex()]),presets:presets)
        if let arguments=dialog.run() {execute(arguments)}
    }
    func chooseSize(_ json:String){
        guard let data=json.data(using:.utf8),let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let relative=report["options"] as? [[String:Any]] else {message("Size preview unavailable","No qualified size choices were returned.");return}
        let presetError=report["preset_error"] as? String
        var choices=relative
        var unavailable:[String]=[]
        for preset in report["presets"] as? [[String:Any]] ?? [] {
            let name=preset["name"] as? String ?? "Unnamed"
            if preset["available"] as? Bool == true {
                var option=preset;option["label"]="Preset: "+name;option["preset"]=name;choices.append(option)
            } else {unavailable.append(name+" — "+(preset["rotation"] as? Int == 90 ? "Portrait":"Landscape")+": "+(preset["reason"] as? String ?? "Unavailable"))}
        }
        guard !choices.isEmpty else {message("Size preview unavailable","No qualified choices are currently available.");return}
        NSApp.activate(ignoringOtherApps:true)
        let presets=report["presets"] as? [[String:Any]] ?? []
        let current=relative.first(where:{$0["size"] as? String == "current"}) ?? [:]
        var notes:[String]=[]
        if let error=presetError {notes.append("Saved presets unavailable\n"+error)}
        if !unavailable.isEmpty {notes.append("Unavailable presets\n"+unavailable.joined(separator:"\n"))}
        let canSave=visibleCapabilities?.contains("preset-save")==true
        let canRemove=visibleCapabilities?.contains("preset-remove")==true
        if !canSave || !canRemove {notes.append(presetCompatibilitySummary(visibleCapabilities,checking:checkingCapabilities)+" Check support in Controls.")}
        let chooser=SizeChooser(choices:choices,current:current,notes:notes.joined(separator:"\n\n"),orientation:report["rotation"] as? Int == 90 ? "Portrait":"Landscape",fontSize:CGFloat([16,20,24][textSizeIndex()]),canSave:presetError==nil && canSave,canRemove:presetError==nil && !presets.isEmpty && canRemove,durations:previewDurations(report))
        let response=chooser.run()
        if response==1,presetError==nil {savePresetPrompt();return}
        if response==2,presetError==nil {removePresetPrompt(presets);return}
        let index=chooser.selectedIndex
        guard response==0,index>=0,index<choices.count,let fingerprint=choices[index]["fingerprint"] as? String else {return}
        let durationArguments=chooser.previewSeconds==20 ? []:["--preview-seconds",String(chooser.previewSeconds)]
        if let preset=choices[index]["preset"] as? String {execute(["preview-start","--preset",preset,"--fingerprint",fingerprint]+durationArguments)}
        else if let size=choices[index]["size"] as? String {execute(["preview-start","--size",size,"--fingerprint",fingerprint]+durationArguments)}
    }
    func notify(_ health:[String:Any],fresh:Bool) {
        guard fresh else{return}
        let defaults=UserDefaults.standard
        let state=health["status"] as? String ?? ""
        let center=UNUserNotificationCenter.current()
        if state=="ready" || state=="inactive-setup" {
            if !failureAlerts.sent.isEmpty || failureAlerts.pending != nil {
                failureAlerts.clear();defaults.removeObject(forKey:"failureIncidents")
                center.removePendingNotificationRequests(withIdentifiers:["display-recovery"])
                center.removeDeliveredNotifications(withIdentifiers:["display-recovery"])
            }
            return
        }
        guard let incident=failureIncident(health),let body=failureNotificationBody(health),let attempt=failureAlerts.reserve(incident) else{return}
        let content=UNMutableNotificationContent();content.title="Display Bridge needs attention"
        content.body=body
        content.categoryIdentifier=state=="state-error" || state=="preview-needs-repair" ? "state-failure":"failure"
        content.userInfo=["incident":incident]
        center.getNotificationSettings{settings in
            DispatchQueue.main.async {
                guard self.failureAlerts.current(attempt) else{return}
                let current=self.read("health.json")
                guard settings.authorizationStatus == .authorized,statusFresh(current),failureIncident(current)==incident else {
                    self.failureAlerts.finish(attempt,success:false);return
                }
                center.add(UNNotificationRequest(identifier:"display-recovery",content:content,trigger:nil)){error in
                    DispatchQueue.main.async {
                        self.failureAlerts.finish(attempt,success:error==nil)
                        defaults.set(self.failureAlerts.sent,forKey:"failureIncidents")
                    }
                }
            }
        }
    }
    func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping ()->Void){
        if let command=notificationCommand(response.actionIdentifier) {
            DispatchQueue.main.async {
                let health=self.read("health.json")
                let incident=response.notification.request.content.userInfo["incident"] as? String
                let staleRepair=command=="repair-audio" && (incident==nil || !statusFresh(health) || failureIncident(health) != incident)
                if self.busy || staleRepair {self.showPanel()}
                else {self.execute([command])}
                completionHandler()
            }
        } else {completionHandler()}
    }
    func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void){completionHandler([.banner,.list])}
}
