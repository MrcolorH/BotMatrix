import Foundation
import Combine
import AppKit
import Network

public struct QQPermissionRequest: Codable, Identifiable, Equatable {
    public var id: Int64 { userId }
    public var userId: Int64
    public var senderName: String
    public var requestedAt: Date
    public var note: String

    public init(userId: Int64, senderName: String, requestedAt: Date = Date(), note: String = "") {
        self.userId = userId
        self.senderName = senderName
        self.requestedAt = requestedAt
        self.note = note
    }
}

@MainActor
public final class QQController: ObservableObject {
    public static let shared = QQController()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isStarting: Bool = false
    @Published public private(set) var isStopping: Bool = false
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var botUin: Int64 = 0
    @Published public private(set) var botNickname: String = ""
    @Published public private(set) var lastError: String? = nil
    @Published public private(set) var totalProcessed: Int = 0
    @Published public private(set) var uptimeString: String = "00:00:00"

    // 守护进程控制
    @Published public private(set) var isDaemonRunning: Bool = false
    @Published public private(set) var daemonPid: Int32? = nil
    private var daemonProcess: Process?
    private var daemonPipe: Pipe?

    // NapCat 状态与快速登录管理
    @Published public var showNapCatInstallSheet: Bool = false
    @Published public private(set) var quickLoginList: [String] = []
    @Published public private(set) var currentLoginPhase: String = ""
    @Published public private(set) var qrCodeUrl: String = ""
    @Published public private(set) var isQrCodeAccepted: Bool = false

    // 📋 好友权限申请列表 (待真实管理员审批)
    @Published public private(set) var pendingRequests: [QQPermissionRequest] = []

    private let storage = StorageService.shared
    private let logger = LogService.shared
    private let agyService = AgyService.shared
    private let qqClient = OneBotQQClient.shared
    private let napCat = NapCatService.shared

    private var uptimeTimer: Timer?
    private var startedAt: Date?
    private var monitorTask: Task<Void, Never>?

    private var pendingRequestsUrl: URL {
        let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".tgbot", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("pending_qq_requests.json")
    }

    public init() {
        loadPendingRequests()
    }

    public var displayName: String {
        if !botNickname.isEmpty {
            return "\(botNickname) (\(botUin))"
        }
        if botUin > 0 {
            return "QQ 小号 (\(botUin))"
        }
        return "本地 QQ 小号网关"
    }

    public var statusDescription: String {
        if isStopping { return "正在关停..." }
        if !isRunning { return "已停止" }
        if isConnected { return "已连通" }
        if isStarting { return "正在唤起..." }
        if currentLoginPhase == "waiting_qrcode" { return "待登录 (点击登录管理)" }
        return "正在连线..."
    }

    /// 切换启动 / 停止状态
    public func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    /// 一键启动 QQ 监听与后台守护进程 (非阻塞式设计)
    public func start() {
        guard !isRunning else { return }

        let wsString = storage.qqWsUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: wsString), !wsString.isEmpty else {
            lastError = "无效的 QQ OneBot WebSocket 地址"
            logger.error("QQ", "启动失败: WebSocket 地址格式错误")
            return
        }

        lastError = nil
        isRunning = true
        isStarting = true
        startedAt = Date()
        startUptimeTimer()

        logger.info("QQ", "正在启动 QQ 小号服务...")

        monitorTask?.cancel()
        monitorTask = Task {
            if storage.qqManageDaemon {
                await launchDaemonProcess()
            }
            // 守护进程拉起完成（或已在运行），立即释放 isStarting 状态，让用户随时可按停止
            self.isStarting = false

            // 后台异步监管连线与登录状态，绝不阻塞 UI
            await monitorAndConnect(targetUrl: url)
        }
    }

    /// 停止 QQ 监听与后台守护进程
    public func stop() {
        guard !isStopping else { return }
        isStopping = true
        monitorTask?.cancel()
        monitorTask = nil

        logger.info("QQ", "正在断开 QQ 小号网关并彻底停止守护进程...")

        // 停止计时
        uptimeTimer?.invalidate()
        uptimeTimer = nil
        uptimeString = "00:00:00"
        startedAt = nil

        // 断开 WebSocket
        qqClient.disconnect()

        Task {
            // 杀死后台 QQ 进程树
            await stopDaemonProcess()

            await MainActor.run {
                self.isRunning = false
                self.isConnected = false
                self.isStarting = false
                self.isStopping = false
                self.isDaemonRunning = false
                self.botUin = 0
                self.botNickname = ""
                self.currentLoginPhase = ""
                self.qrCodeUrl = ""
                logger.success("QQ", "已彻底停止本地 QQ 服务并释放系统端口与资源")
            }
        }
    }

    /// 拉起后台 QQ 进程
    private func launchDaemonProcess() async {
        let qqPath = "/Applications/QQ.app/Contents/MacOS/QQ"
        guard FileManager.default.fileExists(atPath: qqPath) || FileManager.default.fileExists(atPath: "/Applications/QQ.app") else {
            logger.warn("QQ", "未检测到 /Applications/QQ.app，无法自动拉起后台守护。请先安装官方 Mac QQ 并用 NapCat 安装器切换入口。")
            self.lastError = "未检测到 /Applications/QQ.app，请先安装官方 Mac QQ"
            self.isRunning = false
            return
        }

        // 检查系统当前是否已有 QQ 在跑，若已有直接复用，绝不滥杀重启
        if isSystemQQRunning() {
            logger.info("QQ", "本地 QQ 守护服务进程已在运行，直接接管...")
            self.isDaemonRunning = true
            return
        }

        logger.info("QQ", "🚀 正在为您在后台拉起本地 QQ 守护端...")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: qqPath)
        proc.arguments = ["--no-sandbox"]

        // 注入 NapCat 环境变量支持一键静默快速登录
        var env = ProcessInfo.processInfo.environment
        let autoAccount = storage.qqAccount.trimmingCharacters(in: .whitespacesAndNewlines)
        if !autoAccount.isEmpty && storage.qqAutoQuickLogin {
            env["NAPCAT_QUICK_ACCOUNT"] = autoAccount
        }
        let autoPwd = storage.qqPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !autoPwd.isEmpty {
            env["NAPCAT_QUICK_PASSWORD"] = autoPwd
        }
        proc.environment = env

        // 管道异步读取并接管全部控制台日志，遇到 EOF 自动注销防死循环
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        self.daemonPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    if trimmed.contains("frameworks path is not exists") || trimmed.contains("not mini app") {
                        continue
                    }
                    DispatchQueue.main.async {
                        LogService.shared.info("QQ-Core", trimmed)
                    }
                }
            }
        }

        do {
            try proc.run()
            self.daemonProcess = proc
            self.daemonPid = proc.processIdentifier
            self.isDaemonRunning = true
            logger.success("QQ", "已拉起本地 QQ 守护端进程 (PID: \(proc.processIdentifier))")
        } catch {
            logger.error("QQ", "拉起 QQ 守护端失败: \(error.localizedDescription)")
            self.lastError = "拉起 QQ 失败: \(error.localizedDescription)"
            self.isRunning = false
        }
    }

    /// 后台异步监管连线与登录状态
    private func monitorAndConnect(targetUrl: URL) async {
        let autoAccount = storage.qqAccount.trimmingCharacters(in: .whitespacesAndNewlines)
        var quickLoginTriggered = false

        // 最多监控 25 秒
        for _ in 0..<50 {
            guard isRunning && !isStopping else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)

            // 1. 检测 WebUI 端口 (6099) 并尝试静默自登
            if !quickLoginTriggered {
                let reachable = await napCat.isWebUIReachable()
                if reachable {
                    if let list = try? await napCat.getQuickLoginList() {
                        self.quickLoginList = list
                    }

                    if let status = try? await napCat.checkLoginStatus() {
                        self.currentLoginPhase = status.loginPhase
                        if !status.isLogin {
                            let targetUin = !autoAccount.isEmpty ? autoAccount : (self.quickLoginList.first ?? "")
                            if !targetUin.isEmpty && storage.qqAutoQuickLogin {
                                quickLoginTriggered = true
                                logger.info("QQ", "检测到待登录状态，正在为账号 \(targetUin) 触发一键免密快捷登录...")
                                _ = try? await napCat.quickLogin(uin: targetUin)
                            }
                        } else {
                            quickLoginTriggered = true
                        }
                    }
                }
            }

            // 2. 检测 OneBot WebSocket (3001) 端口是否就绪
            if await testConnection(url: targetUrl) {
                logger.success("QQ", "本地 QQ 守护端口已就绪并开放！")
                await connectClient(targetUrl: targetUrl)
                return
            }
        }

        // 超时兜底提示
        if !isConnected && isRunning && !isStopping {
            if let status = try? await napCat.checkLoginStatus() {
                self.currentLoginPhase = status.loginPhase
                if !status.isLogin {
                    logger.warn("QQ", "💡 QQ 守护端已拉起但尚未登录，请点击卡片上的「登录管理」完成免密登录或扫码。")
                }
            }
        }
    }

    /// 连接并绑定 OneBot 客户端
    private func connectClient(targetUrl: URL) async {
        await MainActor.run {
            self.lastError = nil
        }
        qqClient.connect(url: targetUrl) { [weak self] event in
            Task { @MainActor in
                await self?.handleQQEvent(event)
            }
        }

        // 等待连线稳定后拉取一次账号信息
        try? await Task.sleep(nanoseconds: 800_000_000)
        try? await qqClient.fetchLoginInfo()

        // 尝试通过 NapCat HTTP API 同步一次精确的昵称和 UIN
        if let info = try? await napCat.getLoginInfo() {
            if let nick = info.nick, !nick.isEmpty {
                self.botNickname = nick
            }
            if let u = info.uin, let uInt = Int64(u), uInt > 0 {
                self.botUin = uInt
                if storage.qqAccount.isEmpty {
                    storage.qqAccount = u
                }
            }
        }
    }

    /// 彻底关停后台 QQ 与所有 Helper 进程
    private func stopDaemonProcess() async {
        daemonPipe?.fileHandleForReading.readabilityHandler = nil
        daemonPipe = nil

        if let proc = daemonProcess, proc.isRunning {
            proc.terminate()
        }
        daemonProcess = nil
        isDaemonRunning = false
        daemonPid = nil

        // 执行系统级 pkill 彻底清理所有 Electron QQ 辅助进程，释放端口
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killTask.arguments = ["-9", "-f", "/Applications/QQ.app"]
        try? killTask.run()
        killTask.waitUntilExit()

        for _ in 0..<4 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if !isSystemQQRunning() {
                break
            }
        }
    }

    /// 检查系统当前是否有 QQ 进程在跑
    public func isSystemQQRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "/Applications/QQ.app/Contents/MacOS/QQ"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return !data.isEmpty
    }

    /// 测试端口连通性 (使用原生 Network.framework，毫秒级检测，绝不挂起)
    private func testConnection(url: URL) async -> Bool {
        guard let host = url.host else { return false }
        let port = url.port ?? (url.scheme == "wss" ? 443 : (url.scheme == "ws" ? 80 : 3001))

        return await withCheckedContinuation { continuation in
            let endpointHost = NWEndpoint.Host(host)
            let endpointPort = NWEndpoint.Port(integerLiteral: UInt16(port))
            let conn = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)

            let lock = NSLock()
            var resumed = false

            let complete = { (success: Bool) in
                lock.lock()
                defer { lock.unlock() }
                if !resumed {
                    resumed = true
                    conn.cancel()
                    continuation.resume(returning: success)
                }
            }

            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + 1.0)
            timer.setEventHandler {
                timer.cancel()
                complete(false)
            }
            timer.resume()

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timer.cancel()
                    complete(true)
                case .failed(_):
                    timer.cancel()
                    complete(false)
                default:
                    break
                }
            }
            conn.start(queue: DispatchQueue.global())
        }
    }

    // MARK: - App 内一键免密快捷登录 & 账号密码登录

    /// 在 App 内执行一键快速免密登录
    public func performQuickLogin(uin: String) async -> Bool {
        if !isRunning || !isSystemQQRunning() {
            logger.info("QQ", "QQ 尚未启动，正在为您先行拉起后台守护服务...")
            start()
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let reachable = await napCat.isWebUIReachable()
                if reachable { break }
            }
        }

        do {
            logger.info("QQ", "正在请求一键免密登录 \(uin)...")
            let ok = try await napCat.quickLogin(uin: uin)
            if ok {
                await MainActor.run {
                    self.lastError = nil
                }
                storage.qqAccount = uin
                if let url = URL(string: storage.qqWsUrl) {
                    for _ in 0..<20 {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if await testConnection(url: url) {
                            await connectClient(targetUrl: url)
                            break
                        }
                    }
                }
                return true
            }
            return false
        } catch {
            logger.error("QQ", "一键登录失败: \(error.localizedDescription)")
            await MainActor.run {
                self.lastError = "一键登录失败: \(error.localizedDescription)"
            }
            return false
        }
    }

    /// 在 App 内执行账号密码登录
    public func performPasswordLogin(uin: String, password: String) async -> NapCatPasswordResult {
        if !isRunning || !isSystemQQRunning() {
            logger.info("QQ", "QQ 尚未启动，正在为您先行拉起后台守护服务...")
            start()
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let reachable = await napCat.isWebUIReachable()
                if reachable { break }
            }
        }

        do {
            let res = try await napCat.passwordLogin(uin: uin, password: password)
            if res.success {
                await MainActor.run {
                    self.lastError = nil
                }
                storage.qqAccount = uin
                storage.qqPassword = password
                if let url = URL(string: storage.qqWsUrl) {
                    for _ in 0..<20 {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if await testConnection(url: url) {
                            await connectClient(targetUrl: url)
                            break
                        }
                    }
                }
            }
            return res
        } catch {
            return NapCatPasswordResult(success: false, message: error.localizedDescription, needCaptcha: false, proofWaterUrl: nil, needNewDevice: false, jumpUrl: nil)
        }
    }

    /// 刷新并获取二维码
    public func refreshQRCode() async -> String? {
        do {
            let qr = try await napCat.getQRCode()
            self.qrCodeUrl = qr
            return qr
        } catch {
            if let qr = try? await napCat.refreshQRCode() {
                self.qrCodeUrl = qr
                return qr
            }
            return nil
        }
    }

    /// 检查并同步登录状态
    public func syncLoginStatus() async -> NapCatLoginStatus? {
        if let status = try? await napCat.checkLoginStatus() {
            self.currentLoginPhase = status.loginPhase
            self.isQrCodeAccepted = status.qrLoginAccepted
            if status.isLogin && !isConnected {
                if let url = URL(string: storage.qqWsUrl) {
                    await connectClient(targetUrl: url)
                }
            }
            return status
        }
        return nil
    }

    /// 打开本地 NapCat WebUI 扫码后台 (备用快捷方式)
    public func openWebUI() {
        if let url = URL(string: "http://127.0.0.1:6099/webui") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 打开 NapCat 一键配置向导
    public func presentNapCatInstaller() {
        self.showNapCatInstallSheet = true
    }

    /// 兼容入口：唤起 NapCat 一键配置向导
    public func openNapCatInstaller() {
        presentNapCatInstaller()
    }

    /// 打开官方 Mac QQ 下载官网
    public func openQQDownload() {
        if let url = URL(string: "https://im.qq.com/macqq/index.shtml") {
            NSWorkspace.shared.open(url)
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

    // MARK: - 📋 好友权限申请与审批管理

    private func loadPendingRequests() {
        guard FileManager.default.fileExists(atPath: pendingRequestsUrl.path),
              let data = try? Data(contentsOf: pendingRequestsUrl),
              let list = try? JSONDecoder().decode([QQPermissionRequest].self, from: data) else {
            self.pendingRequests = []
            return
        }
        self.pendingRequests = list
    }

    private func savePendingRequests() {
        if let data = try? JSONEncoder().encode(pendingRequests) {
            try? data.write(to: pendingRequestsUrl, options: .atomic)
        }
    }

    /// 用户私聊提交 /ai 权限申请
    public func submitPermissionRequest(userId: Int64, senderName: String, note: String) async -> (success: Bool, message: String) {
        if storage.isQQAdmin(userId: userId) {
            return (false, "您已经是白名单授权用户啦，可以直接和萌萌聊天喵~")
        }
        if pendingRequests.contains(where: { $0.userId == userId }) {
            return (false, "您已经提交过申请啦，正在等待主人（真实管理员）审核中，请耐心等候喵~")
        }

        let req = QQPermissionRequest(userId: userId, senderName: senderName, requestedAt: Date(), note: note)
        pendingRequests.append(req)
        savePendingRequests()

        logger.info("QQ", "收到来自 [\(senderName)](\(userId)) 的 AI 聊天权限申请")

        // 向所有真实管理员发送审批通知
        let masterList = storage.qqMasterAdminList
        if masterList.isEmpty {
            logger.warn("QQ", "收到权限申请，但当前未配置任何 QQ 真实管理员！")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            let timeStr = formatter.string(from: req.requestedAt)
            let noteInfo = note.isEmpty ? "" : "\n附言：\(note)"

            let notifyText = """
            🔔【收到 AI 聊天权限申请】
            申请人：\(senderName)
            QQ 号码：\(userId)
            申请时间：\(timeStr)\(noteInfo)

            👉 极简审批：直接回复【同意】或【拒绝】
            👉 引用审批：引用本条消息回复【同意】或【拒绝】
            👉 精确审批：回复【同意 \(userId)】或【拒绝 \(userId)】
            """
            for masterId in masterList {
                try? await qqClient.sendPrivateMsg(userId: masterId, text: notifyText)
            }
        }

        return (true, "📝 萌萌已经帮您向真实管理员（主人）提交申请啦！请稍等主人审核通过喵~")
    }

    /// 真实管理员批准申请 (加入普通白名单，受沙箱保护)
    public func approveRequest(userId: Int64) async -> (success: Bool, message: String) {
        let req = pendingRequests.first(where: { $0.userId == userId })
        let targetName = req?.senderName ?? "\(userId)"

        storage.addQQAdmin(id: userId)
        pendingRequests.removeAll { $0.userId == userId }
        savePendingRequests()

        logger.success("QQ", "已批准 [\(targetName)](\(userId)) 的权限申请，已加入普通白名单(沙箱隔离)")

        // 通知被批准的用户
        let welcomeMsg = """
        🎉 您的 AI 聊天权限申请已获主人批准！
        现在您可以随时向萌萌发送消息开始聊天啦喵~
        （已为您接入独立安全沙箱运行环境）
        """
        try? await qqClient.sendPrivateMsg(userId: userId, text: welcomeMsg)

        return (true, "✅ 已成功批准 \(targetName) (\(userId))，已加入普通白名单（沙箱隔离模式）！")
    }

    /// 真实管理员拒绝申请
    public func rejectRequest(userId: Int64) async -> (success: Bool, message: String) {
        let req = pendingRequests.first(where: { $0.userId == userId })
        let targetName = req?.senderName ?? "\(userId)"

        pendingRequests.removeAll { $0.userId == userId }
        savePendingRequests()

        logger.info("QQ", "已拒绝 [\(targetName)](\(userId)) 的权限申请")

        // 通知被拒绝的用户
        let rejectMsg = "抱歉喵，主人暂未批准您的 AI 聊天权限申请。"
        try? await qqClient.sendPrivateMsg(userId: userId, text: rejectMsg)

        return (true, "❌ 已拒绝 \(targetName) (\(userId)) 的权限申请。")
    }

    /// 处理 OneBot 事件报文
    private func handleQQEvent(_ event: [String: Any]) async {
        self.isConnected = true
        self.lastError = nil

        // 1. 响应拉取登录信息
        if let echo = event["echo"] as? String, echo == "sync_login_info",
           let data = event["data"] as? [String: Any] {
            if let uin = (data["user_id"] as? NSNumber)?.int64Value {
                self.botUin = uin
            }
            if let nick = data["nickname"] as? String {
                self.botNickname = nick
            }
            logger.success("QQ", "已成功识别登录账号: \(botNickname) (UIN: \(botUin))")
            return
        }

        // 2. 消息事件拦截处理
        guard let postType = event["post_type"] as? String, postType == "message" else { return }

        let messageType = event["message_type"] as? String ?? ""

        let userId: Int64
        if let num = event["user_id"] as? NSNumber {
            userId = num.int64Value
        } else if let str = event["user_id"] as? String, let num = Int64(str) {
            userId = num
        } else {
            userId = 0
        }

        var rawMessage = (event["raw_message"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if rawMessage.isEmpty {
            if let str = event["message"] as? String {
                rawMessage = str.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let arr = event["message"] as? [[String: Any]] {
                var pieces: [String] = []
                for item in arr {
                    if let type = item["type"] as? String, type == "text",
                       let data = item["data"] as? [String: Any],
                       let t = data["text"] as? String {
                        pieces.append(t)
                    }
                }
                rawMessage = pieces.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let sender = (event["sender"] as? [String: Any])?["nickname"] as? String ?? "\(userId)"

        guard !rawMessage.isEmpty else { return }

        // 提取引用回复内容 (如果有)
        var quotedText: String? = nil
        if let replyObj = event["reply"] as? [String: Any] {
            quotedText = replyObj["message"] as? String ?? replyObj["raw_message"] as? String
        }

        // 私聊处理
        if messageType == "private" {
            await handlePrivateMessage(userId: userId, senderName: sender, text: rawMessage, quotedText: quotedText)
        }
        // 群聊处理
        else if messageType == "group" {
            let groupId: Int64
            if let num = event["group_id"] as? NSNumber {
                groupId = num.int64Value
            } else if let str = event["group_id"] as? String, let num = Int64(str) {
                groupId = num
            } else {
                groupId = 0
            }
            await handleGroupMessage(groupId: groupId, userId: userId, senderName: sender, text: rawMessage)
        }
    }

    /// 从文本或引用消息中提取 QQ 号 (支持多种格式匹配)
    private func extractQQNumber(from text: String) -> Int64? {
        let patterns = [
            #"QQ\s*号码[：:]\s*(\d{5,12})"#,
            #"QQ[：:]\s*(\d{5,12})"#,
            #"\b(\d{5,12})\b"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
                let ns = text as NSString
                let matchStr = ns.substring(with: match.range(at: 1))
                if let num = Int64(matchStr) {
                    return num
                }
            }
        }
        return nil
    }

    /// 处理私聊消息
    private func handlePrivateMessage(userId: Int64, senderName: String, text: String, quotedText: String? = nil) async {
        logger.info("QQ", "收到来自 [\(senderName)](\(userId)) 的私聊: \(text.prefix(40))")

        let isMaster = storage.isQQMasterAdmin(userId: userId)
        let isAdmin = storage.isQQAdmin(userId: userId)
        let roleTag = isMaster ? "👑 真实管理员(宿主模式)" : "🛡️ 普通白名单(沙箱模式)"

        // 去除 CQ 码（如 [CQ:reply,id=123] 等），提取纯净命令文本
        let cleanText = text.replacingOccurrences(of: #"\s*\[CQ:[^\]]+\]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 真实管理员审批快捷判定 (支持极简回复【同意】/【拒绝】、引用回复【同意】/【拒绝】或带 QQ 号命令)
        if isMaster {
            let lower = cleanText.lowercased()
            let approveKeywords = ["同意", "通过", "批准", "准了", "准", "ok", "y", "yes", "1"]
            let rejectKeywords = ["拒绝", "不同意", "不通过", "驳回", "拒", "n", "no", "0"]

            let isApproveIntent = approveKeywords.contains(lower) ||
                lower.hasPrefix("/approve") || lower.hasPrefix("/pass") ||
                lower.hasPrefix("同意") || lower.hasPrefix("通过") || lower.hasPrefix("批准")

            let isRejectIntent = rejectKeywords.contains(lower) ||
                lower.hasPrefix("/reject") || lower.hasPrefix("/deny") ||
                lower.hasPrefix("拒绝") || lower.hasPrefix("不同意") || lower.hasPrefix("驳回")

            if isApproveIntent {
                // 解析目标 QQ：优先从消息文本提取，次选从引用回复消息中提取，最后取排队中的最新申请
                var targetId: Int64? = extractQQNumber(from: cleanText)
                if targetId == nil, let q = quotedText {
                    targetId = extractQQNumber(from: q)
                }
                if targetId == nil {
                    if pendingRequests.count == 1 {
                        targetId = pendingRequests.first?.userId
                    } else if pendingRequests.count > 1 {
                        targetId = pendingRequests.last?.userId
                    } else {
                        try? await qqClient.sendPrivateMsg(userId: userId, text: "当前暂无待审核的权限申请喵~")
                        return
                    }
                }

                if let tid = targetId {
                    let res = await approveRequest(userId: tid)
                    var replyMsg = res.message
                    if pendingRequests.count > 0 {
                        replyMsg += "\n💡 当前仍有 \(pendingRequests.count) 条待审核申请，可回复 /pending 查看列表。"
                    }
                    try? await qqClient.sendPrivateMsg(userId: userId, text: replyMsg)
                    return
                }
            }

            if isRejectIntent {
                var targetId: Int64? = extractQQNumber(from: cleanText)
                if targetId == nil, let q = quotedText {
                    targetId = extractQQNumber(from: q)
                }
                if targetId == nil {
                    if pendingRequests.count == 1 {
                        targetId = pendingRequests.first?.userId
                    } else if pendingRequests.count > 1 {
                        targetId = pendingRequests.last?.userId
                    } else {
                        try? await qqClient.sendPrivateMsg(userId: userId, text: "当前暂无待审核的权限申请喵~")
                        return
                    }
                }

                if let tid = targetId {
                    let res = await rejectRequest(userId: tid)
                    var replyMsg = res.message
                    if pendingRequests.count > 0 {
                        replyMsg += "\n💡 当前仍有 \(pendingRequests.count) 条待审核申请，可回复 /pending 查看列表。"
                    }
                    try? await qqClient.sendPrivateMsg(userId: userId, text: replyMsg)
                    return
                }
            }

            if lower == "/pending" || lower == "待审核" || lower == "申请列表" {
                if pendingRequests.isEmpty {
                    try? await qqClient.sendPrivateMsg(userId: userId, text: "当前暂无待审核的权限申请喵~")
                } else {
                    let listStr = pendingRequests.enumerated().map { (idx, req) in
                        "\(idx + 1). \(req.senderName) (\(req.userId))" + (req.note.isEmpty ? "" : " - 附言: \(req.note)")
                    }.joined(separator: "\n")
                    try? await qqClient.sendPrivateMsg(userId: userId, text: "📋 当前待审核申请：\n\(listStr)\n\n👉 极简审批：直接回复【同意】或【拒绝】\n👉 精准审批：回复【同意 <QQ>】或【拒绝 <QQ>】")
                }
                return
            }
        }

        // 2. 非白名单用户的权限拦截与 /ai 申请提交
        guard isAdmin else {
            if text.hasPrefix("/ai") {
                var note = ""
                if text.hasPrefix("/ai ") {
                    note = String(text.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let res = await submitPermissionRequest(userId: userId, senderName: senderName, note: note)
                try? await qqClient.sendPrivateMsg(userId: userId, text: res.message)
                return
            }

            logger.warn("QQ", "非白名单 QQ 用户 [\(senderName)] (ID: \(userId)) 发送消息，已引导发起申请: \(text.prefix(30))")
            let deniedText = """
            ⛔️ 您好喵~ 目前您尚未获得萌萌的 AI 聊天权限。

            💡 申请权限：您可以直接向萌萌发送 /ai 提交申请，待主人（真实管理员）审核通过后即可为您开启沙箱对话喵~
            """
            try? await qqClient.sendPrivateMsg(userId: userId, text: deniedText)
            return
        }

        let sessionKey = "qq:\(userId)"

        if storage.videoEnabledQQ && UniversalVideoResolver.isVideoLinkMessage(text) {
            if let url = UniversalVideoResolver.extractUrl(from: text) {
                logger.info("QQ", "解析视频直链: \(url)")
                try? await qqClient.sendPrivateMsg(userId: userId, text: "🔍 正在识别并提取最高画质直链...")

                do {
                    let (_, result) = try await UniversalVideoResolver.resolve(
                        rawUrl: url,
                        twitterApiKey: storage.twitterDownApiKey
                    )
                    var replyText = "🎬 视频解析成功：\n"
                    if !result.title.isEmpty {
                        replyText += "🏷️ 标题: \(result.title)\n"
                    }
                    replyText += "🔗 最高画质直链:\n\(result.url)"
                    if let size = result.fileSize {
                        replyText += "\n📦 大小: \(size)"
                    }
                    try await qqClient.sendPrivateMsg(userId: userId, text: replyText)
                    self.totalProcessed += 1
                } catch {
                    try? await qqClient.sendPrivateMsg(userId: userId, text: "❌ 视频解析失败: \(error.localizedDescription)")
                }
                return
            }
        }

        if text == "/status" || text == "状态" {
            guard isMaster else {
                logger.warn("QQ", "普通白名单用户 [\(senderName)](\(userId)) 尝试查询宿主状态，已拦截（仅限真实管理员）")
                try? await qqClient.sendPrivateMsg(userId: userId, text: "⛔️ 权限受限：Mac mini 宿主系统运行状态仅限真实管理员（设备主人）查看。您当前处于白名单沙箱安全模式。")
                return
            }
            let status = await agyService.getMacSystemStatus()
            let clean = status.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            try? await qqClient.sendPrivateMsg(userId: userId, text: clean)
            self.totalProcessed += 1
            return
        }

        if text == "/quota" || text == "/limit" || text == "额度" {
            guard isMaster else {
                logger.warn("QQ", "普通白名单用户 [\(senderName)](\(userId)) 尝试查询反重力额度，已拦截（仅限真实管理员）")
                try? await qqClient.sendPrivateMsg(userId: userId, text: "⛔️ 权限受限：反重力 AI 额度仅限真实管理员查看。")
                return
            }
            let quota = await agyService.getAgyQuotaReport()
            let clean = quota.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            try? await qqClient.sendPrivateMsg(userId: userId, text: clean)
            self.totalProcessed += 1
            return
        }

        if storage.agyEnabledQQ {
            let prompt = text.hasPrefix("/ai ") ? String(text.dropFirst(4)).trimmingCharacters(in: .whitespaces) : text

            // 1. 立即激活 QQ 原生“正在输入中...”状态 (eventType: 1)
            logger.info("QQ", "已激活 [\(senderName)](\(userId)) [\(roleTag)] QQ 原生“正在输入中...”状态，AI 思考生成中...")
            _ = try? await qqClient.setInputStatus(userId: userId, eventType: 1)

            // 2. 持续心跳保活：每 2.0 秒自动续期，确保在反重力思考完毕前输入状态无缝持续、绝不提前中断
            let typingTask = Task.detached { [weak qqClient] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if Task.isCancelled { break }
                    _ = try? await qqClient?.setInputStatus(userId: userId, eventType: 1)
                }
            }
            defer {
                typingTask.cancel()
            }

            do {
                logger.info("QQ", "正在请求反重力 AI 处理提问 [\(roleTag)]: \(prompt.prefix(40))...")
                let reply = try await agyService.executePrompt(prompt, sessionKey: sessionKey, isMasterAdmin: isMaster)

                // 3. AI 回复生成完毕：立刻停止心跳续期并在发送消息前显式结束输入状态 (eventType: 0)
                typingTask.cancel()
                _ = try? await qqClient.setInputStatus(userId: userId, eventType: 0)

                // 4. 输入状态刚结束，立刻将 AI 回复发送给用户，无缝衔接
                logger.info("QQ", "反重力 AI 成功返回，正在下发 QQ 私聊消息 (长度: \(reply.count))...")
                try await qqClient.sendPrivateMsg(userId: userId, text: reply)
                self.totalProcessed += 1
                logger.success("QQ", "反重力 AI 成功回复 [\(roleTag)] QQ 用户 [\(senderName)]")
            } catch {
                typingTask.cancel()
                _ = try? await qqClient.setInputStatus(userId: userId, eventType: 0)
                logger.error("QQ", "反重力 AI 执行异常: \(error.localizedDescription)")
                try? await qqClient.sendPrivateMsg(userId: userId, text: "❌ 反重力执行异常: \(error.localizedDescription)")
            }
        } else {
            logger.warn("QQ", "收到来自 [\(senderName)](\(userId)) 的消息，但 QQ 端 AI 功能当前未启用 (agyEnabledQQ=false)")
        }
    }

    /// 处理群聊消息
    private func handleGroupMessage(groupId: Int64, userId: Int64, senderName: String, text: String) async {
        let atTag = "[CQ:at,qq=\(botUin)]"
        let isMentioned = (botUin > 0 && text.contains(atTag)) || text.contains("@机器人")

        guard isMentioned else {
            if storage.videoEnabledQQ && UniversalVideoResolver.isVideoLinkMessage(text) && storage.isQQAdmin(userId: userId) {
                if let url = UniversalVideoResolver.extractUrl(from: text) {
                    if let (_, result) = try? await UniversalVideoResolver.resolve(rawUrl: url, twitterApiKey: storage.twitterDownApiKey) {
                        let replyText = "🎬 视频解析成功：\n\(result.url)"
                        try? await qqClient.sendGroupMsg(groupId: groupId, text: replyText, replyToUser: userId)
                    }
                }
            }
            return
        }

        // 群内被 @ 时，明确提示：AI 聊天目前仅支持私聊
        let replyText = "🐱 萌萌的 AI 智能对话目前仅支持私聊哦！请点击我的头像添加好友并发送私聊消息开启对话喵~（好友可私聊发送 /ai 申请权限）"
        try? await qqClient.sendGroupMsg(groupId: groupId, text: replyText, replyToUser: userId)
    }
}
