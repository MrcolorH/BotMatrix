import Foundation

/// OneBot v11 原生 WebSocket 客户端 (免公网 IP，用于连接本地 NapCat / LLOneBot / Lagrange)
public final class OneBotQQClient {
    public static let shared = OneBotQQClient()

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    public private(set) var isConnected: Bool = false
    private var targetUrl: URL?
    private var onEventCallback: (([String: Any]) -> Void)?

    private var isIntentionalDisconnect: Bool = false
    private let logger = LogService.shared

    private init() {}

    /// 连接 OneBot WebSocket 终端
    public func connect(url: URL, onEvent: @escaping ([String: Any]) -> Void) {
        disconnect()

        self.targetUrl = url
        self.onEventCallback = onEvent
        self.isIntentionalDisconnect = false

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)

        let task = session!.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()

        self.isConnected = true
        self.logger.success("QQ", "已发起连接至本地 OneBot QQ 终端: \(url.absoluteString)")

        // 启动消息接收循环
        receiveLoop()
    }

    /// 断开连接
    public func disconnect() {
        isIntentionalDisconnect = true
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func receiveLoop() {
        guard let task = webSocketTask, isConnected else { return }

        task.receive { [weak self] result in
            guard let self = self, self.isConnected else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                        self.onEventCallback?(json)
                    }
                case .data(let data):
                    if let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                        self.onEventCallback?(json)
                    }
                @unknown default:
                    break
                }
                // 继续监听下一个事件
                self.receiveLoop()

            case .failure(let error):
                if !self.isIntentionalDisconnect {
                    self.logger.warn("QQ", "与 QQ 终端断开: \(error.localizedDescription)，5秒后自动尝试重连...")
                    self.isConnected = false
                    self.webSocketTask = nil

                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
                        guard let self = self, !self.isIntentionalDisconnect else { return }
                        if let u = self.targetUrl, let cb = self.onEventCallback {
                            self.connect(url: u, onEvent: cb)
                        }
                    }
                }
            }
        }
    }

    /// 设置 QQ 输入中状态 (NapCat / OneBot 11 扩展: set_input_status)
    /// - Parameters:
    ///   - userId: 目标 QQ 号码
    ///   - eventType: 事件类型 (1: 文字输入中, 0: 状态中)
    public func setInputStatus(userId: Int64, eventType: Int = 1) async throws {
        guard let task = webSocketTask, isConnected else { return }

        let payload: [String: Any] = [
            "action": "set_input_status",
            "params": [
                "user_id": "\(userId)",
                "event_type": eventType
            ],
            "echo": "input_status_\(Int(Date().timeIntervalSince1970 * 1000))"
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let jsonStr = String(data: data, encoding: .utf8) else { return }
        try await task.send(.string(jsonStr))
    }

    /// 发送 QQ 私聊文本消息 (支持长文本自动拆分)
    public func sendPrivateMsg(userId: Int64, text: String) async throws {
        guard webSocketTask != nil, isConnected else {
            throw NSError(domain: "OneBotQQClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "QQ 终端未连接"])
        }

        let maxChunkSize = 3500
        if text.count > maxChunkSize {
            var remaining = text
            while !remaining.isEmpty {
                let takeCount = min(maxChunkSize, remaining.count)
                let chunk = String(remaining.prefix(takeCount))
                remaining = String(remaining.dropFirst(takeCount))

                try await sendRawPrivateMsg(userId: userId, text: chunk)
                if !remaining.isEmpty {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
        } else {
            try await sendRawPrivateMsg(userId: userId, text: text)
        }
    }

    private func sendRawPrivateMsg(userId: Int64, text: String) async throws {
        guard let task = webSocketTask, isConnected else { return }

        let payload: [String: Any] = [
            "action": "send_private_msg",
            "params": [
                "user_id": userId,
                "message": text
            ],
            "echo": "msg_\(Int(Date().timeIntervalSince1970 * 1000))"
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let jsonStr = String(data: data, encoding: .utf8) else { return }
        try await task.send(.string(jsonStr))
    }

    /// 发送 QQ 群聊文本消息 (可选带引用/AT，支持长文本拆分)
    public func sendGroupMsg(groupId: Int64, text: String, replyToUser: Int64? = nil) async throws {
        guard webSocketTask != nil, isConnected else {
            throw NSError(domain: "OneBotQQClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "QQ 终端未连接"])
        }

        var messageContent = text
        if let uid = replyToUser {
            messageContent = "[CQ:at,qq=\(uid)] " + text
        }

        let maxChunkSize = 3500
        if messageContent.count > maxChunkSize {
            var remaining = messageContent
            while !remaining.isEmpty {
                let takeCount = min(maxChunkSize, remaining.count)
                let chunk = String(remaining.prefix(takeCount))
                remaining = String(remaining.dropFirst(takeCount))

                try await sendRawGroupMsg(groupId: groupId, text: chunk)
                if !remaining.isEmpty {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
        } else {
            try await sendRawGroupMsg(groupId: groupId, text: messageContent)
        }
    }

    private func sendRawGroupMsg(groupId: Int64, text: String) async throws {
        guard let task = webSocketTask, isConnected else { return }

        let payload: [String: Any] = [
            "action": "send_group_msg",
            "params": [
                "group_id": groupId,
                "message": text
            ],
            "echo": "group_msg_\(Int(Date().timeIntervalSince1970 * 1000))"
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let jsonStr = String(data: data, encoding: .utf8) else { return }
        try await task.send(.string(jsonStr))
    }

    /// 主动获取登录的 QQ 账号信息
    public func fetchLoginInfo() async throws {
        guard let task = webSocketTask, isConnected else { return }
        let payload: [String: Any] = [
            "action": "get_login_info",
            "params": [:],
            "echo": "sync_login_info"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        if let jsonStr = String(data: data, encoding: .utf8) {
            try await task.send(.string(jsonStr))
        }
    }
}
