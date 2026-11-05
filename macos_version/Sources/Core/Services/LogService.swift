import Foundation
import Combine

public final class LogService: ObservableObject {
    public static let shared = LogService()

    @Published public private(set) var entries: [LogEntry] = []
    private let maxEntries = 1000
    private let queue = DispatchQueue(label: "com.tgbot.mac.logservice", qos: .utility)

    private let logFileUrl: URL = {
        let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".tgbot/logs")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("app.log")
    }()

    public init() {}

    public func log(level: LogLevel, tag: String, message: String) {
        let entry = LogEntry(level: level, tag: tag, message: message)
        let line = "\(entry.plainTextLine)\n"
        print(entry.plainTextLine)

        queue.async { [weak self] in
            guard let self = self else { return }
            if let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: self.logFileUrl) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    try? data.write(to: self.logFileUrl, options: .atomic)
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }

    public func info(_ tag: String, _ message: String) {
        log(level: .info, tag: tag, message: message)
    }

    public func success(_ tag: String, _ message: String) {
        log(level: .success, tag: tag, message: message)
    }

    public func warn(_ tag: String, _ message: String) {
        log(level: .warning, tag: tag, message: message)
    }

    public func error(_ tag: String, _ message: String) {
        log(level: .error, tag: tag, message: message)
    }

    public func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }

    public func exportText() -> String {
        entries.map { $0.plainTextLine }.joined(separator: "\n")
    }
}
