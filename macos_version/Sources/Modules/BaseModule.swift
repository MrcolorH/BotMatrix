import Foundation

public protocol BotServiceModule: AnyObject {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var iconName: String { get }
    var isEnabled: Bool { get set }
    var commands: [BotCommand] { get }

    func canHandle(message: TelegramMessage) -> Bool
    func handleMessage(message: TelegramMessage, client: TelegramClient, logger: LogService) async throws

    func canHandleCallback(query: TelegramCallbackQuery) -> Bool
    func handleCallbackQuery(query: TelegramCallbackQuery, client: TelegramClient, logger: LogService) async throws
}

public extension BotServiceModule {
    var commands: [BotCommand] { [] }
}
