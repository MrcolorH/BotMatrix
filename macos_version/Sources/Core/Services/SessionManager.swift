import Foundation

/// 单轮对话历史消息
public struct ChatMessage: Codable, Equatable {
    public let role: String // "user" 或 "assistant"
    public let content: String
    public let timestamp: Date

    public init(role: String, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// 每个用户独立的隔离会话空间 (Session)
public final class UserSession {
    public let sessionId: String              // 如 "tg:123456" 或 "qq:654321"
    public private(set) var history: [ChatMessage] = []
    public private(set) var lastActiveAt: Date = Date()

    public init(sessionId: String) {
        self.sessionId = sessionId
    }

    /// 追加新一轮对话，并应用滑动窗口截断
    public func append(userText: String, replyText: String, maxTurns: Int = 10) {
        history.append(ChatMessage(role: "user", content: userText))
        history.append(ChatMessage(role: "assistant", content: replyText))
        lastActiveAt = Date()

        // 保持滑动窗口 (每轮 2 条消息: user + assistant)
        let maxCount = maxTurns * 2
        if history.count > maxCount {
            history.removeFirst(history.count - maxCount)
        }
    }

    /// 格式化为注入 CLI 的上下文文本
    public func formattedHistory() -> String {
        guard !history.isEmpty else { return "" }
        var result = ""
        for msg in history {
            let sender = msg.role == "user" ? "用户" : "助理"
            result += "\(sender): \(msg.content)\n"
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 清空个人会话记忆
    public func clear() {
        history.removeAll()
        lastActiveAt = Date()
    }
}

/// 全局多租户会话隔离管理中枢 (彻底隔绝不同平台、不同用户之间的对话记录)
public final class SessionManager {
    public static let shared = SessionManager()

    private var sessions: [String: UserSession] = [:]
    private let lock = NSLock()

    private init() {}

    /// 获取或新建专属隔离 Session (带超时检测)
    public func getSession(sessionKey: String, timeoutMinutes: Int = 30) -> UserSession {
        lock.lock()
        defer { lock.unlock() }

        if let existing = sessions[sessionKey] {
            // 如果会话闲置超过设定分钟数，自动清空旧上下文开启新会话
            let idleSeconds = Date().timeIntervalSince(existing.lastActiveAt)
            if timeoutMinutes > 0 && idleSeconds > Double(timeoutMinutes * 60) {
                existing.clear()
            }
            return existing
        }

        let newSession = UserSession(sessionId: sessionKey)
        sessions[sessionKey] = newSession
        return newSession
    }

    /// 仅清空特定用户自己的记忆 (绝不影响任何其他人)
    public func clear(sessionKey: String) {
        lock.lock()
        defer { lock.unlock() }
        sessions[sessionKey]?.clear()
    }

    /// 清空所有内存中的会话
    public func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        sessions.removeAll()
    }

    /// 当前活跃会话数量
    public var activeSessionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return sessions.count
    }
}
