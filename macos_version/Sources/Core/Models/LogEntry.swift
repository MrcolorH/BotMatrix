import Foundation

public enum LogLevel: String, CaseIterable, Codable {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARN"
    case error = "ERROR"

    public var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

public struct LogEntry: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let tag: String
    public let message: String

    public init(level: LogLevel, tag: String, message: String, timestamp: Date = Date()) {
        self.level = level
        self.tag = tag
        self.message = message
        self.timestamp = timestamp
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    public var plainTextLine: String {
        "[\(formattedTime)] [\(level.rawValue)] [\(tag)] \(message)"
    }
}
