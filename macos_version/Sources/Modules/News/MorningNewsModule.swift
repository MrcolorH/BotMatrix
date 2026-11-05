import Foundation

public final class MorningNewsModule: BotServiceModule, ObservableObject {
    public let id = "morning_news"
    public let name = "每日晨报中心"
    public let description = "专为指定订阅用户推送的晨报服务。支持用户自由定制标签、后台 CLI 每天 08:00 智能汇总推送。"
    public let iconName = "sun.max.fill"

    @Published public var isEnabled: Bool = true

    public var commands: [BotCommand] {
        return [
            BotCommand(command: "getnews", description: "☀️ 申请加入每日晨报推送名单 (早晨 08:00 准时推送)"),
            BotCommand(command: "addtag", description: "🏷️ 添加晨报定制关注标签 (如: /addTag AI发展)"),
            BotCommand(command: "removetag", description: "🗑️ 移除指定的晨报标签"),
            BotCommand(command: "mytags", description: "📋 查看我的当前关注标签与推送配置"),
            BotCommand(command: "previewnews", description: "🔍 立即试读今日专属定制晨报"),
            BotCommand(command: "stopnews", description: "👋 退出每日晨报推送名单")
        ]
    }

    private let service = MorningNewsService.shared
    private let scheduler = MorningNewsScheduler.shared

    public init() {}

    private let supportedCommands: Set<String> = [
        "getnews", "stopnews", "cancelnews", "quitnews",
        "addtag", "removetag", "deltag", "mytags", "tags",
        "testnews", "previewnews"
    ]

    private func extractCommand(from text: String) -> (cmd: String, args: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }

        let pattern = #"^/([a-zA-Z0-9_]+)(?:@[a-zA-Z0-9_]+)?(?:\s+([\s\S]*))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)) else {
            return nil
        }

        let ns = trimmed as NSString
        let cmd = ns.substring(with: match.range(at: 1)).lowercased()
        var args = ""
        if match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound {
            args = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (cmd, args)
    }

    public func canHandle(message: TelegramMessage) -> Bool {
        guard isEnabled, let rawText = message.text else { return false }
        guard let (cmd, _) = extractCommand(from: rawText) else { return false }
        return supportedCommands.contains(cmd)
    }

    public func handleMessage(message: TelegramMessage, client: TelegramClient, logger: LogService) async throws {
        guard let rawText = message.text,
              let (cmd, args) = extractCommand(from: rawText) else { return }

        let chatId = message.chat.id
        let userId = message.from?.id ?? chatId
        let username = message.from?.username
        let firstName = message.from?.firstName ?? "朋友"
        let userTag = username != nil ? "@\(username!)" : "\(userId)"

        switch cmd {
        case "getnews":
            let (isNew, sub) = service.subscribe(
                userId: userId,
                chatId: chatId,
                username: username,
                firstName: firstName
            )

            logger.info("News", "用户 [\(userTag)] 申请加入晨报名单 (\(isNew ? "新用户" : "恢复订阅"))")

            let tagsList = sub.tags.map { "• <b>\($0)</b>" }.joined(separator: "\n")
            let welcome = """
            ☀️ <b>您已成功加入【每日晨报】推送名单！</b>

            ⏰ <b>推送时间</b>：每天早晨 <b>\(String(format: "%02d:%02d", service.pushHour, service.pushMinute))</b> 准时送达。
            📌 <b>当前默认关注标签:</b>
            \(tagsList)

            ──────────────────
            🏷️ <b>晨报标签使用指南（定制您感兴趣的动态）:</b>

            后台 CLI 每天将自动针对您的专属标签搜集最新大事、深度动态并智能排版发送给您。您可以自由增删标签：

            1️⃣ <b>添加关注标签</b>：
            <code>/addTag AI发展</code>
            <code>/addTag 机器人发展, 大肥鱼现状, 量子计算</code>
            <i>（支持用逗号或空格一次添加多个标签）</i>

            2️⃣ <b>删除不需要的标签</b>：
            <code>/removeTag 大肥鱼现状</code>

            3️⃣ <b>查看我的当前标签</b>：
            <code>/myTags</code>

            4️⃣ <b>立即体验预览</b>：
            <code>/previewNews</code>（立刻让后台 CLI 为您生成一份今日专属试读晨报）

            5️⃣ <b>随时退出推送名单</b>：
            <code>/stopNews</code>
            ──────────────────
            祝您拥有美好的一天！✨
            """
            _ = try await client.sendMessage(chatId: chatId, text: welcome, parseMode: "HTML")

        case "stopnews", "cancelnews", "quitnews":
            let success = service.unsubscribe(userId: userId)
            logger.info("News", "用户 [\(userTag)] 退出每日晨报推送名单")

            let reply = success ? """
            👋 <b>已成功退出每日晨报推送名单</b>

            您将不再接收早晨 08:00 的定时晨报推送。
            💡 <i>若未来想重新开启，只需随时向我发送 <code>/getNews</code> 即可秒级重新加入！</i>
            """ : """
            ℹ️ 您当前未在晨报推送名单中。如需订阅请发送 <code>/getNews</code>。
            """
            _ = try await client.sendMessage(chatId: chatId, text: reply, parseMode: "HTML")

        case "addtag":
            if args.isEmpty {
                let hint = """
                ⚠️ <b>请指定要添加的晨报标签名称</b>
                例如：
                <code>/addTag 自动驾驶</code>
                <code>/addTag 具身智能, 大肥鱼现状, 脑机接口</code>
                """
                _ = try await client.sendMessage(chatId: chatId, text: hint, parseMode: "HTML")
                return
            }

            // 分割标签（逗号或空格）
            let rawList = args.components(separatedBy: CharacterSet(charactersIn: ",， "))
            let newTags = rawList.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

            // 如果该用户未订阅，先自动为其建立订阅
            _ = service.subscribe(userId: userId, chatId: chatId, username: username, firstName: firstName)
            let (_, currentTags) = service.addTags(userId: userId, newTags: newTags)

            let tagsList = currentTags.map { "• <b>\($0)</b>" }.joined(separator: "\n")
            let reply = """
            ✅ <b>标签添加成功！</b>

            已新增: <code>\(newTags.joined(separator: ", "))</code>

            📌 <b>当前生效的晨报关注标签 (\(currentTags.count)个):</b>
            \(tagsList)

            💡 <i>每天早晨 08:00 后台 CLI 将为您精准搜集这些领域的最新动态！</i>
            """
            _ = try await client.sendMessage(chatId: chatId, text: reply, parseMode: "HTML")

        case "removetag", "deltag":
            if args.isEmpty {
                let hint = """
                ⚠️ <b>请指定要移除的标签名称</b>
                例如：<code>/removeTag 大肥鱼现状</code>
                输入 <code>/myTags</code> 可查看当前已有标签。
                """
                _ = try await client.sendMessage(chatId: chatId, text: hint, parseMode: "HTML")
                return
            }

            let (_, currentTags) = service.removeTag(userId: userId, tagToRemove: args)
            let tagsList = currentTags.isEmpty ? "<i>（暂无标签，建议添加）</i>" : currentTags.map { "• <b>\($0)</b>" }.joined(separator: "\n")
            let reply = """
            🗑️ <b>已移除标签:</b> <code>\(args)</code>

            📌 <b>剩余有效关注标签 (\(currentTags.count)个):</b>
            \(tagsList)
            """
            _ = try await client.sendMessage(chatId: chatId, text: reply, parseMode: "HTML")

        case "mytags", "tags":
            guard let sub = service.getSubscriber(userId: userId), sub.isActive else {
                let notSubscribed = """
                ℹ️ <b>您尚未订阅每日晨报</b>

                发送 <code>/getNews</code> 即可立即加入名单，并自定义您的专属关注标签！
                """
                _ = try await client.sendMessage(chatId: chatId, text: notSubscribed, parseMode: "HTML")
                return
            }

            let tagsList = sub.tags.isEmpty ? "<i>（暂无标签，请使用 /addTag 添加）</i>" : sub.tags.map { "• <b>\($0)</b>" }.joined(separator: "\n")
            let reply = """
            📋 <b>您的每日晨报订阅信息:</b>

            • 状态: 🟢 正常接收中
            • 推送时间: 每天早晨 <b>\(String(format: "%02d:%02d", service.pushHour, service.pushMinute))</b>
            • 接收账号: <code>\(sub.displayName)</code>

            🏷️ <b>您已定制的关注标签 (\(sub.tags.count)个):</b>
            \(tagsList)

            ──────────────────
            • <code>/addTag &lt;标签&gt;</code> - 继续添加新标签
            • <code>/removeTag &lt;标签&gt;</code> - 移除已有标签
            • <code>/previewNews</code> - 立即试读今日晨报
            • <code>/stopNews</code> - 退出晨报推送名单
            """
            _ = try await client.sendMessage(chatId: chatId, text: reply, parseMode: "HTML")

        case "testnews", "previewnews":
            logger.info("News", "用户 [\(userTag)] 请求即时试读预览晨报")
            _ = try? await client.sendChatAction(chatId: chatId, action: "typing")

            let sub = service.getSubscriber(userId: userId) ?? NewsSubscriber(
                userId: userId,
                chatId: chatId,
                username: username,
                firstName: firstName,
                tags: ["AI发展", "机器人发展", "大肥鱼现状"]
            )

            let tip = try? await client.sendMessage(
                chatId: chatId,
                text: "🔍 后台 CLI 正在为您检索并汇总【\(sub.tags.joined(separator: "、"))】最新要闻，请稍候...",
                parseMode: nil
            )

            let news = await service.generateNews(for: sub)
            if let tipId = tip?.messageId {
                _ = try? await client.editMessageText(chatId: chatId, messageId: tipId, text: news, parseMode: "HTML")
            } else {
                _ = try? await client.sendMessage(chatId: chatId, text: news, parseMode: "HTML")
            }

        default:
            break
        }
    }

    public func canHandleCallback(query: TelegramCallbackQuery) -> Bool {
        return false
    }

    public func handleCallbackQuery(query: TelegramCallbackQuery, client: TelegramClient, logger: LogService) async throws {}
}
