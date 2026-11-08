import AppKit
import InputSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = RuleStore()
    private let inputSources = CarbonInputSourceService()
    private let eventStore = SwitchEventStore(fileURL: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/InputSwitch/switch-events.jsonl"))
    private lazy var coordinator = SwitchCoordinator(store: store, inputSources: inputSources, eventStore: eventStore)
    private var monitor: AppActivationMonitor?
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var pauseButton: NSButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
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

    @objc private func showWindow() {
        statusPopover?.close()
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
        statusPopover?.close()
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

    @objc private func showStatusMenu() {
        guard let button = statusItem?.button else { return }
        pauseButton?.title = store.isPaused ? "恢复自动切换" : "暂停自动切换"
        statusPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let popoverWindow = statusPopover?.contentViewController?.view.window {
            popoverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            popoverWindow.makeFirstResponder(nil)
        }
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

        let openButton = NSButton(title: "打开规则", target: self, action: #selector(showWindow))
        let pauseButton = NSButton(title: "暂停自动切换", target: self, action: #selector(togglePause))
        let quitButton = NSButton(title: "退出", target: self, action: #selector(quit))
        for button in [openButton, pauseButton, quitButton] {
            button.isBordered = false
            button.alignment = .left
        }

        let content = NSStackView(views: [openButton, pauseButton, quitButton])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 6
        content.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        content.frame = NSRect(x: 0, y: 0, width: 160, height: 100)

        let contentController = NSViewController()
        contentController.view = content

        // 全屏 Space 中不能依赖需要成为 key window 的 NSMenu。
        let popover = NSPopover()
        popover.contentViewController = contentController
        popover.behavior = .transient
        popover.animates = false
        statusPopover = popover
        self.pauseButton = pauseButton

        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(showStatusMenu)
        statusItem?.button?.sendAction(on: [.leftMouseUp])
    }
}
