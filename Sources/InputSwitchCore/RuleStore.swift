import Combine
import Foundation

public final class RuleStore: ObservableObject {
    @Published public private(set) var rules: [Rule]
    @Published public private(set) var errorMessage: String?
    @Published public var isPaused: Bool {
        didSet { defaults.set(isPaused, forKey: "isPaused") }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isPaused = defaults.bool(forKey: "isPaused")

        do {
            if let data = defaults.data(forKey: "rules") {
                rules = try JSONDecoder().decode([Rule].self, from: data)
            } else {
                rules = []
            }
        } catch {
            rules = []
            errorMessage = "无法读取已保存的规则"
        }
    }

    public func rule(for bundleID: String) -> Rule? {
        rules.first { $0.bundleID == bundleID }
    }

    public func save(_ rule: Rule) {
        var updated = rules
        if let index = updated.firstIndex(where: { $0.bundleID == rule.bundleID }) {
            updated[index] = rule
        } else {
            updated.append(rule)
        }
        updated.sort { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
        persist(updated)
    }

    public func delete(id: String) {
        persist(rules.filter { $0.id != id })
    }

    private func persist(_ updated: [Rule]) {
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: "rules")
            rules = updated
            errorMessage = nil
        } catch {
            errorMessage = "无法保存规则"
        }
    }
}
