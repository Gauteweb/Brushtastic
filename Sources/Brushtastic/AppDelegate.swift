import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = StrokeStore()
    private var panels: [OverlayPanel] = []
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var drawing = false

    private var toggleItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private let toolMenu = NSMenu()
    private let colorMenu = NSMenu()
    private let widthMenu = NSMenu()
    private var delayLabel: NSTextField!
    private var delaySlider: NSSlider!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.onChange = { [weak self] in
            self?.panels.forEach { $0.overlayView.needsDisplay = true }
        }

        setupStatusItem()
        rebuildPanels()

        // ⌃⌥D
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_D),
                        modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.toggleDrawing()
        }
        if hotKey == nil {
            NSLog("Brushtastic: kunne ikke registrere ⌃⌥D (allerede i bruk?)")
        }

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(exitDrawing),
                                               name: .brushtasticExitDrawing, object: nil)
        // Når brukeren bytter Space, sørg for at panelene fortsatt ligger øverst.
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(spaceChanged),
                                                          name: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil)
    }

    // MARK: Skjermer og Spaces

    @objc private func screensChanged() {
        rebuildPanels()
    }

    @objc private func spaceChanged() {
        panels.forEach { $0.orderFrontRegardless() }
    }

    private func rebuildPanels() {
        panels.forEach { $0.orderOut(nil); $0.close() }
        panels = NSScreen.screens.map { screen in
            let p = OverlayPanel(screen: screen, store: store)
            p.setDrawingMode(drawing)
            p.orderFrontRegardless()
            return p
        }
        if drawing { focusPanelUnderMouse() }
    }

    // MARK: Tegnemodus

    private func toggleDrawing() {
        setDrawing(!drawing)
    }

    @objc private func exitDrawing() {
        setDrawing(false)
    }

    @objc private func toggleFromMenu() {
        toggleDrawing()
    }

    private func setDrawing(_ on: Bool) {
        guard on != drawing else { return }
        drawing = on
        if !on, store.current != nil { store.end() }
        panels.forEach { $0.setDrawingMode(on) }
        if on {
            panels.forEach { $0.orderFrontRegardless() }
            focusPanelUnderMouse()
        } else {
            panels.forEach { if $0.isKeyWindow { $0.resignKey() } }
        }
        updateStatusUI()
    }

    private func focusPanelUnderMouse() {
        let mouse = NSEvent.mouseLocation
        let target = panels.first { NSMouseInRect(mouse, $0.frame, false) } ?? panels.first
        // Ikke-aktiverende panel: blir key uten å stjele fokus fra appen i forgrunnen.
        target?.makeKey()
    }

    // MARK: Menylinje

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.delegate = self

        toggleItem = NSMenuItem(title: L.startDrawing, action: #selector(toggleFromMenu), keyEquivalent: "d")
        toggleItem.keyEquivalentModifierMask = [.control, .option]
        toggleItem.target = self
        menu.addItem(toggleItem)

        let clear = NSMenuItem(title: L.clearAll, action: #selector(clearAll), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())
        menu.addItem(makeDelayItem())

        menu.addItem(.separator())
        menu.addItem(makeToolMenuItem())
        menu.addItem(makeColorMenuItem())
        menu.addItem(makeWidthMenuItem())

        menu.addItem(.separator())
        loginItem = NSMenuItem(title: L.launchAtLogin, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        for text in [L.hintExit, L.hintShift] {
            let hint = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }

        menu.addItem(.separator())
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let about = NSMenuItem(title: "Brushtastic \(version)", action: nil, keyEquivalent: "")
        about.isEnabled = false
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: L.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        updateStatusUI()
    }

    private func makeDelayItem() -> NSMenuItem {
        let width: CGFloat = 240
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 52))

        delayLabel = NSTextField(labelWithString: "")
        delayLabel.font = .menuFont(ofSize: 0)
        delayLabel.frame = NSRect(x: 20, y: 28, width: width - 40, height: 18)
        container.addSubview(delayLabel)

        delaySlider = NSSlider(value: Settings.shared.fadeDelaySliderValue,
                               minValue: Settings.sliderRange.lowerBound,
                               maxValue: Settings.sliderRange.upperBound,
                               target: self, action: #selector(delayChanged(_:)))
        delaySlider.isContinuous = true
        delaySlider.frame = NSRect(x: 18, y: 4, width: width - 36, height: 22)
        container.addSubview(delaySlider)

        let item = NSMenuItem()
        item.view = container
        updateDelayLabel()
        return item
    }

    @objc private func delayChanged(_ sender: NSSlider) {
        // Rund av til nærmeste 0,5 s.
        let rounded = (sender.doubleValue * 2).rounded() / 2
        let wasNever = Settings.shared.neverFades
        Settings.shared.fadeDelaySliderValue = rounded
        if wasNever != Settings.shared.neverFades {
            store.fadeModeChanged()
        }
        updateDelayLabel()
    }

    private func updateDelayLabel() {
        if Settings.shared.neverFades {
            delayLabel.stringValue = L.fadeNever
            return
        }
        let f = NumberFormatter()
        f.locale = L.numberLocale
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        let s = f.string(from: NSNumber(value: Settings.shared.fadeDelay)) ?? "\(Settings.shared.fadeDelay)"
        delayLabel.stringValue = L.fadeAfter(s)
    }

    private func makeToolMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L.tool, action: nil, keyEquivalent: "")
        let sub = toolMenu
        for tool in Tool.allCases {
            let mi = NSMenuItem(title: tool.name, action: #selector(toolChosen(_:)), keyEquivalent: tool.key)
            mi.keyEquivalentModifierMask = []
            mi.target = self
            mi.tag = tool.rawValue
            sub.addItem(mi)
        }
        item.submenu = sub
        return item
    }

    @objc private func toolChosen(_ sender: NSMenuItem) {
        if let tool = Tool(rawValue: sender.tag) { Settings.shared.tool = tool }
    }

    private func makeColorMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L.color, action: nil, keyEquivalent: "")
        let sub = colorMenu
        for (i, c) in Settings.colors.enumerated() {
            let mi = NSMenuItem(title: c.name, action: #selector(colorChosen(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = i
            mi.image = Self.swatch(c.color)
            sub.addItem(mi)
        }
        item.submenu = sub
        return item
    }

    private func makeWidthMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L.lineWidth, action: nil, keyEquivalent: "")
        let sub = widthMenu
        for (i, w) in Settings.lineWidths.enumerated() {
            let mi = NSMenuItem(title: w.name, action: #selector(widthChosen(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = i
            sub.addItem(mi)
        }
        item.submenu = sub
        return item
    }

    @objc private func colorChosen(_ sender: NSMenuItem) {
        Settings.shared.colorIndex = sender.tag
    }

    @objc private func widthChosen(_ sender: NSMenuItem) {
        Settings.shared.lineWidth = Settings.lineWidths[sender.tag].width
    }

    @objc private func clearAll() {
        store.clear()
    }

    // MARK: Start ved innlogging

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Brushtastic: kunne ikke endre innloggingsobjekt: \(error)")
            let alert = NSAlert()
            alert.messageText = L.launchAtLoginError
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        // macOS kan kreve at brukeren godkjenner i Systeminnstillinger.
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        updateLoginItemState()
    }

    private func updateLoginItemState() {
        switch SMAppService.mainApp.status {
        case .enabled:
            loginItem.state = .on
            loginItem.title = L.launchAtLogin
        case .requiresApproval:
            loginItem.state = .mixed
            loginItem.title = L.launchAtLoginPending
        default:
            loginItem.state = .off
            loginItem.title = L.launchAtLogin
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateLoginItemState()
        delaySlider.doubleValue = Settings.shared.fadeDelaySliderValue
        updateDelayLabel()
        toolMenu.items.forEach { $0.state = $0.tag == Settings.shared.tool.rawValue ? .on : .off }
        colorMenu.items.forEach { $0.state = $0.tag == Settings.shared.colorIndex ? .on : .off }
        widthMenu.items.forEach {
            $0.state = Settings.lineWidths[$0.tag].width == Settings.shared.lineWidth ? .on : .off
        }
    }

    private func updateStatusUI() {
        toggleItem?.title = drawing ? L.stopDrawing : L.startDrawing
        let name = drawing ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Brushtastic")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private static func swatch(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            color.setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
    }
}
