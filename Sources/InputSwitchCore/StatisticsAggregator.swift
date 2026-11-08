import Foundation

public struct DailyCount: Equatable {
    public let date: Date
    public let count: Int

    public init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

public struct AppUsage: Equatable {
    public let bundleID: String
    public let appName: String
    public let count: Int

    public init(bundleID: String, appName: String, count: Int) {
        self.bundleID = bundleID
        self.appName = appName
        self.count = count
    }
}

public enum StatisticsAggregator {
    public static func dailyCounts(
        events: [SwitchEvent],
        endingOn date: Date,
        days: Int,
        calendar: Calendar = .current
    ) -> [DailyCount] {
        guard days > 0 else { return [] }

        let end = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else { return [] }

        var counts: [Date: Int] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.timestamp)
            if day >= start && day <= end {
                counts[day, default: 0] += 1
            }
        }

        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DailyCount(date: day, count: counts[day] ?? 0)
        }
    }

    public static func todayCount(events: [SwitchEvent], now: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        return events.reduce(0) { count, event in
            calendar.startOfDay(for: event.timestamp) == today ? count + 1 : count
        }
    }

    public static func topApps(events: [SwitchEvent], limit: Int) -> [AppUsage] {
        guard limit > 0 else { return [] }

        var counts: [String: (appName: String, count: Int)] = [:]
        for event in events {
            let entry = counts[event.bundleID]
            counts[event.bundleID] = (event.appName, (entry?.count ?? 0) + 1)
        }

        return counts
            .map { AppUsage(bundleID: $0.key, appName: $0.value.appName, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}
