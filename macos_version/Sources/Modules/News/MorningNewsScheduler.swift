import Foundation

public final class MorningNewsScheduler {
    public static let shared = MorningNewsScheduler()

    private var timer: Timer?
    private let service = MorningNewsService.shared
    private let logger = LogService.shared
    private var isPushing: Bool = false

    public init() {}

    /// 启动定时调度器 (后台每 30 秒轮询检查一次时间)
    public func start(clientProvider: @escaping () -> TelegramClient?) {
        stop()

        logger.info("News", "每日晨报调度器已启动，目标推送时间: 每天 \(String(format: "%02d:%02d", service.pushHour, service.pushMinute))")

        // 启动主定时器
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                guard let client = clientProvider() else { return }
                self.checkAndExecutePushIfNeeded(client: client)
            }
        }
    }

    /// 停止定时器
    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 检查并执行每日推送
    private func checkAndExecutePushIfNeeded(client: TelegramClient) {
        guard !isPushing else { return }

        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: now)

        // 判断是否到达推送时分，且今天尚未推送
        if hour == service.pushHour && minute == service.pushMinute && service.lastPushDate != todayStr {
            isPushing = true
            service.markPushedToday(dateString: todayStr)

            logger.info("News", "⏰ 达到早晨 \(String(format: "%02d:%02d", service.pushHour, service.pushMinute)) 定时点，开始向订阅用户广播晨报...")

            Task {
                await self.broadcastMorningNews(client: client)
                self.isPushing = false
            }
        }
    }

    /// 向所有订阅用户推送晨报
    public func broadcastMorningNews(client: TelegramClient) async {
        let activeUsers = service.subscribers.filter { $0.isActive }
        guard !activeUsers.isEmpty else {
            logger.info("News", "当前暂无有效订阅用户，跳过本次晨报推送。")
            return
        }

        logger.info("News", "准备向 \(activeUsers.count) 位用户推送今日晨报...")

        var successCount = 0
        var failCount = 0

        for subscriber in activeUsers {
            let news = await service.generateNews(for: subscriber)
            do {
                _ = try await client.sendMessage(
                    chatId: subscriber.chatId,
                    text: news,
                    parseMode: "HTML"
                )
                successCount += 1
                logger.success("News", "晨报成功推送给 [\(subscriber.displayName)] (标签: \(subscriber.tags.joined(separator: ", ")))")
                // 防刷保护间隔
                try? await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                failCount += 1
                logger.error("News", "向 [\(subscriber.displayName)] 推送晨报失败: \(error.localizedDescription)")
            }
        }

        logger.info("News", "今日晨报推送完毕：成功 \(successCount) 位，失败 \(failCount) 位。")
    }

    /// 单独向指定订阅者发送测试晨报
    public func pushSingleTest(subscriber: NewsSubscriber, client: TelegramClient) async throws {
        logger.info("News", "正在为 [\(subscriber.displayName)] 即时生成测试晨报...")
        let news = await service.generateNews(for: subscriber)
        _ = try await client.sendMessage(
            chatId: subscriber.chatId,
            text: news,
            parseMode: "HTML"
        )
        logger.success("News", "测试晨报已发送至 [\(subscriber.displayName)]")
    }
}
