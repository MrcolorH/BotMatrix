import Foundation

public enum TelegramError: LocalizedError {
    case invalidToken
    case networkError(String)
    case apiError(code: Int, description: String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Telegram Bot Token 无效或为空"
        case .networkError(let msg):
            return "网络连接错误: \(msg)"
        case .apiError(let code, let desc):
            return "Telegram API 错误 (\(code)): \(desc)"
        case .decodingError(let msg):
            return "解析响应失败: \(msg)"
        }
    }
}

public final class TelegramClient {
    public let token: String
    private let session: URLSession

    public init(token: String) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    private var baseUrl: URL {
        URL(string: "https://api.telegram.org/bot\(token)/")!
    }

    private func executePost<Req: Encodable, Res: Codable>(
        method: String,
        payload: Req? = nil
    ) async throws -> Res {
        guard !token.isEmpty else { throw TelegramError.invalidToken }
        let endpoint = baseUrl.appendingPathComponent(method)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let payload = payload {
            request.httpBody = try JSONEncoder().encode(payload)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TelegramError.networkError("无效的 HTTP 响应")
        }

        let decoder = JSONDecoder()
        do {
            let apiRes = try decoder.decode(TelegramApiResponse<Res>.self, from: data)
            if apiRes.ok, let result = apiRes.result {
                return result
            } else {
                throw TelegramError.apiError(
                    code: apiRes.errorCode ?? httpResponse.statusCode,
                    description: apiRes.description ?? "未知错误"
                )
            }
        } catch let err as TelegramError {
            throw err
        } catch {
            if let rawString = String(data: data, encoding: .utf8) {
                throw TelegramError.decodingError("\(error.localizedDescription) [原文: \(rawString.prefix(120))]")
            }
            throw TelegramError.decodingError(error.localizedDescription)
        }
    }

    /// 获取机器人自身信息
    public func getMe() async throws -> TelegramUser {
        struct EmptyBody: Encodable {}
        return try await executePost(method: "getMe", payload: Optional<EmptyBody>.none)
    }

    /// 删除 Webhook，避免 getUpdates 返回 409 Conflict
    public func deleteWebhook(dropPendingUpdates: Bool = false) async throws {
        struct Body: Encodable {
            let drop_pending_updates: Bool
        }
        let _: Bool = try await executePost(method: "deleteWebhook", payload: Body(drop_pending_updates: dropPendingUpdates))
    }

    /// 长轮询拉取更新
    public func getUpdates(offset: Int, timeout: Int = 20) async throws -> [TelegramUpdate] {
        struct Body: Encodable {
            let offset: Int
            let timeout: Int
            let allowed_updates: [String]
        }
        let body = Body(offset: offset, timeout: timeout, allowed_updates: ["message", "callback_query"])
        return try await executePost(method: "getUpdates", payload: body)
    }

    /// 发送文本消息
    @discardableResult
    public func sendMessage(
        chatId: Int64,
        text: String,
        parseMode: String? = "HTML",
        disableWebPagePreview: Bool = false,
        replyMarkup: InlineKeyboardMarkup? = nil
    ) async throws -> TelegramMessage {
        struct Body: Encodable {
            let chat_id: Int64
            let text: String
            let parse_mode: String?
            let disable_web_page_preview: Bool
            let reply_markup: InlineKeyboardMarkup?
        }
        let body = Body(
            chat_id: chatId,
            text: text,
            parse_mode: parseMode,
            disable_web_page_preview: disableWebPagePreview,
            reply_markup: replyMarkup
        )
        return try await executePost(method: "sendMessage", payload: body)
    }

    /// 发送照片
    @discardableResult
    public func sendPhoto(
        chatId: Int64,
        photoUrl: String,
        caption: String? = nil,
        parseMode: String? = "HTML",
        hasSpoiler: Bool = false,
        replyMarkup: InlineKeyboardMarkup? = nil
    ) async throws -> TelegramMessage {
        struct Body: Encodable {
            let chat_id: Int64
            let photo: String
            let caption: String?
            let parse_mode: String?
            let has_spoiler: Bool
            let reply_markup: InlineKeyboardMarkup?
        }
        let body = Body(
            chat_id: chatId,
            photo: photoUrl,
            caption: caption,
            parse_mode: parseMode,
            has_spoiler: hasSpoiler,
            reply_markup: replyMarkup
        )
        return try await executePost(method: "sendPhoto", payload: body)
    }

    /// 发送视频
    @discardableResult
    public func sendVideo(
        chatId: Int64,
        videoUrl: String,
        caption: String? = nil,
        parseMode: String? = "HTML",
        replyMarkup: InlineKeyboardMarkup? = nil
    ) async throws -> TelegramMessage {
        struct Body: Encodable {
            let chat_id: Int64
            let video: String
            let caption: String?
            let parse_mode: String?
            let reply_markup: InlineKeyboardMarkup?
        }
        let body = Body(
            chat_id: chatId,
            video: videoUrl,
            caption: caption,
            parse_mode: parseMode,
            reply_markup: replyMarkup
        )
        return try await executePost(method: "sendVideo", payload: body)
    }

    /// 编辑消息文本
    public func editMessageText(
        chatId: Int64,
        messageId: Int,
        text: String,
        parseMode: String? = "HTML",
        replyMarkup: InlineKeyboardMarkup? = nil
    ) async throws {
        struct Body: Encodable {
            let chat_id: Int64
            let message_id: Int
            let text: String
            let parse_mode: String?
            let reply_markup: InlineKeyboardMarkup?
        }
        let body = Body(
            chat_id: chatId,
            message_id: messageId,
            text: text,
            parse_mode: parseMode,
            reply_markup: replyMarkup
        )
        let _: TelegramMessage = try await executePost(method: "editMessageText", payload: body)
    }

    /// 编辑媒体标题 (Caption)
    public func editMessageCaption(
        chatId: Int64,
        messageId: Int,
        caption: String,
        parseMode: String? = "HTML",
        replyMarkup: InlineKeyboardMarkup? = nil
    ) async throws {
        struct Body: Encodable {
            let chat_id: Int64
            let message_id: Int
            let caption: String
            let parse_mode: String?
            let reply_markup: InlineKeyboardMarkup?
        }
        let body = Body(
            chat_id: chatId,
            message_id: messageId,
            caption: caption,
            parse_mode: parseMode,
            reply_markup: replyMarkup
        )
        let _: TelegramMessage = try await executePost(method: "editMessageCaption", payload: body)
    }

    /// 发送聊天状态动作 (例如 "typing" 正在输入中...)
    public func sendChatAction(chatId: Int64, action: String = "typing") async throws {
        struct Body: Encodable {
            let chat_id: Int64
            let action: String
        }
        let _: Bool = try await executePost(method: "sendChatAction", payload: Body(chat_id: chatId, action: action))
    }

    /// 回答 CallbackQuery
    public func answerCallbackQuery(
        callbackQueryId: String,
        text: String? = nil,
        showAlert: Bool = false
    ) async throws {
        struct Body: Encodable {
            let callback_query_id: String
            let text: String?
            let show_alert: Bool
        }
        let body = Body(
            callback_query_id: callbackQueryId,
            text: text,
            show_alert: showAlert
        )
        let _: Bool = try await executePost(method: "answerCallbackQuery", payload: body)
    }

    /// 注册或更新机器人命令菜单 (让用户在 Telegram 输入框打 / 时弹出指令提示气泡)
    public func setMyCommands(commands: [BotCommand]) async throws {
        struct Body: Encodable {
            let commands: [BotCommand]
        }
        let body = Body(commands: commands)
        let _: Bool = try await executePost(method: "setMyCommands", payload: body)
    }
}
