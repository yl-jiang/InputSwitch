import Foundation
import InputSwitchCore

final class FakeInputSourceService: InputSourceServicing {
    var sources = [InputSourceInfo(id: "ABC", name: "ABC")]
    var currentID = "Doubao"
    var selectionSucceeds = true
    var availableCallCount = 0
    var currentCallCount = 0
    var selectCallCount = 0

    func availableInputSources() -> [InputSourceInfo] {
        availableCallCount += 1
        return sources
    }

    func currentInputSourceID() -> String? {
        currentCallCount += 1
        return currentID
    }

    func selectInputSource(id: String) -> Bool {
        selectCallCount += 1
        if selectionSucceeds { currentID = id }
        return selectionSucceeds
    }
}

struct SwitchCoordinatorTests {
    static func shouldSwitchToConfiguredInputSource() {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RuleStore(defaults: defaults)
        store.save(Rule(bundleID: "com.microsoft.VSCode", appName: "Visual Studio Code", inputSourceID: "ABC"))
        let inputSources = FakeInputSourceService()
        let coordinator = SwitchCoordinator(store: store, inputSources: inputSources)

        coordinator.handleActivatedApp(bundleID: "com.microsoft.VSCode")

        expectEqual(inputSources.currentID, "ABC", "激活 VS Code 时应切换到 ABC")
        expectEqual(inputSources.selectCallCount, 1, "一次激活只应调用一次系统切换")
        expectEqual(coordinator.hasError, false, "成功切换不应显示错误")
    }

    static func shouldNotRetryFailedSwitchForSameActivation() {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RuleStore(defaults: defaults)
        store.save(Rule(bundleID: "com.microsoft.VSCode", appName: "Visual Studio Code", inputSourceID: "ABC"))
        let inputSources = FakeInputSourceService()
        inputSources.selectionSucceeds = false
        let coordinator = SwitchCoordinator(store: store, inputSources: inputSources)

        coordinator.handleActivatedApp(bundleID: "com.microsoft.VSCode")
        coordinator.handleActivatedApp(bundleID: "com.microsoft.VSCode")

        expectEqual(inputSources.selectCallCount, 1, "同一次激活失败后不应重试")
        expectEqual(coordinator.hasError, true, "切换失败应显示错误")
    }

    static func shouldNotReadInputSourcesForUnconfiguredApp() {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let inputSources = FakeInputSourceService()
        let coordinator = SwitchCoordinator(store: RuleStore(defaults: defaults), inputSources: inputSources)

        coordinator.handleActivatedApp(bundleID: "com.apple.finder")

        expectEqual(inputSources.availableCallCount, 0, "未配置 App 不应枚举输入法")
        expectEqual(inputSources.currentCallCount, 0, "未配置 App 不应读取当前输入法")
        expectEqual(inputSources.selectCallCount, 0, "未配置 App 不应切换输入法")
    }

    static func shouldSelectEvenWhenCachedInputSourceAppearsCorrect() {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RuleStore(defaults: defaults)
        store.save(Rule(bundleID: "com.microsoft.VSCode", appName: "Visual Studio Code", inputSourceID: "ABC"))
        let inputSources = FakeInputSourceService()
        inputSources.currentID = "ABC"
        let coordinator = SwitchCoordinator(store: store, inputSources: inputSources)

        coordinator.handleActivatedApp(bundleID: "com.microsoft.VSCode")

        expectEqual(inputSources.selectCallCount, 1, "缓存显示已正确时仍应执行本次激活的切换")
    }

    static func shouldRecordAcceptedSwitch() {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let eventStore = SwitchEventStore(fileURL: directory.appendingPathComponent("events.jsonl"))
        let store = RuleStore(defaults: defaults)
        store.save(Rule(bundleID: "com.microsoft.VSCode", appName: "Visual Studio Code", inputSourceID: "ABC"))
        let inputSources = FakeInputSourceService()
        let coordinator = SwitchCoordinator(store: store, inputSources: inputSources, eventStore: eventStore)

        coordinator.handleActivatedApp(bundleID: "com.microsoft.VSCode")

        expectEqual(eventStore.events.count, 1, "系统接受切换后应记录一次真实事件")
        expectEqual(eventStore.events.first?.bundleID, "com.microsoft.VSCode", "统计应记录实际 App")
    }

    private static func makeDefaults() -> (String, UserDefaults) {
        let suite = "InputSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("无法创建隔离测试配置")
        }
        return (suite, defaults)
    }
}
