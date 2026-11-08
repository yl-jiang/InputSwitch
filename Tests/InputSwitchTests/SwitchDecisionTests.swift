import Foundation
import InputSwitchCore

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    guard actual == expected else {
        FileHandle.standardError.write(Data("FAIL: \(message)；实际值：\(actual)，预期值：\(expected)\n".utf8))
        exit(1)
    }
}

@main
struct InputSwitchTests {
    static let abc = "com.apple.keylayout.ABC"
    static let vscodeRule = Rule(
        bundleID: "com.microsoft.VSCode",
        appName: "Visual Studio Code",
        inputSourceID: abc
    )

    static func main() {
        shouldIgnoreAppWithoutRule()
        shouldIgnoreWhenPaused()
        shouldReportUnavailableInputSource()
        shouldSelectConfiguredInputSource()
        RuleStoreTests.shouldReplaceRuleForSameApp()
        RuleStoreTests.shouldPersistRulesAndPausedState()
        SwitchCoordinatorTests.shouldSwitchToConfiguredInputSource()
        SwitchCoordinatorTests.shouldNotRetryFailedSwitchForSameActivation()
        SwitchCoordinatorTests.shouldNotReadInputSourcesForUnconfiguredApp()
        SwitchCoordinatorTests.shouldSelectEvenWhenCachedInputSourceAppearsCorrect()
        SwitchEventStoreTests.shouldPersistEventsAsJSONL()
        SwitchEventStoreTests.shouldClearFileAndMemory()
        SwitchEventStoreTests.shouldKeepValidEventsWhenLineIsCorrupt()
        StatisticsAggregatorTests.shouldReturnConsecutiveDailyCounts()
        StatisticsAggregatorTests.shouldReturnEmptyWhenDaysNotPositive()
        StatisticsAggregatorTests.shouldCountTodayEvents()
        StatisticsAggregatorTests.shouldRankAppsByCountThenName()
        StatisticsAggregatorTests.shouldReturnEmptyWhenLimitNotPositive()
        SwitchCoordinatorTests.shouldRecordAcceptedSwitch()
        print("PASS: 19 tests")
    }

    static func shouldIgnoreAppWithoutRule() {
        expectEqual(decide(rule: nil), .ignore, "未配置的 App 不应切换输入法")
    }

    static func shouldIgnoreWhenPaused() {
        expectEqual(decide(isPaused: true), .ignore, "暂停时不应切换输入法")
    }

    static func shouldReportUnavailableInputSource() {
        expectEqual(decide(enabledInputSourceIDs: []), .unavailable(abc), "目标输入法不可用时应该报告")
    }

    static func shouldSelectConfiguredInputSource() {
        expectEqual(decide(), .select(abc), "进入已配置 App 时应该选择目标输入法")
    }

    static func decide(
        rule: Rule? = vscodeRule,
        isPaused: Bool = false,
        enabledInputSourceIDs: Set<String> = [abc]
    ) -> SwitchDecision {
        SwitchDecision.decide(
            rule: rule,
            isPaused: isPaused,
            enabledInputSourceIDs: enabledInputSourceIDs
        )
    }
}
