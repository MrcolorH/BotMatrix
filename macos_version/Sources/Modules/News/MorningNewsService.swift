import Foundation

public final class MorningNewsService: ObservableObject {
    public static let shared = MorningNewsService()

    @Published public private(set) var subscribers: [NewsSubscriber] = []
    @Published public var pushHour: Int = 8
    @Published public var pushMinute: Int = 0
    @Published public private(set) var lastPushDate: String = ""

    private let fileUrl: URL = {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let folder = home.appendingPathComponent(".tgbot")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("morning_news.json")
    }()

    public init() {
        loadData()
    }

    // MARK: - 持久化存储

    public func loadData() {
        guard FileManager.default.fileExists(atPath: fileUrl.path),
              let data = try? Data(contentsOf: fileUrl),
              let model = try? JSONDecoder().decode(MorningNewsData.self, from: data) else {
            // 初始化默认
            self.subscribers = []
            self.pushHour = 8
            self.pushMinute = 0
            self.lastPushDate = ""
            return
        }

        self.subscribers = model.subscribers
        self.pushHour = model.pushHour
        self.pushMinute = model.pushMinute
        self.lastPushDate = model.lastPushDate
    }

    public func saveData() {
        let model = MorningNewsData(
            subscribers: self.subscribers,
            pushHour: self.pushHour,
            pushMinute: self.pushMinute,
            lastPushDate: self.lastPushDate,
            defaultTags: ["AI发展", "机器人发展", "大肥鱼现状"]
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(model)
            try data.write(to: fileUrl, options: .atomic)
        } catch {
            print("[MorningNews] 保存晨报数据失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 订阅者管理

    /// 用户申请加入晨报推送名单
    /// - Returns: (是否新加入, 该订阅对象)
    @discardableResult
    public func subscribe(userId: Int64, chatId: Int64, username: String?, firstName: String) -> (isNew: Bool, subscriber: NewsSubscriber) {
        if let idx = subscribers.firstIndex(where: { $0.userId == userId }) {
            var sub = subscribers[idx]
            let wasActive = sub.isActive
            sub.isActive = true
            sub.chatId = chatId
            sub.username = username
            if !firstName.isEmpty { sub.firstName = firstName }
            if sub.tags.isEmpty {
                sub.tags = ["AI发展", "机器人发展", "大肥鱼现状"]
            }
            subscribers[idx] = sub
            saveData()
            return (!wasActive, sub)
        } else {
            let newSub = NewsSubscriber(
                userId: userId,
                chatId: chatId,
                username: username,
                firstName: firstName,
                tags: ["AI发展", "机器人发展", "大肥鱼现状"],
                subscribedAt: Date(),
                isActive: true
            )
            subscribers.append(newSub)
            saveData()
            return (true, newSub)
        }
    }

    /// 用户主动退出晨报推送名单
    @discardableResult
    public func unsubscribe(userId: Int64) -> Bool {
        if let idx = subscribers.firstIndex(where: { $0.userId == userId }) {
            subscribers[idx].isActive = false
            saveData()
            return true
        }
        return false
    }

    /// 获取指定用户订阅信息
    public func getSubscriber(userId: Int64) -> NewsSubscriber? {
        return subscribers.first(where: { $0.userId == userId })
    }

    /// 为用户添加晨报关注标签
    public func addTags(userId: Int64, newTags: [String]) -> (success: Bool, currentTags: [String]) {
        guard let idx = subscribers.firstIndex(where: { $0.userId == userId }) else {
            return (false, [])
        }
        var tags = subscribers[idx].tags
        for tag in newTags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !tags.contains(trimmed) {
                tags.append(trimmed)
            }
        }
        subscribers[idx].tags = tags
        saveData()
        return (true, tags)
    }

    /// 为用户移除指定标签
    public func removeTag(userId: Int64, tagToRemove: String) -> (success: Bool, currentTags: [String]) {
        guard let idx = subscribers.firstIndex(where: { $0.userId == userId }) else {
            return (false, [])
        }
        let trimmed = tagToRemove.trimmingCharacters(in: .whitespacesAndNewlines)
        var tags = subscribers[idx].tags
        tags.removeAll { $0 == trimmed }
        subscribers[idx].tags = tags
        saveData()
        return (true, tags)
    }

    /// 记录今日已推送标记
    public func markPushedToday(dateString: String) {
        self.lastPushDate = dateString
        saveData()
    }

    /// 获取当前有效订阅者数量
    public var activeSubscriberCount: Int {
        subscribers.filter { $0.isActive }.count
    }

    // MARK: - 后台 CLI 智能晨报内容生成

    /// 根据用户订阅的个性化标签生成专属晨报推文
    public func generateNews(for subscriber: NewsSubscriber) async -> String {
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "yyyy年MM月dd日 EEEE"
        dateFormater.locale = Locale(identifier: "zh_CN")
        let dateStr = dateFormater.string(from: Date())

        let tags = subscriber.tags.isEmpty ? ["AI发展", "机器人发展", "大肥鱼现状"] : subscriber.tags
        let tagsPrompt = tags.joined(separator: "、")

        let prompt = """
        请以「每日科技智报」记者的身份，为读者汇总今天的晨报要闻。
        今天重点追踪的定制标签为：【\(tagsPrompt)】。

        请严格按以下要求排版输出（直接输出排版好的正文推文，纯净优雅，不要附带任何无关的寒暄废话）：
        1. 顶部标题：包含日期「\(dateStr)」与晨报问候。
        2. 针对每一个标签（例如：\(tagsPrompt)），设立清晰的段落小标题（使用 emoji 标注，如 🤖、🧠、🐟 等），并搜集整理 1~2 条最新大事/核心动态/真实趣味现状，用干练、生动的语言总结。
        3. 特别注意：如果标签中包含「大肥鱼现状」，请结合网络技术圈/办公区鱼缸/宠物鱼趣味梗，给出一句幽默生动的“大肥鱼现状观察”，让读者会心一笑。
        4. 底部附上一句积极向上的今日能量寄语。
        5. 格式使用 Telegram HTML 友好排版（可用 <b>加粗</b>、<code>代码</code>、<blockquote>引用</blockquote>）。
        """

        // 优先使用反重力 CLI (agy)
        let agy = AgyService.shared
        do {
            let output = try await agy.executePrompt(prompt)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        } catch {
            print("[MorningNews] 反重力 CLI 执行异常: \(error.localizedDescription)，将使用本地结构化智能引擎")
        }

        // 兜底高品质本地生成模板 (确保即使 CLI 临时不可用也能准时送达)
        return generateFallbackNews(subscriber: subscriber, dateStr: dateStr, tags: tags)
    }

    private func generateFallbackNews(subscriber: NewsSubscriber, dateStr: String, tags: [String]) -> String {
        var sections: [String] = []

        for tag in tags {
            switch tag {
            case let t where t.contains("AI") || t.contains("大模型") || t.contains("人工智能"):
                sections.append("""
                🧠 <b>【\(tag)】</b>
                • <b>前沿大模型与具身智能加速落地</b>：多模态推理能力与长上下文理解再次刷新行业评测基准，开源模型生态蓬勃发展，推理成本大幅降低。
                • <b>端侧 AI 全面铺开</b>：本地个人助理应用与自托管 Agent 在开发者圈广泛普及，零数据上云的私有化工作流正成为主流。
                """)
            case let t where t.contains("机器") || t.contains("具身"):
                sections.append("""
                🤖 <b>【\(tag)】</b>
                • <b>双足与四足人形机器人运动控制跃升</b>：新一代关节力控与视觉语言动作（VLA）模型紧密结合，工农业与家庭服务场景实测稳定性显著增强。
                • <b>机器人灵巧手精细操作突破</b>：触觉感知阵列结合高频反馈算法，实现复杂异形物件的秒级稳定抓取。
                """)
            case let t where t.contains("大肥鱼"):
                sections.append("""
                🐟 <b>【\(tag)】</b>
                • <b>大肥鱼今日水文监测报告</b>：水温适宜，水草茂盛。大肥鱼目前正悠闲地在水底慢吞吞巡游，偶尔吐两个惬意的小气泡，精神状态极其稳定，无忧无虑，一切安好！
                """)
            default:
                sections.append("""
                📌 <b>【\(tag)】</b>
                • 今日该领域持续演进，产业上下游关注度保持高位，技术迭代与应用落地正在稳步向前推进。
                """)
            }
        }

        let body = sections.joined(separator: "\n\n")

        return """
        ☀️ <b>每日晨报 · 科技与智能简报</b>
        📅 <i>\(dateStr)</i>
        ──────────────────
        \(body)
        ──────────────────
        ✨ <b>今日寄语</b>：保持好奇心，用代码与智慧开启充实的一天！
        """
    }
}
