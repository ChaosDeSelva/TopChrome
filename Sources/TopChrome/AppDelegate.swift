import AppKit
import TopChromeCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let preferences = Preferences()
    private lazy var chrome = ChromeController(owner: preferences.ownerName)
    private let shortcut = GlobalShortcut()
    private let toolbarPanel = ControlPanel(title: "TopChrome Controls")
    private let gripPanel = ControlPanel(title: "TopChrome Resize")
    private let toolbar = DrawerToolbar(frame: .zero)
    private let grip = ResizeGrip(frame: .zero)
    private let welcome = WelcomeWindow()
    private var statusItem: NSStatusItem!
    private var state: ChromeWindowState?
    private var screen: NSScreen?
    private var expanded = false
    private var busy = false
    private var revealingDrawer = false
    private var polling = false
    private var commandGeneration = 0
    private var shortcutWorks = false
    private var previousApp: NSRunningApplication?
    private var timer: Timer?
    private var pendingResize: DispatchWorkItem?
    private var quitting = false
    private var spaceSuspended = false
    private var modalOpen = false
    private var ready = false
    private var pendingOpenURLs: [String] = []
    private var pendingSpaceChange: DispatchWorkItem?
    private var pendingControlRefresh: DispatchWorkItem?
    private var pollFailures = 0
    private let chromeVisibility = ChromeVisibility()
    private let desktopFollower = ChromeDesktopFollower()
    private let controlSettler = ControlSettler()
    private var movingDesktop = false
    private var desktopStatus: String?
    private var desktopRequest = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        toolbarPanel.contentView = toolbar
        gripPanel.contentView = grip
        toolbar.onNew = { [weak self] in self?.newTab() }
        toolbar.onHide = { [weak self] in self?.hideDrawer() }
        toolbar.onExpand = { [weak self] in self?.toggleExpanded() }
        toolbar.onHeight = { [weak self] view in self?.heightMenu().popUp(positioning: nil, at: .zero, in: view) }
        toolbar.onShortcut = { [weak self] in self?.changeShortcut() }
        grip.onDrag = { [weak self] bottom in self?.resize(bottom: bottom) }
        welcome.onOpen = { [weak self] in self?.showDrawer() }
        welcome.onShortcut = { [weak self] in self?.changeShortcut() }
        installMenus()
        shortcut.onPress = { [weak self] in self?.toggleDrawer() }
        shortcutWorks = shortcut.register(preferences.keyBinding)
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in self?.poll() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        ready = true
        if !pendingOpenURLs.isEmpty { openPendingLinks() }
        else if preferences.lastVisibleBounds != nil { showDrawer() }
        else { showWelcome() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        do {
            let addresses = try urls.map { try OpenLink.address(from: $0) }
            pendingOpenURLs.append(contentsOf: addresses)
            openPendingLinks()
        } catch { showWelcome(error.localizedDescription) }
    }

    private func openPendingLinks() {
        guard ready, !busy, !quitting, !modalOpen, !pendingOpenURLs.isEmpty else { return }
        let addresses = pendingOpenURLs
        pendingOpenURLs.removeAll()
        revealDrawer(opening: addresses)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showDrawer(); return false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !quitting else { return .terminateLater }
        quitting = true
        timer?.invalidate()
        pendingResize?.cancel()
        pendingSpaceChange?.cancel()
        pendingControlRefresh?.cancel()
        cancelDesktopTransfer()
        hideControls()
        guard preferences.hidden, chrome.isRunning else { return .terminateNow }
        chrome.perform(.release(bounds: restoreBounds())) { [weak self] result in
            if case .success = result { self?.preferences.hidden = false }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc private func toggleDrawer() {
        if movingDesktop { hideDrawer(); return }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isFocused = front == "com.google.Chrome" || front == Bundle.main.bundleIdentifier
        if chrome.isRunning, isFocused, chromeVisibility.isFrontChromeWindow,
           !preferences.hidden, state?.visible == true, state?.minimized == false { hideDrawer() }
        else { showDrawer() }
    }

    @objc private func showDrawer() {
        revealDrawer()
    }

    private func revealDrawer(opening urls: [String] = [], addingTab: Bool = false) {
        guard !busy else { return }
        cancelDesktopTransfer()
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") != nil else {
            showWelcome("Install Google Chrome in Applications, then open the drawer again."); return
        }
        revealingDrawer = true
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier, front?.bundleIdentifier != "com.google.Chrome" { previousApp = front }
        screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if state == nil, chrome.isRunning {
            perform(.inspect) { [weak self] in self?.revealKnownDrawer(opening: urls, addingTab: addingTab) }
        } else { revealKnownDrawer(opening: urls, addingTab: addingTab) }
    }

    private func revealKnownDrawer(opening urls: [String], addingTab: Bool) {
        pendingSpaceChange?.cancel()
        spaceSuspended = false
        let action: ChromeAction = !urls.isEmpty ? .openURLs(urls, bounds: desiredBounds()) :
            (addingTab ? .newTab(bounds: desiredBounds()) : .show(bounds: desiredBounds()))
        preferences.hidden = false
        let reveal: () -> Void = { [weak self] in
            self?.perform(action) { [weak self] in
                self?.revealingDrawer = false
                self?.preferences.lastVisibleBounds = self?.state?.bounds
                self?.welcome.orderOut(nil)
                self?.updateControls()
            }
        }
        if preferences.followAllChromeWindows, state != nil, !chromeVisibility.isOnCurrentDesktop {
            // Restore visibility without activation so Chrome cannot switch us back to its old desktop.
            perform(.prepare(bounds: desiredBounds())) { [weak self] in
                self?.bringDrawerHere(automatic: false, then: reveal)
            }
        } else { reveal() }
    }

    private func cancelDesktopTransfer() {
        desktopRequest += 1
        desktopFollower.cancel()
        pendingControlRefresh?.cancel()
        movingDesktop = false
    }

    private func bringDrawerHere(automatic: Bool, attempt: Int = 0, then completion: @escaping () -> Void) {
        chromeVisibility.remember(state)
        if chromeVisibility.isOnCurrentDesktop { movingDesktop = false; completion(); return }
        guard let identity = chromeVisibility.identity else {
            if attempt < 8 {
                let request = desktopRequest
                movingDesktop = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
                    guard let self, self.desktopRequest == request, !self.quitting, !self.preferences.hidden else { return }
                    self.bringDrawerHere(automatic: automatic, attempt: attempt + 1, then: completion)
                }
                return
            }
            movingDesktop = false
            revealingDrawer = false
            desktopStatus = "The Chrome drawer could not be identified. Show it again to retry."
            if !automatic { showWelcome(desktopStatus) }
            return
        }
        let browserID = state?.id
        let request = desktopRequest
        movingDesktop = true
        desktopFollower.bring(identity) { [weak self] outcome in
            guard let self, self.desktopRequest == request else { return }
            self.movingDesktop = false
            guard !self.quitting, !self.preferences.hidden, self.state?.id == browserID else { return }
            switch outcome {
            case .ready:
                self.desktopStatus = "The drawer’s move to the current desktop was confirmed."
                completion()
            case .cancelled: self.revealingDrawer = false
            case .unavailable, .rejected:
                self.revealingDrawer = false
                self.desktopStatus = outcome == .unavailable ?
                    "Desktop following is unavailable here. Use a normal desktop; this macOS version must support Chrome window movement." :
                    "macOS did not move the Chrome drawer to this desktop. Its tabs are still open."
                self.hideControls()
                if !automatic { self.showWelcome(self.desktopStatus) }
            }
        }
    }

    private func hideDrawer() {
        guard !busy, let state else { return }
        revealingDrawer = false
        cancelDesktopTransfer()
        pendingResize?.cancel()
        pendingSpaceChange?.cancel()
        preferences.lastVisibleBounds = state.bounds
        preferences.hidden = true
        hideControls()
        perform(.hide) { [weak self] in
            guard let self else { return }
            if self.state?.visible == true {
                self.preferences.hidden = false
                self.showWelcome("Chrome kept the drawer on screen. Try showing and hiding it again.")
            } else { self.previousApp?.activate(options: []) }
        }
    }

    @objc private func newTab() {
        revealDrawer(addingTab: true)
    }

    @objc private func toggleExpanded() {
        guard !busy else { return }
        expanded.toggle()
        if state == nil || state?.minimized == true || preferences.hidden { showDrawer() }
        else { perform(.resize(bounds: desiredBounds())) }
    }

    private func setHeight(_ value: Double) {
        preferences.heightFraction = value
        expanded = false
        guard state != nil, !preferences.hidden else { updateControls(); return }
        scheduleResize()
    }

    private func resize(bottom: CGFloat) {
        guard let visible = screen?.visibleFrame, visible.height > 0 else { return }
        setHeight((visible.maxY - bottom) / visible.height)
    }

    private func scheduleResize() {
        pendingResize?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.quitting, !self.preferences.hidden, self.state?.minimized == false else { return }
            if self.busy || self.movingDesktop { self.scheduleResize(); return }
            self.perform(.resize(bounds: self.desiredBounds()))
        }
        pendingResize = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
    }

    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }
    private func desiredBounds() -> [Int] {
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let drawer = DrawerGeometry.frame(in: visible, fraction: preferences.heightFraction, expanded: expanded)
        return DrawerGeometry.scriptBounds(for: DrawerGeometry.browser(in: drawer), primaryHeight: primaryHeight)
    }
    private func restoreBounds() -> [Int] {
        if let bounds = preferences.lastVisibleBounds,
           let frame = DrawerGeometry.cocoaFrame(from: bounds, primaryHeight: primaryHeight),
           NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) { return bounds }
        return desiredBounds()
    }

    private func perform(_ action: ChromeAction, completed: (() -> Void)? = nil) {
        guard !busy, !quitting else { return }
        busy = true
        commandGeneration += 1
        welcome.setStatus(nil, busy: true)
        chrome.perform(action) { [weak self] result in
            guard let self, !self.quitting else { return }
            self.busy = false
            self.welcome.setStatus(nil, busy: false)
            switch result {
            case .success(let value):
                self.pollFailures = 0
                self.state = value
                self.chromeVisibility.remember(value)
                self.updateControls()
                completed?()
            case .failure(let error):
                self.revealingDrawer = false
                self.preferences.hidden = false
                self.hideControls()
                self.showWelcome(error.localizedDescription, permissionDenied: (error as? ChromeFailure)?.code == -1743)
            }
        }
    }

    private func poll() {
        openPendingLinks()
        guard !busy, !movingDesktop, !spaceSuspended, !polling, !quitting, !modalOpen, state != nil else { return }
        guard chrome.isRunning else { state = nil; hideControls(); return }
        polling = true
        let generation = commandGeneration
        chrome.perform(.inspect) { [weak self] result in
            guard let self, !self.quitting else { return }
            self.polling = false
            guard generation == self.commandGeneration else { return }
            switch result {
            case .success(let value):
                self.pollFailures = 0
                self.state = value
                self.chromeVisibility.remember(value)
                self.updateControls()
            case .failure:
                self.pollFailures += 1
                if self.pollFailures >= 3 || !self.chromeVisibility.isOnCurrentDesktop { self.hideControls() }
            }
        }
    }

    private func updateControls(deferHiding: Bool = true) {
        toolbar.update(fraction: preferences.heightFraction, expanded: expanded,
                       shortcutLabel: preferences.keyBinding.display, shortcutWorks: shortcutWorks, tabs: state?.tabCount ?? 0)
        statusItem.button?.toolTip = "TopChrome · \(preferences.keyBinding.display) · right-click for controls"
        guard let state, !preferences.hidden, !quitting else { hideControls(); return }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard front == "com.google.Chrome" || front == Bundle.main.bundleIdentifier else { hideControls(); return }
        if revealingDrawer || busy || spaceSuspended || movingDesktop { controlSettler.cancel(); return }
        guard state.visible, !state.minimized,
              chromeVisibility.isFrontChromeWindow,
              let browser = DrawerGeometry.cocoaFrame(from: chromeVisibility.currentBounds ?? state.bounds,
                                                     primaryHeight: primaryHeight) else {
            if deferHiding {
                controlSettler.recheck { [weak self] in self?.updateControls(deferHiding: false) }
            } else { hideControls() }
            return
        }
        controlSettler.cancel()
        screen = NSScreen.screens.max { $0.frame.intersection(browser).area < $1.frame.intersection(browser).area } ?? screen
        toolbarPanel.present(at: NSRect(x: browser.minX, y: browser.maxY, width: browser.width, height: DrawerGeometry.toolbarHeight))
        gripPanel.present(at: NSRect(x: browser.minX, y: browser.minY - DrawerGeometry.gripHeight, width: browser.width, height: DrawerGeometry.gripHeight))
    }

    private func hideControls() { controlSettler.cancel(); toolbarPanel.dismiss(); gripPanel.dismiss() }
    private func showWelcome(_ error: String? = nil, permissionDenied: Bool = false) {
        welcome.setStatus(error, busy: busy, permissionDenied: permissionDenied)
        NSApp.activate(ignoringOtherApps: true)
        welcome.makeKeyAndOrderFront(nil)
    }

    @objc private func appChanged() { updateControls() }
    @objc private func spaceChanged() {
        pendingSpaceChange?.cancel()
        cancelDesktopTransfer()
        revealingDrawer = false
        commandGeneration += 1
        spaceSuspended = true
        if !chromeVisibility.isOnCurrentDesktop { hideControls() }
        finishSpaceChange(request: desktopRequest)
    }

    private func finishSpaceChange(request: Int) {
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.quitting, self.desktopRequest == request else { return }
            if self.busy || self.movingDesktop { self.finishSpaceChange(request: request); return }
            self.spaceSuspended = false
            guard !self.modalOpen, !self.preferences.hidden, self.state?.visible == true,
                  self.state?.minimized == false else { self.updateControls(); return }
            let reveal = { [weak self] in
                guard let self else { return }
                let awaitingVisibility = !self.chromeVisibility.isOnCurrentDesktop && self.state?.isFront == true
                if (self.chromeVisibility.isFrontChromeWindow || awaitingVisibility), let identity = self.chromeVisibility.identity,
                   let app = NSRunningApplication(processIdentifier: identity.process), app.bundleIdentifier == "com.google.Chrome" {
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier != identity.process { app.activate(options: []) }
                    self.refreshControlsAfterMove(request: request)
                } else {
                    self.perform(.show(bounds: self.desiredBounds())) { [weak self] in self?.refreshControlsAfterMove(request: request) }
                }
            }
            if self.preferences.followAllChromeWindows {
                self.bringDrawerHere(automatic: true, then: reveal)
            } else if self.chromeVisibility.isOnCurrentDesktop {
                reveal()
            } else { self.poll(); self.updateControls() }
        }
        pendingSpaceChange = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func refreshControlsAfterMove(request: Int, attempt: Int = 0) {
        guard request == desktopRequest, !quitting, !preferences.hidden else { return }
        updateControls()
        guard !chromeVisibility.isOnCurrentDesktop, attempt < 20 else { return }
        // Desktop membership can settle before the window appears in the on-screen list.
        let work = DispatchWorkItem { [weak self] in self?.refreshControlsAfterMove(request: request, attempt: attempt + 1) }
        pendingControlRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025, execute: work)
    }

    @objc private func desktopSetup() {
        let alert = NSAlert()
        alert.messageText = "Follow Chrome across desktops"
        alert.informativeText = "When the drawer is shown, TopChrome can bring all Google Chrome windows to your current desktop after a swipe. This includes regular Chrome windows. Tabs and page state stay open.\n\nFollowing may need an update after future macOS releases. Native full-screen Spaces are not supported.\n\n" +
            (desktopStatus ?? (preferences.followAllChromeWindows ? "Following is enabled." : "Following is off until you enable it."))
        alert.addButton(withTitle: preferences.followAllChromeWindows ? "Turn Off" : "Enable for All Chrome Windows")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].isEnabled = desktopFollower.isAvailable || preferences.followAllChromeWindows
        modalOpen = true
        shortcut.isEnabled = false
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        modalOpen = false
        shortcut.isEnabled = true
        guard response == .alertFirstButtonReturn else { return }
        preferences.followAllChromeWindows.toggle()
        cancelDesktopTransfer()
        if preferences.followAllChromeWindows { spaceChanged() }
    }

    @objc private func screensChanged() {
        screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if state?.minimized == false, !preferences.hidden { scheduleResize() }
    }

    private func installMenus() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "TopChrome")
            button.image?.isTemplate = true
            button.target = self; button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let main = NSMenu()
        let root = NSMenuItem()
        let menu = NSMenu(title: "TopChrome")
        menu.addItem(item("About TopChrome", #selector(about)))
        menu.addItem(item("Desktop Following Setup…", #selector(desktopSetup)))
        menu.addItem(item("Show / Hide Chrome", #selector(toggleDrawer)))
        menu.addItem(item("Show / Hide Shortcut…", #selector(changeShortcut), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit TopChrome (Keep Tabs)", #selector(quit), key: "q"))
        root.submenu = menu; main.addItem(root)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        edit.submenu = NSMenu(title: "Edit")
        for (name, selector, key) in [("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.submenu?.addItem(NSMenuItem(title: name, action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        main.addItem(edit)
        NSApp.mainMenu = main
        updateControls()
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let heading = NSMenuItem(title: "TopChrome", action: nil, keyEquivalent: "")
            heading.isEnabled = false; menu.addItem(heading)
            menu.addItem(item(toolbarPanel.isVisible ? "Hide Chrome Drawer" : "Show Chrome Drawer", #selector(toggleDrawer)))
            menu.addItem(item(expanded ? "Restore Saved Height" : "Full Height", #selector(toggleExpanded)))
            let height = NSMenuItem(title: "Drawer Height", action: nil, keyEquivalent: "")
            height.submenu = heightMenu(); menu.addItem(height)
            menu.addItem(item("New Chrome Tab", #selector(newTab)))
            menu.addItem(item("Desktop Following Setup…", #selector(desktopSetup)))
            menu.addItem(.separator())
            menu.addItem(item("Show / Hide Shortcut…", #selector(changeShortcut)))
            menu.addItem(item("About TopChrome", #selector(about)))
            menu.addItem(.separator())
            menu.addItem(item("Close Drawer Window & Quit…", #selector(closeAndQuit)))
            menu.addItem(item("Quit TopChrome (Keep Tabs)", #selector(quit)))
            menu.delegate = self
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
        } else { toggleDrawer() }
    }
    func menuDidClose(_ menu: NSMenu) { statusItem.menu = nil }
    private func heightMenu() -> NSMenu {
        let menu = NSMenu()
        for percent in [30, 40, 50, 60, 75, 90] {
            let entry = item("\(percent)%\(percent == 50 ? " (Default)" : "")", #selector(heightSelected))
            entry.tag = percent
            entry.state = Int((preferences.heightFraction * 100).rounded()) == percent ? .on : .off
            menu.addItem(entry)
        }
        return menu
    }
    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }
    @objc private func heightSelected(_ sender: NSMenuItem) { setHeight(Double(sender.tag) / 100) }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func closeAndQuit() {
        guard !busy else { return }
        let alert = NSAlert()
        alert.messageText = "Close the Chrome drawer’s tabs?"
        alert.informativeText = "This closes only the window managed by TopChrome. To keep these tabs open, choose Quit TopChrome (Keep Tabs) instead."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Close Window & Quit")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        perform(.close(bounds: restoreBounds())) { [weak self] in
            self?.perform(.inspect) { [weak self] in
                if self?.state == nil { NSApp.terminate(nil) }
                else { self?.showWelcome("Chrome is keeping the drawer open. Resolve any Chrome confirmation dialog, then try again.") }
            }
        }
    }

    @objc private func changeShortcut() {
        let alert = NSAlert()
        alert.messageText = "Show / hide shortcut"
        alert.informativeText = "Current: \(preferences.keyBinding.display). Choose a combination that is comfortable and available."
        let recorder = ShortcutRecorder(frame: NSRect(x: 0, y: 0, width: 360, height: 76))
        alert.accessoryView = recorder
        alert.addButton(withTitle: "Save Shortcut")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Use Default")
        alert.buttons[0].isEnabled = false
        recorder.onChange = { [weak alert, weak recorder] in alert?.buttons[0].isEnabled = recorder?.candidate != nil }
        modalOpen = true
        shortcut.isEnabled = false
        defer { modalOpen = false; shortcut.isEnabled = true }
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = recorder
        let response = alert.runModal()
        let choice = response == .alertThirdButtonReturn ? KeyBinding.defaultBinding : (response == .alertFirstButtonReturn ? recorder.candidate : nil)
        guard let choice else { return }
        guard shortcut.register(choice) else {
            let conflict = NSAlert()
            conflict.messageText = "That shortcut is unavailable"
            conflict.informativeText = "macOS or another app is using this combination. Your previous shortcut has been kept."
            conflict.runModal(); return
        }
        preferences.keyBinding = choice
        shortcutWorks = true
        updateControls()
    }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "TopChrome", .applicationVersion: "0.1.0",
            .credits: NSAttributedString(string: "Your Chrome, within reach.\n\n\(preferences.keyBinding.display)  Show / hide\nDrag the bottom edge to resize.\nRight-click the menu-bar icon for all controls.\n\nUses your installed Google Chrome.\nAn independent app, not affiliated with Google.")
        ])
    }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}
