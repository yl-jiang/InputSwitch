import Combine
import Foundation

public final class SwitchEventStore: ObservableObject {
    @Published public private(set) var events: [SwitchEvent]
    @Published public private(set) var errorMessage: String?

    private let fileURL: URL

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析时间戳"
            )
        }
        return decoder
    }()

    public init(fileURL: URL) {
        self.fileURL = fileURL

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            events = []
            return
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            events = []
            errorMessage = "无法读取统计数据"
            return
        }

        var parsed: [SwitchEvent] = []
        var hasCorruptLine = false
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true) {
            if let event = try? SwitchEventStore.decoder.decode(SwitchEvent.self, from: Data(line.utf8)) {
                parsed.append(event)
            } else {
                hasCorruptLine = true
            }
        }
        events = parsed
        errorMessage = hasCorruptLine ? "部分统计数据损坏，已保留有效记录" : nil
    }

    public func record(_ event: SwitchEvent) {
        do {
            let line = try SwitchEventStore.encoder.encode(event)
            // 写盘前编码、解码回读：ISO8601 只保留毫秒，内存中的事件必须与落盘内容一致
            let normalized = try SwitchEventStore.decoder.decode(SwitchEvent.self, from: line)
            var data = line
            data.append(0x0A)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: fileURL, options: .atomic)
            }
            events.append(normalized)
            errorMessage = nil
        } catch {
            errorMessage = "无法记录切换事件"
        }
    }

    public func clear() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            events = []
            errorMessage = nil
        } catch {
            errorMessage = "无法清理统计数据"
        }
    }
}
