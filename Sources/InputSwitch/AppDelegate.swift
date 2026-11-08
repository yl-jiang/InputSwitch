import AppKit
import InputSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = RuleStore()
    private let inputSources = CarbonInputSourceService()
    private let eventStore = SwitchEventStore(fileURL: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/InputSwitch/switch-events.jsonl"))
    private lazy var coordinator = SwitchCoordinator(store: store, inputSources: inputSources, eventStore: eventStore)
    private var monitor: AppActivationMonitor?
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var pauseMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installDefaultRule()
        configureStatusItem()

        monitor = AppActivationMonitor { [weak self] bundleID in
            self?.coordinator.handleActivatedApp(bundleID: bundleID)
        }
        monitor?.start()
        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        pauseMenuItem?.title = store.isPaused ? "恢复自动切换" : "暂停自动切换"
    }

    @objc private func showWindow() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "输入法切换"
            window.minSize = NSSize(width: 720, height: 520)
            window.isReleasedWhenClosed = false
            window.contentViewController = MainViewController(
                store: store,
                coordinator: coordinator,
                inputSources: inputSources,
                eventStore: eventStore
            )
            window.setFrameAutosaveName("RulesWindow")
            window.center()
            self.window = window
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePause() {
        store.isPaused.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func installDefaultRule() {
        guard UserDefaults.standard.object(forKey: "rules") == nil else { return }
        store.save(Rule(
            bundleID: "com.microsoft.VSCode",
            appName: "Visual Studio Code",
            inputSourceID: "com.apple.keylayout.ABC"
        ))
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            let image = NSImage(contentsOf: url)
            image?.isTemplate = true
            image?.size = NSSize(width: 18, height: 18)
            statusItem?.button?.image = image
        } else {
            statusItem?.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "输入法切换")
        }
        statusItem?.button?.setAccessibilityLabel("输入法切换")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "打开规则", action: #selector(showWindow), keyEquivalent: "")
        pauseMenuItem = NSMenuItem(title: "暂停自动切换", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(pauseMenuItem!)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }
}
