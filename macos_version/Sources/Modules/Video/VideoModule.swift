import Foundation

public struct CachedCard {
    public let cardId: String
    public let chatId: Int64
    public let messageId: Int
    public let isPhoto: Bool
    public let platform: VideoPlatform
    public let result: VideoParseResult
    public var isFolded: Bool
    public var lastUnfoldedAt: Date
}

public actor VideoCardStore {
    private var cards: [String: CachedCard] = [:]

    public init() {}

    public func save(_ card: CachedCard) {
        cards[card.cardId] = card
    }

    public func get(_ cardId: String) -> CachedCard? {
        return cards[cardId]
    }

    public func setFolded(_ cardId: String, isFolded: Bool) {
        if var c = cards[cardId] {
            c.isFolded = isFolded
            if !isFolded {
                c.lastUnfoldedAt = Date()
            }
            cards[cardId] = c
        }
    }
}

public final class VideoModule: BotServiceModule, ObservableObject {
    public let id = "video_resolver"
    public let name = "全网视频直链解析与隐私保护"
    public let description = "自主识别 Twitter/X、TikTok/抖音、B站、YouTube 视频直链，支持图文双重毛玻璃遮罩与随时可逆折叠。"
    public let iconName = "link.badge.plus"

    @Published public var isEnabled: Bool = true
    @Published public var twitterDownApiKey: String = ""

    private let cardStore = VideoCardStore()

    public init(storage: StorageService) {
        self.isEnabled = storage.twitterModuleEnabled
        self.twitterDownApiKey = storage.twitterDownApiKey
    }

    public func canHandle(message: TelegramMessage) -> Bool {
        guard isEnabled && StorageService.shared.videoEnabledTG, let text = message.text else { return false }
        return UniversalVideoResolver.isVideoLinkMessage(text)
    }

    public func handleMessage(message: TelegramMessage, client: TelegramClient, logger: LogService) async throws {
        guard let text = message.text,
              let rawUrl = UniversalVideoResolver.extractUrl(from: text) else { return }

        let chatId = message.chat.id
        let userTag = message.chat.username ?? "\(chatId)"

        logger.info("Video", "收到来自 [\(userTag)] 的链接: \(rawUrl)")

        let waitingMsg = try? await client.sendMessage(
            chatId: chatId,
            text: "🔍 <b>正在识别并解析视频直链...</b>\n支持 Twitter/X、TikTok/抖音、B站等多平台并发提取。",
            parseMode: "HTML"
        )

        do {
            let (platform, result) = try await UniversalVideoResolver.resolve(
                rawUrl: rawUrl,
                twitterApiKey: twitterDownApiKey
            )

            let cardId = "card_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 1000...9999))"

            // 构造未折叠文案 (带剧透毛玻璃)
            let unfoldedText = buildUnfoldedHtml(platform: platform, result: result)
            let unfoldedKeyboard = buildUnfoldedKeyboard(cardId: cardId, result: result)

            var isPhoto = false
            var finalMessageId = waitingMsg?.messageId ?? 0

            // 尝试优先发送带毛玻璃的封面图
            if let thumb = result.thumbnail, !thumb.isEmpty {
                do {
                    let photoMsg = try await client.sendPhoto(
                        chatId: chatId,
                        photoUrl: thumb,
                        caption: unfoldedText,
                        parseMode: "HTML",
                        hasSpoiler: true,
                        replyMarkup: unfoldedKeyboard
                    )
                    isPhoto = true
                    finalMessageId = photoMsg.messageId

                    if let wid = waitingMsg?.messageId {
                        _ = try? await client.editMessageText(
                            chatId: chatId,
                            messageId: wid,
                            text: "✅ <b>解析完成</b>",
                            parseMode: "HTML"
                        )
                    }
                } catch {
                    isPhoto = false
                }
            }

            if !isPhoto {
                if let wid = waitingMsg?.messageId {
                    _ = try? await client.editMessageText(
                        chatId: chatId,
                        messageId: wid,
                        text: unfoldedText,
                        parseMode: "HTML",
                        replyMarkup: unfoldedKeyboard
                    )
                    finalMessageId = wid
                } else {
                    let msg = try await client.sendMessage(
                        chatId: chatId,
                        text: unfoldedText,
                        parseMode: "HTML",
                        replyMarkup: unfoldedKeyboard
                    )
                    finalMessageId = msg.messageId
                }
            }

            let card = CachedCard(
                cardId: cardId,
                chatId: chatId,
                messageId: finalMessageId,
                isPhoto: isPhoto,
                platform: platform,
                result: result,
                isFolded: false,
                lastUnfoldedAt: Date()
            )
            await cardStore.save(card)

            logger.success("Video", "成功为 [\(userTag)] 返回 [\(platform.rawValue)] 视频直链 (\(result.resolution))")

            // 触发自动折叠定时器 (根据设置，默认 5 分钟后自动收起防误窥)
            scheduleAutoFold(cardId: cardId, client: client, logger: logger)

        } catch {
            logger.error("Video", "解析视频链接失败: \(error.localizedDescription)")
            let errorText = "❌ <b>视频直链提取失败</b>\n原因: \(error.localizedDescription)"
            if let wid = waitingMsg?.messageId {
                _ = try? await client.editMessageText(
                    chatId: chatId,
                    messageId: wid,
                    text: errorText,
                    parseMode: "HTML"
                )
            } else {
                _ = try? await client.sendMessage(chatId: chatId, text: errorText, parseMode: "HTML")
            }
        }
    }

    public func canHandleCallback(query: TelegramCallbackQuery) -> Bool {
        guard let data = query.data else { return false }
        return data.hasPrefix("fold_") || data.hasPrefix("unfold_")
    }

    public func handleCallbackQuery(query: TelegramCallbackQuery, client: TelegramClient, logger: LogService) async throws {
        guard let data = query.data else { return }

        if data.hasPrefix("fold_") {
            let cardId = String(data.dropFirst(5))
            guard let card = await cardStore.get(cardId) else {
                _ = try? await client.answerCallbackQuery(callbackQueryId: query.id, text: "卡片已过期", showAlert: false)
                return
            }

            await cardStore.setFolded(cardId, isFolded: true)
            let foldedText = buildFoldedHtml(platform: card.platform, result: card.result)
            let foldedKeyboard = buildFoldedKeyboard(cardId: cardId, result: card.result)

            if card.isPhoto {
                _ = try? await client.editMessageCaption(
                    chatId: card.chatId,
                    messageId: card.messageId,
                    caption: foldedText,
                    parseMode: "HTML",
                    replyMarkup: foldedKeyboard
                )
            } else {
                _ = try? await client.editMessageText(
                    chatId: card.chatId,
                    messageId: card.messageId,
                    text: foldedText,
                    parseMode: "HTML",
                    replyMarkup: foldedKeyboard
                )
            }

            _ = try? await client.answerCallbackQuery(
                callbackQueryId: query.id,
                text: "🛡️ 已安全折叠隐藏！随时可点击展开恢复。",
                showAlert: false
            )
            logger.info("Video", "卡片 [\(cardId)] 已安全折叠")

        } else if data.hasPrefix("unfold_") {
            let cardId = String(data.dropFirst(7))
            guard let card = await cardStore.get(cardId) else {
                _ = try? await client.answerCallbackQuery(callbackQueryId: query.id, text: "卡片已过期", showAlert: false)
                return
            }

            await cardStore.setFolded(cardId, isFolded: false)
            let unfoldedText = buildUnfoldedHtml(platform: card.platform, result: card.result)
            let unfoldedKeyboard = buildUnfoldedKeyboard(cardId: cardId, result: card.result)

            if card.isPhoto {
                _ = try? await client.editMessageCaption(
                    chatId: card.chatId,
                    messageId: card.messageId,
                    caption: unfoldedText,
                    parseMode: "HTML",
                    replyMarkup: unfoldedKeyboard
                )
            } else {
                _ = try? await client.editMessageText(
                    chatId: card.chatId,
                    messageId: card.messageId,
                    text: unfoldedText,
                    parseMode: "HTML",
                    replyMarkup: unfoldedKeyboard
                )
            }

            _ = try? await client.answerCallbackQuery(
                callbackQueryId: query.id,
                text: "👁️ 已重新展开完整卡片",
                showAlert: false
            )
            logger.info("Video", "卡片 [\(cardId)] 已重新展开")

            // 重新开启超时自动防误窥
            scheduleAutoFold(cardId: cardId, client: client, logger: logger)
        }
    }

    private func scheduleAutoFold(cardId: String, client: TelegramClient, logger: LogService) {
        let minutes = StorageService.shared.autoFoldMinutes
        guard minutes > 0 else { return }

        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            guard let self = self else { return }

            guard let card = await self.cardStore.get(cardId), !card.isFolded else {
                return
            }

            // 执行自动折叠
            await self.cardStore.setFolded(cardId, isFolded: true)
            let foldedText = self.buildFoldedHtml(platform: card.platform, result: card.result)
            let foldedKeyboard = self.buildFoldedKeyboard(cardId: cardId, result: card.result)

            if card.isPhoto {
                _ = try? await client.editMessageCaption(
                    chatId: card.chatId,
                    messageId: card.messageId,
                    caption: foldedText,
                    parseMode: "HTML",
                    replyMarkup: foldedKeyboard
                )
            } else {
                _ = try? await client.editMessageText(
                    chatId: card.chatId,
                    messageId: card.messageId,
                    text: foldedText,
                    parseMode: "HTML",
                    replyMarkup: foldedKeyboard
                )
            }
            logger.info("Video", "卡片 [\(cardId)] 超时 (\(minutes)分钟) 自动折叠完成")
        }
    }

    private func buildUnfoldedHtml(platform: VideoPlatform, result: VideoParseResult) -> String {
        let safeAuthor = escapeHtml(result.author)
        let safeTitle = escapeHtml(result.title)
        let sizeDisplay = result.fileSize ?? "未知大小"
        let summaryLabel = platform == .twitter ? "推文摘要" : "内容摘要"

        var text = """
        \(platform.badge) <b>视频解析完成</b>

        👤 <b>发布者</b>: <tg-spoiler>@\(safeAuthor)</tg-spoiler>
        📺 <b>最高画质</b>: <code>\(result.resolution)</code>
        📦 <b>预估体积</b>: <code>\(sizeDisplay)</code>
        """

        if !safeTitle.isEmpty {
            text += """


            💬 <b>\(summaryLabel)（剧透遮罩）</b>:
            <tg-spoiler>\(safeTitle)</tg-spoiler>
            """
        }

        return text
    }

    private func buildUnfoldedKeyboard(cardId: String, result: VideoParseResult) -> InlineKeyboardMarkup {
        let sizeDisplay = result.fileSize ?? "直链"
        return InlineKeyboardMarkup(inlineKeyboard: [
            [
                InlineKeyboardButton(
                    text: "🌐 浏览器直达下载 (\(result.resolution) · \(sizeDisplay))",
                    url: result.url
                )
            ],
            [
                InlineKeyboardButton(
                    text: "🔒 立即折叠隐藏（防误窥）",
                    callbackData: "fold_\(cardId)"
                )
            ]
        ])
    }

    private func buildFoldedHtml(platform: VideoPlatform, result: VideoParseResult) -> String {
        let sizeDisplay = result.fileSize ?? "未知大小"
        let summaryLabel = platform == .twitter ? "推文摘要" : "内容摘要"
        return """
        \(platform.badge) <b>视频解析（🛡️ 隐私锁定中）</b>

        📺 <b>规格</b>: <code>\(result.resolution)</code> · <code>\(sizeDisplay)</code>
        🔒 <b>\(summaryLabel)与敏感封面已安全折叠隐藏</b>
        <i>可随时点击下方按钮展开查看或直达下载</i>
        """
    }

    private func buildFoldedKeyboard(cardId: String, result: VideoParseResult) -> InlineKeyboardMarkup {
        return InlineKeyboardMarkup(inlineKeyboard: [
            [
                InlineKeyboardButton(
                    text: "👁️ 展开完整信息",
                    callbackData: "unfold_\(cardId)"
                ),
                InlineKeyboardButton(
                    text: "🌐 直达下载",
                    url: result.url
                )
            ]
        ])
    }

    private func escapeHtml(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
