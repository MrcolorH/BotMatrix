import Foundation

public struct BotCommand: Codable, Equatable {
    public let command: String
    public let description: String

    public init(command: String, description: String) {
        self.command = command.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.description = description
    }
}

public struct TelegramUser: Codable, Equatable {
    public let id: Int64
    public let isBot: Bool
    public let firstName: String
    public let username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
        case firstName = "first_name"
        case username
    }

    public var displayName: String {
        if let username = username, !username.isEmpty {
            return "@\(username) (\(firstName))"
        }
        return firstName
    }
}

public struct TelegramChat: Codable, Equatable {
    public let id: Int64
    public let type: String
    public let title: String?
    public let username: String?
    public let firstName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case username
        case firstName = "first_name"
    }
}

public struct TelegramMessage: Codable, Equatable {
    public let messageId: Int
    public let from: TelegramUser?
    public let chat: TelegramChat
    public let text: String?
    public let date: Int

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case from
        case chat
        case text
        case date
    }
}

public struct TelegramCallbackQuery: Codable, Equatable {
    public let id: String
    public let from: TelegramUser
    public let message: TelegramMessage?
    public let data: String?

    enum CodingKeys: String, CodingKey {
        case id
        case from
        case message
        case data
    }
}

public struct TelegramUpdate: Codable, Equatable {
    public let updateId: Int
    public let message: TelegramMessage?
    public let callbackQuery: TelegramCallbackQuery?

    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
        case callbackQuery = "callback_query"
    }
}

public struct InlineKeyboardButton: Codable, Equatable {
    public let text: String
    public let callbackData: String?
    public let url: String?

    enum CodingKeys: String, CodingKey {
        case text
        case callbackData = "callback_data"
        case url
    }

    public init(text: String, callbackData: String? = nil, url: String? = nil) {
        self.text = text
        self.callbackData = callbackData
        self.url = url
    }
}

public struct InlineKeyboardMarkup: Codable, Equatable {
    public let inlineKeyboard: [[InlineKeyboardButton]]

    enum CodingKeys: String, CodingKey {
        case inlineKeyboard = "inline_keyboard"
    }

    public init(inlineKeyboard: [[InlineKeyboardButton]]) {
        self.inlineKeyboard = inlineKeyboard
    }
}

public struct TelegramApiResponse<T: Codable>: Codable {
    public let ok: Bool
    public let result: T?
    public let description: String?
    public let errorCode: Int?

    enum CodingKeys: String, CodingKey {
        case ok
        case result
        case description
        case errorCode = "error_code"
    }
}
