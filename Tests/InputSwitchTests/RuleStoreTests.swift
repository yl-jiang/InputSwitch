import Foundation
import InputSwitchCore

struct RuleStoreTests {
    static func shouldReplaceRuleForSameApp() {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RuleStore(defaults: defaults)

        store.save(Rule(bundleID: "com.microsoft.VSCode", appName: "Code", inputSourceID: "ABC"))
        store.save(Rule(bundleID: "com.microsoft.VSCode", appName: "Visual Studio Code", inputSourceID: "US"))

        expectEqual(store.rules.count, 1, "同一 App 不应出现重复规则")
        expectEqual(store.rules.first?.inputSourceID, "US", "保存已有 App 时应更新规则")
    }

    static func shouldPersistRulesAndPausedState() {
        let (suite, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RuleStore(defaults: defaults)
        store.save(Rule(bundleID: "com.microsoft.VSCode", appName: "Visual Studio Code", inputSourceID: "ABC"))
        store.isPaused = true

        let restored = RuleStore(defaults: defaults)

        expectEqual(restored.rules, store.rules, "重启后应恢复规则")
        expectEqual(restored.isPaused, true, "重启后应恢复暂停状态")
    }

    private static func makeDefaults() -> (String, UserDefaults) {
        let suite = "InputSwitchTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("无法创建隔离测试配置")
        }
        return (suite, defaults)
    }
}
