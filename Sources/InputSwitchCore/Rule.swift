public struct Rule: Codable, Hashable, Identifiable {
    public var id: String { bundleID }
    public let bundleID: String
    public let appName: String
    public let inputSourceID: String

    public init(bundleID: String, appName: String, inputSourceID: String) {
        self.bundleID = bundleID
        self.appName = appName
        self.inputSourceID = inputSourceID
    }
}
