import Foundation
import InputSwitchCore

struct SwitchEventStoreTests {
    static func shouldPersistEventsAsJSONL() {
        let fileURL = makeFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = SwitchEventStore(fileURL: fileURL)

        store.record(makeEvent())
        store.record(makeEvent(bundleID: "com.apple.Terminal", appName: "Terminal"))

        let restored = SwitchEventStore(fileURL: fileURL)
        expectEqual(restored.events, store.events, "JSONL 记录后重新读取应还原全部事件")
        expectEqual(restored.events.count, 2, "应读取到两条事件")
        expectEqual(restored.events.first, store.events.first, "事件应完整往返，内存与磁盘一致")
        expectEqual(restored.events.first?.timestamp, store.events.first?.timestamp, "时间戳应按毫秒精度还原")
        expectEqual(restored.events.last?.appName, "Terminal", "事件字段应完整还原")
        expectEqual(restored.errorMessage, nil, "有效数据不应产生错误")
    }

    static func shouldClearFileAndMemory() {
        let fileURL = makeFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let store = SwitchEventStore(fileURL: fileURL)
        store.record(makeEvent())

        store.clear()

        expectEqual(store.events, [], "clear 后内存应为空")
        expectEqual(FileManager.default.fileExists(atPath: fileURL.path), false, "clear 应删除统计文件")
    }

    static func shouldKeepValidEventsWhenLineIsCorrupt() {
        let fileURL = makeFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let dir = fileURL.deletingLastPathComponent()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let validLine = "{\"timestamp\":\"2026-11-08T10:00:00Z\",\"bundleID\":\"com.microsoft.VSCode\",\"appName\":\"Code\",\"inputSourceID\":\"ABC\",\"inputSourceName\":\"ABC\"}"
        try! Data((validLine + "\nnot-json\n").utf8).write(to: fileURL)

        let store = SwitchEventStore(fileURL: fileURL)

        expectEqual(store.events.count, 1, "坏行不应导致其他有效数据丢失")
        expectEqual(store.events.first?.bundleID, "com.microsoft.VSCode", "有效行应被解析")
        expectEqual(store.errorMessage != nil, true, "坏行应产生错误提示")
    }

    static func makeFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("InputSwitchTests.\(UUID().uuidString)")
            .appendingPathComponent("events.jsonl")
    }

    static func makeEvent(
        timestamp: Date = Date(),
        bundleID: String = "com.microsoft.VSCode",
        appName: String = "Visual Studio Code"
    ) -> SwitchEvent {
        SwitchEvent(
            timestamp: timestamp,
            bundleID: bundleID,
            appName: appName,
            inputSourceID: "com.apple.keylayout.ABC",
            inputSourceName: "ABC"
        )
    }
}

struct StatisticsAggregatorTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "GMT")!
        return calendar
    }()

    static func shouldReturnConsecutiveDailyCounts() {
        let day = makeDay(8)
        let events = [
            SwitchEventStoreTests.makeEvent(timestamp: makeDay(6).addingTimeInterval(3600)),
            SwitchEventStoreTests.makeEvent(timestamp: makeDay(7).addingTimeInterval(3600)),
            SwitchEventStoreTests.makeEvent(timestamp: makeDay(7).addingTimeInterval(7200)),
        ]

        let counts = StatisticsAggregator.dailyCounts(events: events, endingOn: day, days: 4, calendar: calendar)

        expectEqual(counts.map(\.count), [0, 1, 2, 0], "应按日期升序返回连续天数，无事件日期为 0")
        expectEqual(
            counts.map { $0.date },
            (5...8).map { calendar.startOfDay(for: makeDay($0)) },
            "日期应连续"
        )
    }

    static func shouldReturnEmptyWhenDaysNotPositive() {
        let counts = StatisticsAggregator.dailyCounts(
            events: [],
            endingOn: makeDay(8),
            days: 0,
            calendar: calendar
        )
        expectEqual(counts, [], "days<=0 应返回空数组")
    }

    static func shouldCountTodayEvents() {
        let now = makeDay(8).addingTimeInterval(43200)
        let events = [
            SwitchEventStoreTests.makeEvent(timestamp: now),
            SwitchEventStoreTests.makeEvent(timestamp: now.addingTimeInterval(60)),
            SwitchEventStoreTests.makeEvent(timestamp: makeDay(7).addingTimeInterval(43200)),
        ]

        expectEqual(StatisticsAggregator.todayCount(events: events, now: now, calendar: calendar), 2, "只统计当天事件")
        expectEqual(
            StatisticsAggregator.todayCount(events: [], now: now, calendar: calendar),
            0,
            "无事件时今天计数为 0"
        )
    }

    static func shouldRankAppsByCountThenName() {
        let events = [
            SwitchEventStoreTests.makeEvent(timestamp: makeDay(8), bundleID: "com.b", appName: "Beta"),
            SwitchEventStoreTests.makeEvent(timestamp: makeDay(8), bundleID: "com.a", appName: "Alpha"),
            SwitchEventStoreTests.makeEvent(timestamp: makeDay(8), bundleID: "com.a", appName: "Alpha"),
            SwitchEventStoreTests.makeEvent(timestamp: makeDay(8), bundleID: "com.c", appName: "Gamma"),
        ]

        let top = StatisticsAggregator.topApps(events: events, limit: 10)

        expectEqual(
            top,
            [
                AppUsage(bundleID: "com.a", appName: "Alpha", count: 2),
                AppUsage(bundleID: "com.b", appName: "Beta", count: 1),
                AppUsage(bundleID: "com.c", appName: "Gamma", count: 1),
            ],
            "应按次数降序，同次数按 appName 本地化排序"
        )
        expectEqual(StatisticsAggregator.topApps(events: events, limit: 1).count, 1, "limit 应截断结果")
    }

    static func shouldReturnEmptyWhenLimitNotPositive() {
        expectEqual(
            StatisticsAggregator.topApps(events: [], limit: 0),
            [],
            "limit<=0 应返回空数组"
        )
    }

    private static func makeDay(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12))!
    }
}
