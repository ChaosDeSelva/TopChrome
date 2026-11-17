import AppKit
import TopChromeCore

class ControlPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    init(title: String) {
        super.init(contentRect: .zero, styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        self.title = title
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { standardWindowButton(kind)?.isHidden = true }
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        hasShadow = false
        backgroundColor = Palette.background
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
    }

    func present(at frame: NSRect) {
        if self.frame != frame { setFrame(frame, display: true) }
        if !isVisible { orderFrontRegardless() }
    }

    func dismiss() {
        if isVisible { orderOut(nil) }
    }
}

final class DrawerToolbar: NSView {
    private let brand = NSTextField(labelWithString: "◉  TOPCHROME")
    private let detail = NSTextField(labelWithString: "Your Chrome, within reach")
    private let shortcut = NSButton()
    private let new = NSButton()
    private let height = NSButton()
    private let expand = NSButton()
    private let hide = NSButton()
    var onShortcut: (() -> Void)?
    var onNew: (() -> Void)?
    var onHeight: ((NSView) -> Void)?
    var onExpand: (() -> Void)?
    var onHide: (() -> Void)?
    private var rendered: Content?

    private struct Content: Equatable {
        let fraction: Double
        let expanded: Bool
        let shortcutLabel: String
        let shortcutWorks: Bool
        let tabs: Int
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        brand.font = .systemFont(ofSize: 11, weight: .bold)
        brand.textColor = Palette.accent
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        for button in [shortcut, new, height, expand, hide] {
            button.isBordered = false
            button.bezelStyle = .recessed
            button.target = self
            button.contentTintColor = Palette.foreground
            addSubview(button)
        }
        shortcut.font = .systemFont(ofSize: 11)
        shortcut.action = #selector(shortcutClicked)
        shortcut.toolTip = "Change the show / hide shortcut"
        shortcut.setAccessibilityLabel("Change show and hide shortcut")
        height.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        height.action = #selector(heightClicked)
        height.setAccessibilityLabel("Drawer height")
        height.toolTip = "Choose a height, or drag the bottom edge"
        new.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Chrome tab")
        new.action = #selector(newClicked)
        new.toolTip = "New Chrome tab (⌘T in Chrome)"
        new.setAccessibilityLabel("New Chrome tab")
        expand.action = #selector(expandClicked)
        expand.setAccessibilityLabel("Toggle full height")
        hide.image = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Hide Chrome drawer")
        hide.action = #selector(hideClicked)
        hide.setAccessibilityLabel("Hide Chrome drawer")
        addSubview(brand)
        addSubview(detail)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(fraction: Double, expanded: Bool, shortcutLabel: String, shortcutWorks: Bool, tabs: Int) {
        let content = Content(fraction: fraction, expanded: expanded, shortcutLabel: shortcutLabel, shortcutWorks: shortcutWorks, tabs: tabs)
        guard rendered != content else { return }
        let previous = rendered
        rendered = content
        detail.stringValue = "\(tabs) \(tabs == 1 ? "tab" : "tabs") · Chrome profile"
        shortcut.title = shortcutWorks ? "\(shortcutLabel)  show / hide" : "Set shortcut…"
        height.title = expanded ? "100%" : "\(Int((fraction * 100).rounded()))%"
        if previous?.expanded != expanded {
            expand.image = NSImage(systemSymbolName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                                   accessibilityDescription: expanded ? "Restore saved height" : "Full height")
            expand.toolTip = expanded ? "Restore saved height" : "Full available height"
        }
        hide.toolTip = "Hide Chrome drawer (\(shortcutLabel))"
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        brand.frame = NSRect(x: 16, y: 14, width: 130, height: 16)
        detail.frame = NSRect(x: 160, y: 14, width: max(0, w - 550), height: 16)
        shortcut.frame = NSRect(x: w - 335, y: 5, width: 150, height: 34)
        new.frame = NSRect(x: w - 181, y: 5, width: 32, height: 34)
        height.frame = NSRect(x: w - 142, y: 5, width: 54, height: 34)
        expand.frame = NSRect(x: w - 80, y: 5, width: 32, height: 34)
        hide.frame = NSRect(x: w - 44, y: 5, width: 32, height: 34)
    }
    override func draw(_ dirtyRect: NSRect) {
        Palette.background.setFill(); bounds.fill()
        NSColor.white.withAlphaComponent(0.09).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }
    @objc private func shortcutClicked() { onShortcut?() }
    @objc private func newClicked() { onNew?() }
    @objc private func heightClicked() { onHeight?(height) }
    @objc private func expandClicked() { onExpand?() }
    @objc private func hideClicked() { onHide?() }
}

final class ResizeGrip: NSView {
    var onDrag: ((CGFloat) -> Void)?
    override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeUpDown) }
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) { onDrag?(NSEvent.mouseLocation.y) }
    override func mouseUp(with event: NSEvent) { onDrag?(NSEvent.mouseLocation.y) }
    override func draw(_ dirtyRect: NSRect) {
        Palette.background.setFill(); bounds.fill()
        NSColor.white.withAlphaComponent(0.3).setFill()
        NSBezierPath(roundedRect: NSRect(x: bounds.midX - 22, y: 4, width: 44, height: 3), xRadius: 1.5, yRadius: 1.5).fill()
    }
}

final class WelcomeWindow: NSWindow {
    private let note = NSTextField(wrappingLabelWithString: "Uses the Chrome profile you most recently opened, with your tabs, extensions, and sign-ins. macOS will ask you to allow TopChrome to control Chrome.")
    private let openButton = NSButton(title: "Open Chrome Drawer", target: nil, action: nil)
    private let shortcut = NSButton(title: "Change Shortcut…", target: nil, action: nil)
    private var permissionDenied = false
    var onOpen: (() -> Void)?
    var onShortcut: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 330),
                   styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "TopChrome"
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = Palette.background
        let icon = NSImageView(frame: NSRect(x: 32, y: 230, width: 44, height: 44))
        icon.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        icon.contentTintColor = Palette.accent
        let heading = NSTextField(labelWithString: "Chrome. A shortcut away.")
        heading.font = .systemFont(ofSize: 23, weight: .semibold)
        heading.frame = NSRect(x: 32, y: 190, width: 420, height: 30)
        note.font = .systemFont(ofSize: 13)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 32, y: 95, width: 416, height: 84)
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"
        openButton.frame = NSRect(x: 260, y: 38, width: 188, height: 34)
        openButton.target = self; openButton.action = #selector(openClicked)
        shortcut.bezelStyle = .inline
        shortcut.frame = NSRect(x: 28, y: 38, width: 176, height: 34)
        shortcut.target = self; shortcut.action = #selector(shortcutClicked)
        for view in [icon, heading, note, openButton, shortcut] { contentView?.addSubview(view) }
        center()
    }
    func setStatus(_ message: String?, busy: Bool, permissionDenied: Bool = false) {
        self.permissionDenied = permissionDenied
        note.stringValue = message ?? "Uses the Chrome profile you most recently opened, with your tabs, extensions, and sign-ins. macOS will ask you to allow TopChrome to control Chrome."
        openButton.title = busy ? "Opening…" : (message == nil ? "Open Chrome Drawer" : "Try Again")
        openButton.isEnabled = !busy
        shortcut.title = permissionDenied ? "Open Automation Settings" : "Change Shortcut…"
    }
    @objc private func openClicked() { onOpen?() }
    @objc private func shortcutClicked() {
        if permissionDenied {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
        } else { onShortcut?() }
    }
}
