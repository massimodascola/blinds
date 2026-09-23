import AppKit
import Carbon.HIToolbox
import ServiceManagement

// Blinds hides the menu bar icons that sit to the left of its divider and
// shows them again when you click its arrow.
//
// How it works on macOS 27 (measured on 23 Sep 2026, macOS 27.0 build 26A428):
// * status items are no longer separate windows: MenuBarAgent draws them all;
// * when an item does not fit, macOS moves it into its overflow menu together
//   with EVERY item to its left, without leaving a gap;
// * an item wider than about half the screen is discarded and ignored.
// Hiding therefore just means widening the divider beyond the free space but
// below half the screen width.
//
// On macOS 26 and earlier, status items are still separate windows and the
// classic Hidden Bar / Ice method applies: a 10,000-point divider pushes
// everything to its left off screen. NOT TESTED here (this Mac runs macOS 27):
// it is the method those apps used up to macOS 26.
//
// Only public Apple APIs are used: no Accessibility or Screen Recording
// permission.

/// Localized text from Resources/<language>.lproj/Localizable.strings.
func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

enum Defaults {
    // Stored keys come from version 1.0, when the app was called Tendina and
    // used Italian names. They are kept so existing settings survive updates.
    static let autoCollapse = "richiudiDaSola"
    static let didShowWelcome = "primoAvvioFatto"
}

final class MenuBarController: NSObject, NSMenuDelegate {
    // Creation order matters: macOS places every new item to the left of the
    // existing ones, so the divider starts right next to the arrow, on its left.
    private let arrow = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let divider = NSStatusBar.system.statusItem(withLength: 10)

    private(set) var isCollapsed = false
    private var collapseTimer: Timer?
    private var hotKey: EventHotKeyRef?

    private let autoCollapseDelay: TimeInterval = 10
    private let expandedDividerWidth: CGFloat = 10

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: [Defaults.autoCollapse: true])

        // Fixed names make macOS remember where the user placed the items.
        // They come from version 1.0, when the app was called Tendina:
        // changing them would make macOS forget those positions.
        arrow.autosaveName = "tendina_freccia"
        divider.autosaveName = "tendina_separatore"

        if let button = arrow.button {
            button.target = self
            button.action = #selector(arrowClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = localized("tooltip.arrow")
        }
        divider.button?.toolTip = localized("tooltip.divider")

        updateAppearance()
        registerHotKey()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    // MARK: Expanding and collapsing

    func toggle() {
        isCollapsed ? expand() : collapse()
    }

    func expand() {
        collapseTimer?.invalidate()
        isCollapsed = false
        updateAppearance()
        if UserDefaults.standard.bool(forKey: Defaults.autoCollapse) {
            scheduleCollapse(after: autoCollapseDelay)
        }
    }

    func collapse() {
        collapseTimer?.invalidate()
        guard isOrderCorrect() else {
            showAlert(localized("alert.wrongOrder.title"), text: localized("alert.wrongOrder.text"))
            return
        }
        isCollapsed = true
        updateAppearance()
    }

    private func updateAppearance() {
        if isCollapsed {
            divider.length = collapsedDividerWidth()
            divider.button?.image = nil
            arrow.button?.image = symbol("chevron.left", description: localized("a11y.show"))
        } else {
            divider.length = expandedDividerWidth
            divider.button?.image = dividerLine()
            arrow.button?.image = symbol("chevron.right", description: localized("a11y.hide"))
        }
    }

    private func collapsedDividerWidth() -> CGFloat {
        if #available(macOS 27, *) {
            // Wider than the free space next to the notch, but below half the
            // narrowest screen: above that limit macOS 27 discards the item
            // (measured on an 1800-point screen: works at 850, discarded at 950).
            let narrowest = NSScreen.screens.map { $0.frame.width }.min() ?? 1440
            return (narrowest * 0.44).rounded()
        } else {
            // Classic method up to macOS 26: off any screen.
            return 10_000
        }
    }

    // If the divider ended up to the right of the arrow, collapsing would hide
    // the arrow too. Positions are only reliable while expanded.
    private func isOrderCorrect() -> Bool {
        guard let dividerFrame = divider.button?.window?.frame,
              let arrowFrame = arrow.button?.window?.frame else { return true }
        return dividerFrame.midX < arrowFrame.midX
    }

    private func scheduleCollapse(after delay: TimeInterval) {
        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self, !self.isCollapsed else { return }
            // Don't collapse while a menu is open or the pointer is on the menu bar.
            if self.isMenuOpen() || self.isPointerOnMenuBar() {
                self.scheduleCollapse(after: 3)
            } else {
                self.collapse()
            }
        }
    }

    private func isMenuOpen() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == menuLevel }
    }

    private func isPointerOnMenuBar() -> Bool {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            screen.frame.contains(pointer) && pointer.y >= screen.visibleFrame.maxY
        }
    }

    @objc private func screensChanged() {
        if isCollapsed { divider.length = collapsedDividerWidth() }
    }

    // MARK: Clicks and menu

    @objc private func arrowClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return toggle() }
        let isSecondaryClick = event.type == .rightMouseUp
            || event.modifierFlags.contains(.control)
            || event.modifierFlags.contains(.option)
        if isSecondaryClick {
            showMenu()
        } else {
            toggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let toggleItem = NSMenuItem(title: localized(isCollapsed ? "menu.show" : "menu.hide"),
                                    action: #selector(toggleFromMenu), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let autoCollapseItem = NSMenuItem(title: String(format: localized("menu.autoCollapse"), Int(autoCollapseDelay)),
                                          action: #selector(toggleAutoCollapse), keyEquivalent: "")
        autoCollapseItem.target = self
        autoCollapseItem.state = UserDefaults.standard.bool(forKey: Defaults.autoCollapse) ? .on : .off
        menu.addItem(autoCollapseItem)

        let loginItem = NSMenuItem(title: localized("menu.openAtLogin"),
                                   action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        let helpItem = NSMenuItem(title: localized("menu.help"), action: #selector(showHelp), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)
        let quitItem = NSMenuItem(title: localized("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // The menu is attached for this click only, then detached,
        // so a left click keeps expanding and collapsing.
        arrow.menu = menu
        arrow.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        arrow.menu = nil
    }

    @objc private func toggleFromMenu() { toggle() }

    @objc private func toggleAutoCollapse() {
        let isOn = !UserDefaults.standard.bool(forKey: Defaults.autoCollapse)
        UserDefaults.standard.set(isOn, forKey: Defaults.autoCollapse)
        if isOn, !isCollapsed { scheduleCollapse(after: autoCollapseDelay) }
        if !isOn { collapseTimer?.invalidate() }
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showAlert(localized("alert.login.title"),
                      text: String(format: localized("alert.login.text"), error.localizedDescription))
        }
    }

    @objc func showHelp() {
        showAlert(localized("help.title"), text: localized("help.text"))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: Keyboard shortcut ⌃⌥⌘B

    // The Carbon API is old, but it is the only one that registers a global
    // shortcut without asking for the Accessibility permission.
    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let controller = Unmanaged<MenuBarController>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { controller.toggle() }
            return noErr
        }, 1, &eventType, context, nil)

        let id = EventHotKeyID(signature: OSType(0x424C_4E44), id: 1) // "BLND"
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(cmdKey | optionKey | controlKey),
                                         id, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr {
            NSLog("Blinds: could not register the ⌃⌥⌘B shortcut (error \(status))")
        }
    }

    // MARK: Graphics

    private func symbol(_ name: String, description: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    private func dividerLine() -> NSImage {
        let image = NSImage(size: NSSize(width: 2, height: 14), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    private func showAlert(_ title: String, text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: localized("alert.ok"))
        alert.runModal()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MenuBarController()
        self.controller = controller

        if !UserDefaults.standard.bool(forKey: Defaults.didShowWelcome) {
            UserDefaults.standard.set(true, forKey: Defaults.didShowWelcome)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { controller.showHelp() }
        } else {
            // Start collapsed, once macOS has placed the items in the menu bar.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { controller.collapse() }
        }
    }

    // Opening Blinds again while it is running (Spotlight, Finder) shows
    // everything: the way out if the arrow ended up among the hidden items.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.expand()
        return false
    }
}

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.accessory)
app.run()
