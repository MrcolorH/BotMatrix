import Foundation
import Combine

@MainActor
public final class BotController: ObservableObject {
    public static let shared = BotController()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isBusy: Bool = false
    @Published public private(set) var botUser: TelegramUser? = nil
    @Published public private(set) var lastError: String? = nil
    @Published public private(set) var totalProcessed: Int = 0
    @Published public private(set) var uptimeString: String = "00:00:00"

    private let storage = StorageService.shared
    private let registry = ServiceRegistry.shared
    private let logger = LogService.shared

    private var pollingTask: Task<Void, Never>?
    private var uptimeTimer: Timer?
    private var startedAt: Date?
    private var client: TelegramClient?

    public init() {}

    /// 测试指定 Token 是否有效
    public func testToken(_ token: String) async throws -> TelegramUser {
        let testClient = TelegramClient(token: token)
        return try await testClient.getMe()
    }

    /// 启动机器人长轮询
    public func start() {
        guard !isRunning, !isBusy else { return }

        let token = storage.botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.isEmpty {
            lastError = "请先在设置中填写 Telegram Bot Token"
            logger.error("Bot", "启动失败：未配置 Bot Token")
            return
        }

        isBusy = true
        lastError = nil

        Task {
            do {
                logger.info("Bot", "正在连接 Telegram API 验证 Token...")
                let newClient = TelegramClient(token: token)
                let user = try await newClient.getMe()

                self.client = newClient
                self.botUser = user
                self.isRunning = true
                self.isBusy = false
                self.startedAt = Date()

                logger.success("Bot", "认证成功！机器人: \(user.displayName)")

                // 清除可能存在的旧 Webhook，确保 getUpdates 长轮询可用
                try? await newClient.deleteWebhook(dropPendingUpdates: false)

                // 启动在线时长计时器
                self.startUptimeTimer()

                // 启动每日晨报定时调度器
                MorningNewsScheduler.shared.start { [weak self] in self?.client }

                // 启动后台长轮询任务
                self.startPollingLoop(client: newClient)

                // 自动同步当前所有激活模块的指令菜单到 Telegram 客户端
                await self.syncCommandsToTelegram(client: newClient)

                logger.info("Bot", "🤖 机器人已就绪并进入监听状态，当前已激活 \(registry.enabledCount) 个功能模块")
            } catch {
                self.isRunning = false
                self.isBusy = false
                self.lastError = error.localizedDescription
                self.logger.error("Bot", "启动服务失败: \(error.localizedDescription)")
            }
        }
    }

    /// 停止机器人
    public func stop() {
        guard isRunning || isBusy else { return }
        isBusy = true
        logger.info("Bot", "正在停止机器人服务...")

        pollingTask?.cancel()
        pollingTask = nil

        uptimeTimer?.invalidate()
        uptimeTimer = nil
        uptimeString = "00:00:00"
        startedAt = nil

        MorningNewsScheduler.shared.stop()

        isRunning = false
        isBusy = false
        logger.info("Bot", "服务已停止")
    }

    /// 切换运行状态
    public func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    /// 手动向所有订阅者广播测试晨报
    public func broadcastMorningNewsManually() async {
        guard let client = client, isRunning else {
            logger.warn("News", "无法执行测试晨报推送：机器人未运行")
            return
        }
        await MorningNewsScheduler.shared.broadcastMorningNews(client: client)
    }

    /// 向指定订阅者发送测试晨报
    public func sendTestMorningNews(to subscriber: NewsSubscriber) async throws {
        guard let client = client, isRunning else {
            throw NSError(domain: "BotController", code: 400, userInfo: [NSLocalizedDescriptionKey: "机器人当前未运行，请先启动服务"])
        }
        try await MorningNewsScheduler.shared.pushSingleTest(subscriber: subscriber, client: client)
    }

    /// 自动将当前所有激活模块的指令注册同步至 Telegram (让用户在输入框打 / 弹出指令提示)
    public func syncCommandsToTelegram(client: TelegramClient? = nil) async {
        guard let activeClient = client ?? self.client else {
            logger.warn("Bot", "无法同步指令：机器人未连接")
            return
        }

        var allCommands: [BotCommand] = []
        var seenCommands = Set<String>()

        // 收集所有激活的核心原生模块指令
        for module in registry.modules where module.isEnabled {
            for cmd in module.commands {
                if !seenCommands.contains(cmd.command) {
                    seenCommands.insert(cmd.command)
                    allCommands.append(cmd)
                }
            }
        }

        // 收集所有激活的动态扩展插件指令
        for plugin in registry.pluginManager.dynamicPlugins where plugin.isEnabled {
            for cmd in plugin.commands {
                if !seenCommands.contains(cmd.command) {
                    seenCommands.insert(cmd.command)
                    allCommands.append(cmd)
                }
            }
        }

        guard !allCommands.isEmpty else { return }

        do {
            try await activeClient.setMyCommands(commands: allCommands)
            logger.success("Bot", "✅ 已成功向 Telegram 注册 \(allCommands.count) 个指令！用户在聊天框输入 / 即可看到指令气泡。")
        } catch {
            logger.warn("Bot", "向 Telegram 注册指令菜单失败: \(error.localizedDescription)")
        }
    }

    private func startUptimeTimer() {
        uptimeTimer?.invalidate()
        let start = startedAt ?? Date()
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let interval = Int(Date().timeIntervalSince(start))
            let hours = interval / 3600
            let minutes = (interval % 3600) / 60
            let seconds = interval % 60
            let formatted = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            DispatchQueue.main.async {
                self?.uptimeString = formatted
            }
        }
    }

    private func startPollingLoop(client: TelegramClient) {
        pollingTask?.cancel()

        pollingTask = Task.detached(priority: .userInitiated) { [weak self] in
            var offset = 0
            var hasPollingError = false
            var consecutiveErrorCount = 0

            while !Task.isCancelled {
                guard let self = self else { break }

                let currentlyRunning = await self.isRunning
                if !currentlyRunning { break }

                do {
                    let updates = try await client.getUpdates(offset: offset, timeout: 20)

                    // 如果此前出现过轮询报错或网络波动，本次恢复正常后打印一条成功日志
                    if hasPollingError {
                        hasPollingError = false
                        consecutiveErrorCount = 0
                        let log = await self.logger
                        log.success("Bot", "✅ 网络连接与消息轮询已恢复正常，正在持续监听中...")
                    }

                    for update in updates {
                        if Task.isCancelled { break }
                        offset = update.updateId + 1

                        await MainActor.run {
                            self.totalProcessed += 1
                        }

                        if let message = update.message {
                            let reg = await self.registry
                            let log = await self.logger
                            Task {
                                await reg.dispatchMessage(message: message, client: client, logger: log)
                            }
                        } else if let callback = update.callbackQuery {
                            let reg = await self.registry
                            let log = await self.logger
                            Task {
                                await reg.dispatchCallbackQuery(query: callback, client: client, logger: log)
                            }
                        }
                    }
                } catch let tgError as TelegramError {
                    if Task.isCancelled { break }
                    hasPollingError = true
                    consecutiveErrorCount += 1
                    let log = await self.logger
                    // 避免连续波动每 2 秒大量重复打印：首次立即打印，若持续出错则每 10 次（约 20-30 秒）打印一次
                    let shouldLog = (consecutiveErrorCount == 1) || (consecutiveErrorCount % 10 == 0)

                    switch tgError {
                    case .apiError(let code, let desc):
                        if code == 409 {
                            if shouldLog {
                                log.warn(
                                    "Bot",
                                    "⚠️ 409 冲突：检测到此 Token 正在其他设备或后台进程中运行。同一时刻只能有一个实例轮询！[5秒后重试\(consecutiveErrorCount > 1 ? "，连续第\(consecutiveErrorCount)次" : "")]"
                                )
                            }
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                        } else {
                            if shouldLog {
                                log.warn("Bot", "Telegram API 响应异常 (\(code): \(desc)) [3秒后重试\(consecutiveErrorCount > 1 ? "，连续第\(consecutiveErrorCount)次" : "")]")
                            }
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                        }
                    default:
                        if shouldLog {
                            log.warn("Bot", "网络轮询波动: \(tgError.localizedDescription) [2秒后重试\(consecutiveErrorCount > 1 ? "，连续第\(consecutiveErrorCount)次" : "")]")
                        }
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                } catch {
                    if Task.isCancelled { break }
                    hasPollingError = true
                    consecutiveErrorCount += 1
                    let shouldLog = (consecutiveErrorCount == 1) || (consecutiveErrorCount % 10 == 0)

                    if shouldLog {
                        let log = await self.logger
                        log.warn("Bot", "轮询发生错误: \(error.localizedDescription) [2秒后重试\(consecutiveErrorCount > 1 ? "，连续第\(consecutiveErrorCount)次" : "")]")
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
    }

    /// 向 Telegram 系统所有者派发广播通知
    public func sendNotificationToMasterAdmins(text: String) async {
        guard let client = client, isRunning else { return }
        for adminId in storage.masterAdminList {
            _ = try? await client.sendMessage(chatId: adminId, text: text)
        }
    }
}
