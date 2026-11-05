import Foundation

/// 每日晨报订阅用户信息
public struct NewsSubscriber: Codable, Identifiable, Equatable {
    public var id: Int64 { userId }
    public let userId: Int64
    public var chatId: Int64
    public var username: String?
    public var firstName: String
    public var tags: [String]
    public var subscribedAt: Date
    public var isActive: Bool
    public var lastReceivedAt: Date?

    public init(
        userId: Int64,
        chatId: Int64,
        username: String?,
        firstName: String,
        tags: [String] = ["AI发展", "机器人发展", "大肥鱼现状"],
        subscribedAt: Date = Date(),
        isActive: Bool = true,
        lastReceivedAt: Date? = nil
    ) {
        self.userId = userId
        self.chatId = chatId
        self.username = username
        self.firstName = firstName
        self.tags = tags
        self.subscribedAt = subscribedAt
        self.isActive = isActive
        self.lastReceivedAt = lastReceivedAt
    }

    public var displayName: String {
        if !firstName.isEmpty { return firstName }
        if let u = username, !u.isEmpty { return "@\(u)" }
        return "用户 \(userId)"
    }
}

/// 每日晨报持久化配置
public struct MorningNewsData: Codable {
    public var subscribers: [NewsSubscriber]
    public var pushHour: Int
    public var pushMinute: Int
    public var lastPushDate: String
    public var defaultTags: [String]

    public init(
        subscribers: [NewsSubscriber] = [],
        pushHour: Int = 8,
        pushMinute: Int = 0,
        lastPushDate: String = "",
        defaultTags: [String] = ["AI发展", "机器人发展", "大肥鱼现状"]
    ) {
        self.subscribers = subscribers
        self.pushHour = pushHour
        self.pushMinute = pushMinute
        self.lastPushDate = lastPushDate
        self.defaultTags = defaultTags
    }
}
