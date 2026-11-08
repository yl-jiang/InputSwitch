public struct InputSourceInfo: Equatable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public protocol InputSourceServicing {
    func availableInputSources() -> [InputSourceInfo]
    func currentInputSourceID() -> String?
    func selectInputSource(id: String) -> Bool
}
