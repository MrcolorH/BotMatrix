import Foundation

public final class AgyModule: BotServiceModule, ObservableObject {
    public let id = "antigravity_ai"
    public let name = "反重力 AI 角色对话"
    public let description = "白名单用户免前缀自然对话，非白名单用户无视非指令闲聊；纯净拟人回复与输入中状态。"
    public let iconName = "bubble.left.and.bubble.right.fill"

    @Published public var isEnabled: Bool = true

    public var commands: [BotCommand] {
        return [
            BotCommand(command: "start", description: "🎬 查看 TGBot 欢迎指南与主要功能"),
            BotCommand(command: "help", description: "📖 查看机器人所有服务与使用说明"),
            BotCommand(command: "ai", description: "🤖 与反重力 AI 开启智能对话与任务执行"),
            BotCommand(command: "persona", description: "🎭 查看当前生效的 AI 角色人设"),
            BotCommand(command: "status", description: "🖥️ 查看 Mac mini 宿主系统运行状态")
        ]
    }

    private let storage = StorageService.shared
    private let agyService = AgyService.shared

    public init(storage: StorageService) {
        self.isEnabled = storage.agyModuleEnabled
    }

    /// 判断是否为单条视频解析链接 (如果是单独链接，优先交由 VideoModule 处理)
    private func isSingleVideoLink(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = UniversalVideoResolver.extractUrl(from: trimmed) else { return false }
        let withoutUrl = trimmed.replacingOccurrences(of: url, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return withoutUrl.isEmpty
    }

    /// 解析斜杠命令 (/ai, /status 等)
    private func parseSlashCommand(text: String) -> (cmd: String, prompt: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }

        let pattern = #"^/([a-zA-Z0-9_]+)(?:@[a-zA-Z0-9_]+)?(?:\s+([\s\S]*))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)) else {
            return nil
        }

        let ns = trimmed as NSString
        let cmd = ns.substring(with: match.range(at: 1)).lowercased()
        var prompt = ""
        if match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound {
            prompt = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (cmd, prompt)
    }

    public func canHandle(message: TelegramMessage) -> Bool {
        guard isEnabled && storage.agyEnabledTG, let rawText = message.text else { return false }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }

        // 1. 如果是单独一条视频链接，绝不截胡，交由 VideoModule 处理
        if UniversalVideoResolver.isVideoLinkMessage(text) {
            return false
        }

        let userId = message.from?.id ?? 0
        let isAdmin = storage.isAdmin(userId: userId)

        // 2. 白名单用户：单独链接之外的任何文本，全部直接认定为 AI 对话或指令！
        if isAdmin {
            return true
        }

        // 3. 非白名单用户：必须带指令前缀 (如 /ai, /status) 才响应鉴权提示；非链接非指令的一概无视！
        return text.hasPrefix("/")
    }

    public func handleMessage(message: TelegramMessage, client: TelegramClient, logger: LogService) async throws {
        guard let rawText = message.text else { return }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatId = message.chat.id
        let userId = message.from?.id ?? 0
        let userTag = message.from?.username != nil ? "@\(message.from!.username!)" : "\(userId)"
        let isMaster = storage.isMasterAdmin(userId: userId)
        let isAdmin = storage.isAdmin(userId: userId)

        // 区分是指令还是直接自然语言对话
        if text.hasPrefix("/") {
            let parsed = parseSlashCommand(text: text)
            let cmd = parsed?.cmd ?? ""
            let prompt = parsed?.prompt ?? ""

            // 公共指令 /start 或 /help
            if cmd == "start" || cmd == "help" {
                let adminHelp = isMaster ? """

                👑 <b>系统所有者专属功能已激活 (真机宿主模式):</b>
                • 直接向我发送任何文本即可开启 AI 对话并具备真机设备读写与维护能力
                • <code>/quota</code> - 实时查询反重力 AI 5小时与周额度余额
                • <code>/persona</code> - 查看当前生效的 AI 角色卡
                • <code>/status</code> - 查看 Mac mini 宿主系统运行报告
                """ : (isAdmin ? """

                🛡️ <b>白名单授权访客 (沙箱安全模式):</b>
                • 可与 AI 自然对话，但在独立受限沙箱中运行，无权读写宿主主机文件
                • <code>/persona</code> - 查看当前生效的 AI 角色卡
                """ : """

                🔒 <i>您的 Telegram User ID: <code>\(userId)</code>（尚未授权）</i>
                """)

                let helpText = """
                🎬 <b>TGBot 视频中心 & 智能助理</b>

                <b>视频解析服务（全员可用）</b>:
                直接向我发送任何 Twitter/X、TikTok/抖音、B站、YouTube 链接，秒级提取最高画质直链并带防误窥毛玻璃！
                \(adminHelp)
                """
                _ = try? await client.sendMessage(chatId: chatId, text: helpText, parseMode: "HTML")
                return
            }

            // 非白名单用户的权限拦截
            guard isAdmin else {
                logger.warn("Agy", "非白名单用户 [\(userTag)] (ID: \(userId)) 试图调用指令: \(text.prefix(30))")
                let deniedText = """
                ⛔️ <b>权限受限（需要白名单授权）</b>

                您的 Telegram User ID: <code>\(userId)</code> 尚未加入授权名单。
                💡 <b>如何授权</b>：请在公司 Mac mini 的 TGBot 桌面端 ->「参数设置」->「管理员白名单」中添加此 ID。

                🎬 <i>视频直链解析属于公共服务，直接发送链接即可使用，无需任何权限！</i>
                """
                _ = try? await client.sendMessage(chatId: chatId, text: deniedText, parseMode: "HTML")
                return
            }

            // 专享指令：/status (仅限系统所有者)
            if cmd == "status" {
                guard isMaster else {
                    let denied = "⛔️ <b>权限受限</b>：Mac mini 宿主系统硬件与运行状态仅限系统所有者（Owner）查看。您当前处于白名单沙箱隔离模式。"
                    _ = try? await client.sendMessage(chatId: chatId, text: denied, parseMode: "HTML")
                    return
                }
                logger.info("Agy", "系统所有者 [\(userTag)] 查询 Mac mini 系统状态")
                let statusText = await agyService.getMacSystemStatus()
                _ = try? await client.sendMessage(chatId: chatId, text: statusText, parseMode: "HTML")
                return
            }

            // 专享指令：/quota, /limit, /usage, /ed, /edu (仅限系统所有者)
            if cmd == "quota" || cmd == "limit" || cmd == "usage" || cmd == "ed" || cmd == "edu" {
                guard isMaster else {
                    let denied = "⛔️ <b>权限受限</b>：反重力 AI 额度查询仅限系统所有者（Owner）查看。"
                    _ = try? await client.sendMessage(chatId: chatId, text: denied, parseMode: "HTML")
                    return
                }
                logger.info("Agy", "系统所有者 [\(userTag)] 查询反重力 AI 额度")
                let report = await agyService.getAgyQuotaReport()
                _ = try? await client.sendMessage(chatId: chatId, text: report, parseMode: "HTML")
                return
            }

            // 查看生效角色卡
            if cmd == "persona" || cmd == "role" {
                let card = storage.activePersonaCard
                let escapedName = escapeHtml(card.name)
                let escapedPrompt = escapeHtml(card.prompt)
                let text = """
                🎭 <b>当前生效的 AI 角色卡: 【\(escapedName)】</b>
                <blockquote>\(escapedPrompt)</blockquote>
                🔒 <i>提示：为保障安全性，角色卡库仅限在 Mac mini 控制台内私有添加、编辑与切换，不对外提供任何修改指令。</i>
                """
                _ = try? await client.sendMessage(chatId: chatId, text: text, parseMode: "HTML")
                return
            }

            // 如果管理员输入 /ai 或 /agy，提取其后的 prompt；如果直接输入未知指令，把整个内容作为 prompt
            let actualPrompt = prompt.isEmpty ? text : prompt
            await executeAiChat(prompt: actualPrompt, chatId: chatId, userTag: userTag, isMaster: isMaster, client: client, logger: logger)

        } else {
            // 没有斜杠前缀的普通文本：
            // canHandle 已经确保了此时 isAdmin 一定为 true！直接当作自然语言 AI 对话执行！
            await executeAiChat(prompt: text, chatId: chatId, userTag: userTag, isMaster: isMaster, client: client, logger: logger)
        }
    }

    /// 执行拟人化 AI 对话 (去掉所有机器头，纯粹返回模型回复，带有正在输入提示)
    private func executeAiChat(
        prompt: String,
        chatId: Int64,
        userTag: String,
        isMaster: Bool,
        client: TelegramClient,
        logger: LogService
    ) async {
        let roleDesc = isMaster ? "👑 系统所有者(宿主模式)" : "🛡️ 白名单访客(沙箱模式)"
        logger.info("Agy", "用户 [\(userTag)][\(roleDesc)] 发起对话: \(prompt.prefix(40))...")

        // 1. 发送拟人化输入状态 (sendChatAction)
        _ = try? await client.sendChatAction(chatId: chatId, action: "typing")

        // 2. 发送轻量占位消息
        let waitingMsg = try? await client.sendMessage(
            chatId: chatId,
            text: "💭 正在输入...",
            parseMode: nil
        )

        // 3. 开启后台定时续期输入状态 (让顶部一直显示“正在输入...”)
        let typingTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { break }
                _ = try? await client.sendChatAction(chatId: chatId, action: "typing")
            }
        }

        do {
            let output = try await agyService.executePrompt(prompt, sessionKey: "tg:\(chatId)", isMasterAdmin: isMaster)
            typingTask.cancel()

            // 4. 直接输出 AI 纯净文本，彻底去除“反重力回复”等生硬标题
            let cleanOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)

            // 如果内容过长 (超过 3900 字符)，分段发送
            if cleanOutput.count > 3900 {
                let chunks = splitIntoChunks(cleanOutput, size: 3900)
                if let firstChunk = chunks.first, let wid = waitingMsg?.messageId {
                    _ = try? await client.editMessageText(chatId: chatId, messageId: wid, text: firstChunk, parseMode: nil)
                }
                for chunk in chunks.dropFirst() {
                    _ = try? await client.sendMessage(chatId: chatId, text: chunk, parseMode: nil)
                }
            } else {
                if let wid = waitingMsg?.messageId {
                    // 原地将“💭 正在输入...”直接刷新为最终回复内容
                    _ = try? await client.editMessageText(
                        chatId: chatId,
                        messageId: wid,
                        text: cleanOutput.isEmpty ? "（已执行完毕）" : cleanOutput,
                        parseMode: nil
                    )
                } else {
                    _ = try? await client.sendMessage(chatId: chatId, text: cleanOutput, parseMode: nil)
                }
            }

            logger.success("Agy", "AI 回复成功回传给 [\(userTag)]")
        } catch {
            typingTask.cancel()

            logger.error("Agy", "AI 执行失败: \(error.localizedDescription)")
            let errText = "出错了: \(error.localizedDescription)"
            if let wid = waitingMsg?.messageId {
                _ = try? await client.editMessageText(chatId: chatId, messageId: wid, text: errText, parseMode: nil)
            } else {
                _ = try? await client.sendMessage(chatId: chatId, text: errText, parseMode: nil)
            }
        }
    }

    private func splitIntoChunks(_ string: String, size: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for line in string.components(separatedBy: .newlines) {
            if current.count + line.count + 1 > size {
                chunks.append(current)
                current = line
            } else {
                current += (current.isEmpty ? "" : "\n") + line
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    public func canHandleCallback(query: TelegramCallbackQuery) -> Bool {
        return false
    }

    public func handleCallbackQuery(query: TelegramCallbackQuery, client: TelegramClient, logger: LogService) async throws {}

    private func escapeHtml(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
