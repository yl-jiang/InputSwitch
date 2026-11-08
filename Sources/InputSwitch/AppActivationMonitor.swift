import AppKit
import OSLog

final class AppActivationMonitor {
    private let onActivation: (String) -> Void
    private let logger = Logger(subsystem: "com.yulin.InputSwitch", category: "activation")
    private var observer: NSObjectProtocol?

    init(onActivation: @escaping (String) -> Void) {
        self.onActivation = onActivation
    }

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else {
                return
            }
            self?.logger.notice("App activated: \(bundleID, privacy: .public)")
            self?.onActivation(bundleID)
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
