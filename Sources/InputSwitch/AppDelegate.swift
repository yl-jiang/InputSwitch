import AppKit
import InputSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = RuleStore()
    private let inputSources = CarbonInputSourceService()
    private let eventStore = SwitchEventStore(fileURL: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/InputSwitch/switch-events.jsonl"))
    private lazy var coordinator = SwitchCoordinator(store: store, inputSources: inputSources, eventStore: eventStore)
    private var monitor: AppActivationMonitor?
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var popoverAnchorWindow: NSWindow?
    private var pauseButton: StatusMenuButton?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

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
        pauseButton?.itemTitle = store.isPaused ? "恢复自动切换" : "暂停自动切换"
        pauseButton?.itemImage = statusImage(store.isPaused ? "play.fill" : "pause.fill")

        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            presentStatusPopover(on: screen, at: mouseLocation)
        } else if let button = statusItem?.button {
            statusPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        if let popoverWindow = statusPopover?.contentViewController?.view.window {
            popoverWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            popoverWindow.makeFirstResponder(nil)
        }
        startClickMonitoring()
    }

    private func presentStatusPopover(on screen: NSScreen, at mouseLocation: NSPoint) {
        guard let popover = statusPopover else { return }
        let frame = NSRect(x: mouseLocation.x - 0.5, y: screen.visibleFrame.maxY - 1, width: 1, height: 1)
        let anchorWindow = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        anchorWindow.isOpaque = false
        anchorWindow.backgroundColor = .clear
        anchorWindow.hasShadow = false
        anchorWindow.level = .statusBar
        anchorWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let anchorView = NSView(frame: NSRect(origin: .zero, size: frame.size))
        anchorWindow.contentView = anchorView
        anchorWindow.orderFront(nil)
        popoverAnchorWindow = anchorWindow
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    private func startClickMonitoring() {
        stopClickMonitoring()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.statusPopover?.close()
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window !== self?.statusPopover?.contentViewController?.view.window {
                self?.statusPopover?.close()
            }
            return event
        }
    }

    private func stopClickMonitoring() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopClickMonitoring()
        popoverAnchorWindow?.orderOut(nil)
        popoverAnchorWindow = nil
    }

    private func statusImage(_ name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }

    private func makeStatusButton(title: String, imageName: String, action: Selector) -> StatusMenuButton {
        let button = StatusMenuButton(frame: .zero)
        button.itemTitle = title
        button.itemImage = statusImage(imageName)
        button.target = self
        button.action = action
        button.isBordered = false
        button.widthAnchor.constraint(equalToConstant: 176).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
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

        let openButton = makeStatusButton(title: "打开规则", imageName: "macwindow", action: #selector(showWindow))
        let pauseButton = makeStatusButton(title: "暂停自动切换", imageName: "pause.fill", action: #selector(togglePause))
        let quitButton = makeStatusButton(title: "退出", imageName: "power", action: #selector(quit))
        let separator = NSBox()
        separator.boxType = .separator
        separator.widthAnchor.constraint(equalToConstant: 176).isActive = true

        let content = NSStackView(views: [openButton, pauseButton, separator, quitButton])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 4
        content.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        content.frame = NSRect(x: 0, y: 0, width: 188, height: 124)

        let contentController = NSViewController()
        contentController.view = content

        // 全屏 Space 中不能依赖需要成为 key window 的 NSMenu。
        let popover = NSPopover()
        popover.contentViewController = contentController
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = false
        statusPopover = popover
        self.pauseButton = pauseButton

        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(showStatusMenu)
        statusItem?.button?.sendAction(on: [.leftMouseUp])
    }
}
