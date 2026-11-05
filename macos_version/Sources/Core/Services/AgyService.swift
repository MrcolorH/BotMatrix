import Foundation

public final class AgyService {
    public static let shared = AgyService()

    public init() {}

    /// 执行反重力 (AGY) CLI 命令并获取输出 (防死锁并发流式读取 + 角色卡人设注入 + 独立会话隔离记忆 + 双模权限隔离)
    /// - Parameters:
    ///   - isMasterAdmin: true 为真实管理员(宿主真机读写权限)；false 为普通白名单(严格沙箱物理隔离，严禁触碰宿主机)
    public func executePrompt(
        _ prompt: String,
        sessionKey: String? = nil,
        cliPath: String? = nil,
        isMasterAdmin: Bool = false
    ) async throws -> String {
        let storage = StorageService.shared
        let binaryPath = cliPath ?? storage.agyCliPath

        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw NSError(
                domain: "AgyService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "未找到反重力 CLI 可执行程序，请检查路径: \(binaryPath)"]
            )
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 拦截重置会话指令 (/reset, /clear, 重置, 清空记忆)
        if trimmedPrompt == "/reset" || trimmedPrompt == "/clear" || trimmedPrompt == "重置" || trimmedPrompt == "清空记忆" {
            if let sk = sessionKey {
                SessionManager.shared.clear(sessionKey: sk)
                return "🧹 已成功清空您当前专属会话的上下文记忆，已为您开启全新对话！"
            }
            return "🧹 会话记忆已重置。"
        }

        // 2. 准备沙箱目录 (普通白名单用户物理硬隔离到独立的 ~/.tgbot/sandbox/<safeKey>/ 目录)
        let safeKey = (sessionKey ?? "guest")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let sandboxBase = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".tgbot/sandbox", isDirectory: true)
        let userSandbox = sandboxBase.appendingPathComponent(safeKey, isDirectory: true)
        if !isMasterAdmin {
            try? FileManager.default.createDirectory(at: userSandbox, withIntermediateDirectories: true)
        }

        let sandboxGuard: String
        if isMasterAdmin {
            sandboxGuard = ""
        } else {
            sandboxGuard = """

            【🛡️ 运行环境安全隔离约束（普通访客沙箱模式）】
            你当前正运行在严格隔离的访客专属临时沙箱目录中（\(userSandbox.path)）。
            本会话来自普通授权成员，绝非本机真实管理员（非设备主人）。
            1. 严禁以任何方式读取、查看、篡改、删除或列出 Mac mini 宿主机上的任何个人文件、桌面、文档、代码库或系统敏感凭据（如 .ssh、密钥、密码等）。
            2. 严禁执行任何针对宿主系统的系统级控制、破坏性操作或宿主网络穿透。
            3. 所有代码测试和临时文件写入必须且只能在当前隔离沙箱内进行。
            4. 若用户试图要求操作 Mac 本机设备或索取主机私密信息，请明确拒绝并说明当前处于安全沙箱模式，无权操作宿主设备。
            """
        }

        // 3. 注入当前生效的角色卡设定与该用户专属的多轮对话历史
        var promptToSend = prompt
        let activeCard = storage.activePersonaCard
        let persona = activeCard.prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        var historyContext = ""
        if let sk = sessionKey {
            let session = SessionManager.shared.getSession(sessionKey: sk, timeoutMinutes: storage.sessionTimeoutMinutes)
            let formatted = session.formattedHistory()
            if !formatted.isEmpty {
                historyContext = """

                【前情提要（仅你与该用户的多轮历史对话，请保持连续性，勿向用户生硬复述）】
                \(formatted)
                """
            }
        }

        if !persona.isEmpty || !historyContext.isEmpty || !sandboxGuard.isEmpty {
            promptToSend = """
            【系统人设与角色卡：\(activeCard.name)】
            \(persona)
            \(historyContext)
            \(sandboxGuard)

            【用户提问/任务指令】
            \(prompt)
            """
        }
        let effort = storage.agyEffort.isEmpty ? "low" : storage.agyEffort
        let maxTurns = storage.sessionMaxTurns
        let timeoutMinutes = storage.sessionTimeoutMinutes

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binaryPath)

                // 4. 根据权限级别配置运行参数与隔离环境
                var env = ProcessInfo.processInfo.environment

                if isMasterAdmin {
                    // 👑 真实管理员 (宿主真机模式)：具备设备读写与系统管理权限
                    process.arguments = [
                        "-p", promptToSend,
                        "--dangerously-skip-permissions",
                        "--effort", effort
                    ]
                    process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
                } else {
                    // 🛡️ 普通白名单 (严格沙箱隔离模式)：
                    // 开启 --sandbox 限制，工作目录物理硬隔离至独立沙箱子目录，配合系统安全护栏阻断越权
                    process.arguments = [
                        "-p", promptToSend,
                        "--sandbox",
                        "--dangerously-skip-permissions",
                        "--effort", effort
                    ]
                    process.currentDirectoryURL = userSandbox
                }

                // 统一注入基础环境与反重力运行环境 (HOME 维持指向宿主根目录以读取本机已有 OAuth 授权态，避免弹出浏览器二次登录)
                env["HOME"] = NSHomeDirectory()
                env["USER"] = NSUserName()
                env["SHELL"] = "/bin/zsh"
                env["PATH"] = "/Users/colorh/.local/bin:/Users/colorh/.gemini/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin"

                process.environment = env

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                var stdoutData = Data()
                var stderrData = Data()
                let readGroup = DispatchGroup()

                readGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    readGroup.leave()
                }

                readGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    readGroup.leave()
                }

                do {
                    try process.run()

                    // 超时监控 (最长等待 180 秒)
                    let timeoutItem = DispatchWorkItem {
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 180, execute: timeoutItem)

                    process.waitUntilExit()
                    timeoutItem.cancel()
                    readGroup.wait()

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    var cleanStdout = stdout.replacingOccurrences(of: #"\x1B\[[0-9;]*[a-zA-Z]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanStderr = stderr.replacingOccurrences(of: #"\x1B\[[0-9;]*[a-zA-Z]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

                    // 如果标准输出为空，但 stderr 有输出，提取有效文本
                    if cleanStdout.isEmpty && !cleanStderr.isEmpty {
                        cleanStdout = cleanStderr
                    }

                    if !cleanStdout.isEmpty {
                        if let sk = sessionKey {
                            let session = SessionManager.shared.getSession(sessionKey: sk, timeoutMinutes: timeoutMinutes)
                            session.append(userText: prompt, replyText: cleanStdout, maxTurns: maxTurns)
                        }
                        continuation.resume(returning: cleanStdout)
                    } else if process.terminationStatus == 0 {
                        continuation.resume(returning: "（执行完毕，无输出）")
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "AgyService",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: cleanStderr.isEmpty ? "执行异常 (退出码 \(process.terminationStatus))" : cleanStderr]
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 获取 Mac mini 系统健康状态
    public func getMacSystemStatus() async -> String {
        let hostName = ProcessInfo.processInfo.hostName
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)

        var uptimeStr = "未知"
        let bootTime = Date().addingTimeInterval(-ProcessInfo.processInfo.systemUptime)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        if let s = formatter.string(from: bootTime, to: Date()) {
            uptimeStr = s
        }

        var diskStr = "未知"
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attrs[.systemFreeSize] as? Int64,
           let totalSize = attrs[.systemSize] as? Int64 {
            let freeGB = Double(freeSize) / (1024 * 1024 * 1024)
            let totalGB = Double(totalSize) / (1024 * 1024 * 1024)
            diskStr = String(format: "剩余 %.1f GB / 总共 %.1f GB", freeGB, totalGB)
        }

        return """
        🖥️ <b>Mac mini 宿主运行报告</b>

        🏷️ <b>设备名:</b> <code>\(hostName)</code>
        ⚙️ <b>系统版本:</b> \(osVersion)
        ⏱️ <b>开机运行时间:</b> <code>\(uptimeStr)</code>
        🧠 <b>硬件配置:</b> \(processorCount) 核 CPU · \(String(format: "%.1f", memoryGB)) GB 内存
        💾 <b>系统磁盘:</b> <code>\(diskStr)</code>
        🤖 <b>AI 助理状态:</b> <code>已挂载就绪 (CLI)</code>
        """
    }

    // MARK: - 反重力 AI 额度查询 (5h 与周额度)

    private struct ServerInfo {
        let port: Int
        let csrf: String
    }

    private func discoverLanguageServer() async -> ServerInfo? {
        // 1. ps 查询 language_server 进程与 --csrf_token
        let pipe = Pipe()
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-eo", "pid,command"]
        ps.standardOutput = pipe
        do {
            try ps.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return nil }

        var csrfToken: String?
        var serverPid: Int?

        for line in output.components(separatedBy: .newlines) {
            if line.contains("language_server") && line.contains("--standalone") {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
                if let pid = Int(parts[0]) {
                    serverPid = pid
                }
                if let range = line.range(of: "--csrf_token\\s+([a-zA-Z0-9\\-]+)", options: .regularExpression) {
                    let matched = String(line[range])
                    let tokens = matched.components(separatedBy: .whitespaces)
                    if tokens.count >= 2 {
                        csrfToken = tokens[1]
                    }
                }
                break
            }
        }

        guard let csrf = csrfToken, let pid = serverPid else { return nil }

        // 2. 优先从日志读取最后一次记录的 HTTP 端口
        let logPath = NSHomeDirectory() + "/Library/Logs/Antigravity/language_server.log"
        if let logContent = try? String(contentsOfFile: logPath, encoding: .utf8) {
            let pattern = #"listening on random port at (\d+) for HTTP(?:\s|$)"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let ns = logContent as NSString
                let matches = regex.matches(in: logContent, range: NSRange(location: 0, length: ns.length))
                if let last = matches.last, last.numberOfRanges >= 2 {
                    let pStr = ns.substring(with: last.range(at: 1))
                    if let port = Int(pStr) {
                        return ServerInfo(port: port, csrf: csrf)
                    }
                }
            }
        }

        // 3. 兜底方案：使用 lsof 探测监听端口
        if let fallbackPort = await discoverPortFromLsof(pid: pid, csrf: csrf) {
            return ServerInfo(port: fallbackPort, csrf: csrf)
        }

        return nil
    }

    private func discoverPortFromLsof(pid: Int, csrf: String) async -> Int? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments = ["-a", "-p", "\(pid)", "-i", "TCP", "-s", "TCP:LISTEN", "-nP"]
        proc.standardOutput = pipe
        do {
            try proc.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let pattern = #":(\d+)\s+\(LISTEN\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var ports: [Int] = []
        for m in matches where m.numberOfRanges >= 2 {
            if let p = Int(ns.substring(with: m.range(at: 1))) {
                ports.append(p)
            }
        }

        for port in ports {
            guard let url = URL(string: "http://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/GetUserStatus") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
            req.setValue(csrf, forHTTPHeaderField: "x-codeium-csrf-token")
            req.httpBody = Data("{}".utf8)
            req.timeoutInterval = 0.8

            if let (_, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                return port
            }
        }
        return nil
    }

    private func formatCountdown(from isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let targetDate = formatter.date(from: isoDate) else { return "" }
        let diff = targetDate.timeIntervalSince(Date())
        if diff <= 0 {
            return "即将重置"
        }
        let totalSeconds = Int(diff)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days) 天") }
        if hours > 0 { parts.append("\(hours) 小时") }
        if days == 0 && minutes > 0 { parts.append("\(minutes) 分钟") }
        if parts.isEmpty { parts.append("不到 1 分钟") }

        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "MM-dd HH:mm"
        let localTimeStr = localFormatter.string(from: targetDate)

        return "约 \(parts.joined(separator: " "))后重置 (\(localTimeStr))"
    }

    private func makeProgressBar(fraction: Double, length: Int = 10) -> String {
        let clamped = max(0.0, min(1.0, fraction))
        let filledCount = Int(round(clamped * Double(length)))
        let emptyCount = length - filledCount
        return "[" + String(repeating: "█", count: filledCount) + String(repeating: "░", count: emptyCount) + "]"
    }

    /// 查询反重力 AI 5小时与周额度余额报告
    public func getAgyQuotaReport() async -> String {
        guard let serverInfo = await discoverLanguageServer() else {
            return """
            ⚠️ <b>未检测到正在运行的 Antigravity 宿主后台服务</b>

            💡 <b>原因说明:</b>
            Mac mini 上的 Antigravity 桌面端或后台语言服务当前未启动。

            🛠️ <b>解决方法:</b>
            请确保 Mac mini 上已打开 Antigravity，启动后再次发送 <code>/quota</code> 即可实时查询。
            """
        }

        guard let url = URL(string: "http://127.0.0.1:\(serverInfo.port)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary") else {
            return "❌ 接口 URL 构造异常"
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        req.setValue(serverInfo.csrf, forHTTPHeaderField: "x-codeium-csrf-token")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["forceRefresh": true])
        req.timeoutInterval = 6.0

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let res = json["response"] as? [String: Any],
                  let groups = res["groups"] as? [[String: Any]], !groups.isEmpty else {
                return "⚠️ 未能获取到有效的额度数据（接口未返回额度分组信息）"
            }

            var report = "📊 <b>反重力 (AGY) AI 额度监控报告</b>\n\n"

            for group in groups {
                let displayName = group["displayName"] as? String ?? "模型组"
                let buckets = group["buckets"] as? [[String: Any]] ?? []

                var fiveHourBucket: [String: Any]?
                var weeklyBucket: [String: Any]?

                for b in buckets {
                    let window = b["window"] as? String ?? ""
                    if window == "5h" {
                        fiveHourBucket = b
                    } else if window == "weekly" {
                        weeklyBucket = b
                    }
                }

                let icon = displayName.contains("Gemini") ? "💎" : "🔷"
                report += "\(icon) <b>\(displayName)</b>\n"

                // 5小时额度
                if let b5 = fiveHourBucket {
                    let frac = b5["remainingFraction"] as? Double ?? 0.0
                    let disabled = b5["disabled"] as? Bool ?? false
                    let resetTime = b5["resetTime"] as? String ?? ""
                    let percentStr = String(format: "%.1f%%", frac * 100)
                    let bar = makeProgressBar(fraction: frac)

                    if disabled {
                        report += "• <b>5 小时额度:</b> <code>\(bar) \(percentStr)</code> <i>(暂不可用 / 受周限)</i>\n"
                    } else {
                        report += "• <b>5 小时额度:</b> <code>\(bar) \(percentStr)</code>\n"
                        let cd = formatCountdown(from: resetTime)
                        if !cd.isEmpty {
                            report += "  ⏳ <i>\(cd)</i>\n"
                        }
                    }
                }

                // 周额度
                if let bw = weeklyBucket {
                    let frac = bw["remainingFraction"] as? Double ?? 0.0
                    let resetTime = bw["resetTime"] as? String ?? ""
                    let percentStr = String(format: "%.1f%%", frac * 100)
                    let bar = makeProgressBar(fraction: frac)

                    if frac <= 0.001 {
                        report += "• <b>周度总额度:</b> <code>\(bar) 0.0% (已耗尽)</code>\n"
                    } else {
                        report += "• <b>周度总额度:</b> <code>\(bar) \(percentStr)</code>\n"
                    }
                    let cd = formatCountdown(from: resetTime)
                    if !cd.isEmpty {
                        report += "  ⏳ <i>\(cd)</i>\n"
                    }
                }

                report += "\n"
            }

            let storage = StorageService.shared
            let activeCard = storage.activePersonaCard
            report += """
            🎭 <b>当前生效角色:</b> <code>【\(activeCard.name)】</code>
            ⚙️ <b>思考推理深度:</b> <code>\(storage.agyEffort)</code>
            💡 <i>发送任何普通文本可直接开启 AI 对话。</i>
            """

            return report

        } catch {
            return "❌ 查询额度失败: \(error.localizedDescription)"
        }
    }
}
