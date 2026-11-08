import Combine
import Foundation
import OSLog

public final class SwitchCoordinator: ObservableObject {
    @Published public private(set) var status = "等待 App 切换"
    @Published public private(set) var hasError = false

    private let store: RuleStore
    private let inputSources: InputSourceServicing
    private let eventStore: SwitchEventStore?
    private let logger = Logger(subsystem: "com.yulin.InputSwitch", category: "switch")
    private var lastActivatedBundleID: String?

    public init(store: RuleStore, inputSources: InputSourceServicing, eventStore: SwitchEventStore? = nil) {
        self.store = store
        self.inputSources = inputSources
        self.eventStore = eventStore
    }

    public func handleActivatedApp(bundleID: String) {
        guard bundleID != lastActivatedBundleID else { return }
        lastActivatedBundleID = bundleID

        guard !store.isPaused, let rule = store.rule(for: bundleID) else {
            logger.notice("Ignored activation: \(bundleID, privacy: .public)")
            return
        }

        let sources = inputSources.availableInputSources()
        let decision = SwitchDecision.decide(
            rule: rule,
            isPaused: false,
            enabledInputSourceIDs: Set(sources.map(\.id))
        )

        switch decision {
        case .ignore:
            return
        case .unavailable:
            setError("目标输入法不可用")
        case .select:
            select(rule: rule, sources: sources)
        }
    }

    private func select(rule: Rule, sources: [InputSourceInfo]) {
        logger.notice("Selecting input source: \(rule.inputSourceID, privacy: .public)")
        guard inputSources.selectInputSource(id: rule.inputSourceID) else {
            setError("系统调用未能选择输入法")
            return
        }

        let name = sources.first { $0.id == rule.inputSourceID }?.name ?? rule.inputSourceID
        status = "已切换到 \(name)"
        hasError = false
        eventStore?.record(SwitchEvent(
            timestamp: Date(),
            bundleID: rule.bundleID,
            appName: rule.appName,
            inputSourceID: rule.inputSourceID,
            inputSourceName: name
        ))
        logger.notice("Input source selection accepted: \(rule.inputSourceID, privacy: .public)")
    }

    private func setError(_ message: String) {
        logger.error("Switch failed: \(message, privacy: .public)")
        status = message
        hasError = true
    }
}
