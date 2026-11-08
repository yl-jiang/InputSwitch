public enum SwitchDecision: Equatable {
    case ignore
    case select(String)
    case unavailable(String)

    public static func decide(
        rule: Rule?,
        isPaused: Bool,
        enabledInputSourceIDs: Set<String>
    ) -> SwitchDecision {
        guard !isPaused, let rule else { return .ignore }
        guard enabledInputSourceIDs.contains(rule.inputSourceID) else {
            return .unavailable(rule.inputSourceID)
        }
        return .select(rule.inputSourceID)
    }
}
