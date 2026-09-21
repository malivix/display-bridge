// SPDX-License-Identifier: MIT
import AppKit
import Darwin

final class SetupApp:NSObject,NSApplicationDelegate,NSWindowDelegate {
    let demo=Bundle.main.object(forInfoDictionaryKey:"DisplayBridgeDemo") as? Bool == true
    let window=NSWindow(contentRect:NSRect(x:0,y:0,width:720,height:740),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
    let role=NSPopUpButton(),prepared=NSButton(checkboxWithTitle:"Both monitors are prepared",target:nil,action:nil)
    let reviewButton=NSButton(),installButton=NSButton(),text=NSTextView(),banner=NSTextField(wrappingLabelWithString:"")
    var scalable:[NSControl]=[]
    let sizes=NSSegmentedControl(labels:["Standard","Large","Largest"],trackingMode:.selectOne,target:nil,action:nil)
    var selection=SetupSelection(),checking=false,task:Process?,log:FileHandle?,logURL:URL?,timer:Timer?
    var launchedAt=0.0
    var package:URL {Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Source")}
    var python:URL? {(Bundle.main.object(forInfoDictionaryKey:"DisplayBridgePython") as? String).map{URL(fileURLWithPath:$0)}}
    var progressURL:URL {FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/display-auto/install-progress.json")}
    func applicationDidFinishLaunching(_ note:Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu=NSMenu(),appItem=NSMenuItem(),appMenu=NSMenu()
        appMenu.addItem(NSMenuItem(title:"Quit Display Bridge Setup",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"))
        appItem.submenu=appMenu;menu.addItem(appItem);NSApp.mainMenu=menu
        window.title=demo ? "Display Bridge Setup — Demo":"Display Bridge Setup"
        window.minSize=NSSize(width:640,height:640);window.delegate=self;window.isReleasedWhenClosed=false
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),stack.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-20)])
        let intro=NSTextField(wrappingLabelWithString:"Choose this Mac's role. Prepare exactly PG42UQ and BenQ RD280UG in extended mode, both showing this Mac, with fixed 120 Hz and HDR off. Existing enrolled sizes are preserved on an ordinary upgrade.")
        intro.font = .systemFont(ofSize:20);stack.addArrangedSubview(intro);intro.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        role.addItems(withTitles:["Choose this Mac's role…","Mac A · PG 17, BenQ 19","Mac B · PG 18, BenQ 15"])
        role.font=intro.font;role.target=self;role.action=#selector(roleChanged);role.setAccessibilityLabel("Role of this Mac");stack.addArrangedSubview(role)
        prepared.font=intro.font;prepared.target=self;prepared.action=#selector(preparedChanged);stack.addArrangedSubview(prepared)
        banner.font=intro.font;stack.addArrangedSubview(banner);banner.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.borderType = .bezelBorder;scroll.translatesAutoresizingMaskIntoConstraints=false
        text.isEditable=false;text.isSelectable=true;text.font = .systemFont(ofSize:20);text.textContainerInset=NSSize(width:10,height:10)
        text.isVerticallyResizable=true;text.isHorizontallyResizable=false;text.autoresizingMask=[.width]
        text.textContainer?.widthTracksTextView=true;scroll.documentView=text;stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true;scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:120).isActive=true
        let buttons=NSStackView();buttons.orientation = .horizontal;buttons.spacing=12;stack.addArrangedSubview(buttons)
        for (button,title,action) in [(reviewButton,"Review software",#selector(review)),(installButton,demo ? "Simulate installation":"Install / upgrade",#selector(install))] {
            button.title=title;button.font=intro.font;button.target=self;button.action=action;button.bezelStyle = .rounded;buttons.addArrangedSubview(button)
        }
        let prior=NSButton(title:"Last installation",target:self,action:#selector(showLast));prior.font=intro.font
        let logs=NSButton(title:"Show installation log",target:self,action:#selector(showLog));logs.font=intro.font
        let utilities=NSStackView(views:[prior,logs]);utilities.spacing=12;stack.addArrangedSubview(utilities)
        sizes.font=intro.font;sizes.selectedSegment=1;sizes.target=self;sizes.action=#selector(sizeChanged);sizes.setAccessibilityLabel("Interface size");stack.addArrangedSubview(sizes)
        scalable=[intro,role,prepared,banner,reviewButton,installButton,prior,logs,sizes]
        text.string=demo ? "Synthetic setup only. No installer, hardware command or service change will run.":"This window uses a bundled copy of the trusted checkout. Software review reads prerequisites only. Install / upgrade builds helpers, checks hardware, updates the controller and menu, and may briefly change the desktop or audio during verification.\n\nNo baseline replacement or rotation calibration is requested by this flow. Backups and recovery are managed by the existing installer."
        if let revision=Bundle.main.object(forInfoDictionaryKey:"DisplayBridgeRevision") as? String {text.string += "\n\nSource revision: \(revision)"}
        refreshControls();window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc func sizeChanged(){let font=NSFont.systemFont(ofSize:[16.0,20.0,24.0][max(0,min(2,sizes.selectedSegment))]);for control in scalable {control.font=font};text.font=font}
    func refreshControls() {
        role.isEnabled = !checking && !selection.installing;prepared.isEnabled = !checking && !selection.installing
        reviewButton.isEnabled=selection.host != nil && !checking && !selection.installing
        installButton.isEnabled=selection.canInstall && !checking
    }
    @objc func roleChanged() {selection.select(role.indexOfSelectedItem==1 ? "A":role.indexOfSelectedItem==2 ? "B":nil);prepared.state = .off;banner.stringValue="Review software for the selected role before installing.";refreshControls()}
    @objc func preparedChanged(){selection.prepared=prepared.state == .on;refreshControls()}
    @objc func review() {
        guard let host=selection.host,!selection.installing,!checking else{return}
        checking=true;selection.reviewedHost=nil;banner.stringValue="Reviewing software prerequisites…";refreshControls()
        if demo {selection.reviewedHost=host;checking=false;banner.stringValue="Synthetic prerequisites passed. No hardware was inspected.";refreshControls();return}
        guard let python=python else {checking=false;banner.stringValue="Python location is unavailable. Rebuild this setup app from the checkout.";refreshControls();return}
        let arguments=setupArguments(package.appendingPathComponent("install.py"),host:host,preflight:true)
        DispatchQueue.global(qos:.userInitiated).async {
            let result=runMenuCommand(python,arguments,timeout:60)
            let review=setupReview(result.output,host:host)
            DispatchQueue.main.async {
                self.checking=false
                self.selection.reviewedHost=result.code==0 && review.ready ? host:nil
                self.banner.stringValue=self.selection.reviewedHost==nil ? "Software review needs attention.":"Software review passed; confirm monitor preparation before installing."
                self.text.string=review.text;self.refreshControls()
            }
        }
    }
    @objc func install() {
        guard selection.canInstall,!checking,let host=selection.host else{return}
        if demo {
            selection.installing=true;selection.reviewedHost=nil;refreshControls()
            banner.stringValue="Simulated installation running. No hardware or service changes."
            text.string="Demo only. Close and Quit remain held during this ten-second simulation."
            timer=Timer.scheduledTimer(withTimeInterval:10,repeats:false){[weak self] _ in
                guard let self=self else{return};self.selection.installing=false;self.timer=nil
                self.banner.stringValue="Simulated installation finished. No changes made.";self.text.string="Simulation finished. Closing and quitting are available again. Review software again before another simulation.";self.refreshControls()
            }
            return
        }
        guard let python=python else{return}
        do {
            let directory=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DisplayBridgeSetup")
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let url=directory.appendingPathComponent("setup-\(UUID().uuidString).log")
            let fd=Darwin.open(url.path,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0o600)
            guard fd>=0 else{throw NSError(domain:NSPOSIXErrorDomain,code:Int(errno))}
            let output=FileHandle(fileDescriptor:fd,closeOnDealloc:true),process=Process()
            process.executableURL=python;process.arguments=setupArguments(package.appendingPathComponent("install.py"),host:host,preflight:false)
            process.standardInput=FileHandle.nullDevice;process.standardOutput=output;process.standardError=output
            var environment=ProcessInfo.processInfo.environment;environment["PYTHONDONTWRITEBYTECODE"]="1";environment["PYTHONUNBUFFERED"]="1";process.environment=environment
            process.terminationHandler={ [weak self] child in DispatchQueue.main.async {self?.finished(child)} }
            launchedAt=Date().timeIntervalSince1970;try process.run()
            task=process;log=output;logURL=url;selection.installing=true;refreshControls()
            text.string="Waiting for this installer to publish its first report. No outcome is known yet."
            banner.stringValue="Installation is running. Closing or quitting is held until the installer exits."
            timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true){[weak self] _ in self?.showProgress()}
        } catch {banner.stringValue="Installer could not start. No successful installation is claimed. Recheck the checkout and software prerequisites.";selection.reviewedHost=nil;refreshControls()}
    }
    @discardableResult func showProgress()->Bool {
        guard let task=task else{return false}
        guard let report=readMenuState(progressURL),let host=selection.host,
              let summary=setupAttemptSummary(report,pid:task.processIdentifier,host:host,launchedAt:launchedAt,running:task.isRunning,now:Date().timeIntervalSince1970) else {
            text.string="No matching report is currently available for this attempt. The installer may still be working; inspect its private log. An earlier report is not a current outcome."
            return false
        }
        text.string=summary;return true
    }

    func finished(_ child:Process) {
        if !showProgress() {text.string="No matching report was recorded for this attempt. Inspect the private log and check system health; no installation outcome is inferred from an older report."}
        timer?.invalidate();timer=nil;selection.installing=false;selection.reviewedHost=nil
        banner.stringValue=child.terminationStatus==0 ? "Installer command completed. Inspect its report, then check desktop and sound.":"Installer command failed. Inspect the report and private log before retrying."
        try? log?.close();log=nil;task=nil;refreshControls()
    }
    @objc func showLast(){
        if selection.installing {if !demo {showProgress()};return}
        if demo {text.string="Synthetic setup has not run a real installation.";return}
        guard var report=readMenuState(progressURL) else {text.string="No installation report is available.";return}
        report["read_only"]=true;report["available"]=true
        if let bytes=try? JSONSerialization.data(withJSONObject:report),let json=String(data:bytes,encoding:.utf8) {text.string=installationSummary(json)}
    }
    @objc func showLog(){if let url=logURL {NSWorkspace.shared.activateFileViewerSelecting([url])} else{banner.stringValue="No installation log was created in this window."}}
    func windowShouldClose(_ sender:NSWindow)->Bool {if selection.installing {banner.stringValue="Installation is still running. Wait for its result before closing.";return false};return true}
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {if selection.installing {banner.stringValue="Installation is still running. Wait for its result before quitting.";return .terminateCancel};return .terminateNow}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
}
if CommandLine.arguments.contains("--self-test") {runSetupTests()} else {
    let application=NSApplication.shared,delegate=SetupApp();application.delegate=delegate;application.run()
}
