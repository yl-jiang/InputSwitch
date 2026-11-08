import Foundation

public struct SwitchEvent: Codable, Equatable {
    public let timestamp: Date
    public let bundleID: String
    public let appName: String
    public let inputSourceID: String
    public let inputSourceName: String

    public init(
        timestamp: Date,
        bundleID: String,
        appName: String,
        inputSourceID: String,
        inputSourceName: String
    ) {
        self.timestamp = timestamp
        self.bundleID = bundleID
        self.appName = appName
        self.inputSourceID = inputSourceID
        self.inputSourceName = inputSourceName
    }
}
