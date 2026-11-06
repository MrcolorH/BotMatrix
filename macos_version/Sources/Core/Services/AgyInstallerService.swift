import Foundation
import Combine
import AppKit

/// 反重力 (AGY) CLI 一键安装与环境管理服务
/// 具备安装前 Gemini / Google API 网络连通性深度预检，实时日志流推送与自动环境绑定
@MainActor
public final class AgyInstallerService: ObservableObject {
    public static let shared = AgyInstallerService()

    @Published public private(set) var isInstalling: Bool = false
    @Published public private(set) var isTestingNetwork: Bool = false
    @Published public private(set) var networkCheckPassed: Bool? = nil
    @Published public private(set) var networkCheckMessage: String? = nil
    @Published public private(set) var networkLatencyMs: Int? = nil

    @Published public private(set) var installStep: String = ""
    @Published public private(set) var installProgress: Double = 0.0
    @Published public private(set) var installLogs: [String] = []
    @Published public private(set) var errorMessage: String? = nil
    @Published public private(set) var isCompleted: Bool = false
    @Published public private(set) var installedVersion: String? = nil

    private var activeProcess: Process?
    private let fileManager = FileManager.default
    private let logger = LogService.shared

    public var defaultCliURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/agy")
    }

    private init() {}

    private func appendLog(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(text)"
        self.installLogs.append(line)
        self.logger.info("AGY-Installer", text)
    }

    public func reset() {
        self.isInstalling = false
        self.isTestingNetwork = false
        self.networkCheckPassed = nil
        self.networkCheckMessage = nil
        self.networkLatencyMs = nil
        self.installStep = ""
        self.installProgress = 0.0
        self.installLogs = []
        self.errorMessage = nil
        self.isCompleted = false
        self.installedVersion = nil
    }

    // MARK: - 1. 网络连通性预检 (Gemini API & Antigravity 官方服务)
    public func testNetworkConnectivity() async -> Bool {
        self.isTestingNetwork = true
        self.networkCheckMessage = "正在探测 Gemini 与 Antigravity 节点连通性..."
        appendLog("🌐 开始检测网络环境 (Gemini API 与 Google 服务节点)...")

        let endpoints = [
            ("Gemini API 节点", URL(string: "https://generativelanguage.googleapis.com")!),
            ("Antigravity 官方安装源", URL(string: "https://antigravity.google/cli/install.sh")!)
        ]

        var successCount = 0
        var totalLatencyMs = 0

        for (name, url) in endpoints {
            appendLog("🔍 正在测试连通: \(name) (\(url.host ?? ""))")
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 7.0
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let startTime = CFAbsoluteTimeGetCurrent()
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                if let httpResp = response as? HTTPURLResponse {
                    // HTTP 状态码 200~499 均代表网络握手成功，成功到达 Google 节点
                    if httpResp.statusCode < 500 {
                        successCount += 1
                        totalLatencyMs += elapsedMs
                        appendLog("  ✓ \(name) 连接成功！响应状态: \(httpResp.statusCode)，延迟: \(elapsedMs)ms")
                    } else {
                        appendLog("  ⚠️ \(name) 收到服务端异常响应: \(httpResp.statusCode)")
                    }
                }
            } catch {
                let nsError = error as NSError
                appendLog("  ❌ \(name) 连接失败: \(nsError.localizedDescription)")
            }
        }

        self.isTestingNetwork = false

        if successCount >= 1 {
            let avgLatency = totalLatencyMs / max(1, successCount)
            self.networkCheckPassed = true
            self.networkLatencyMs = avgLatency
            self.networkCheckMessage = "网络连通正常 (Gemini/Google 节点畅通，延迟约 \(avgLatency)ms)"
            appendLog("✅ 网络环境测试通过：Google / Gemini 网络链路通畅，具备安装与运行条件。")
            return true
        } else {
            self.networkCheckPassed = false
            self.networkLatencyMs = nil
            self.networkCheckMessage = "网络未连通：无法访问 Gemini / Antigravity 服务节点。请开启科学上网（魔法环境）后重试。"
            appendLog("❌ 网络连通性测试未通过：无法连接到 Gemini 官方服务。")
            appendLog("⚠️ 重要提示：反重力 (AGY) 底层依赖 Google 链路，国内直连无法正常访问。")
            appendLog("💡 解决方案：请开启科学上网软件（推荐开启 Clash / Surge 的 TUN 虚拟网卡模式或全局系统代理），确保浏览器可访问 Google 后再点击重试。")
            return false
        }
    }

    // MARK: - 2. 一键开始全流程安装
    public func startInstallation() async {
        guard !isInstalling else { return }

        self.isInstalling = true
        self.errorMessage = nil
        self.isCompleted = false
        self.installProgress = 0.05
        self.installLogs.removeAll()

        appendLog("🚀 启动反重力 (AGY) CLI 自动化安装与部署向导...")

        // 第一步：网络环境强制预检
        self.installStep = "步骤 1/4: 探测 Gemini 网络连通性..."
        self.installProgress = 0.15

        let isNetworkOk = await testNetworkConnectivity()
        guard isNetworkOk else {
            self.isInstalling = false
            self.errorMessage = "网络未连通：无法访问 Gemini / Google 节点，请开启科学上网环境后重新尝试。"
            self.installStep = "❌ 网络预检失败，等待环境调整"
            return
        }

        // 第二步：准备目标目录
        self.installStep = "步骤 2/4: 初始化运行目录环境..."
        self.installProgress = 0.30

        let binDir = defaultCliURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: binDir, withIntermediateDirectories: true, attributes: nil)
            appendLog("✓ 本地目录就绪: \(binDir.path)")
        } catch {
            self.isInstalling = false
            self.errorMessage = "无法创建目录 \(binDir.path): \(error.localizedDescription)"
            appendLog("❌ 目录初始化失败: \(error.localizedDescription)")
            return
        }

        // 第三步：运行官方安装脚本
        self.installStep = "步骤 3/4: 下载并部署官方 Antigravity CLI..."
        self.installProgress = 0.45
        appendLog("📥 正在调用官方 Bootstrapper 脚本 (https://antigravity.google/cli/install.sh)...")

        let installCmd = "curl -fsSL https://antigravity.google/cli/install.sh | bash"
        let success = await runShellCommand(installCmd)
        guard success else {
            self.isInstalling = false
            self.errorMessage = "反重力 CLI 脚本安装执行失败，请检查下方日志详情。"
            self.installStep = "❌ 安装执行失败"
            return
        }

        self.installProgress = 0.80

        // 第四步：权限修复与版本验证
        self.installStep = "步骤 4/4: 校验二进制并自动绑定配置..."
        appendLog("🔐 正在验证可执行二进制文件与权限...")

        let agyPath = defaultCliURL.path
        if fileManager.fileExists(atPath: agyPath) {
            // 确保具有可执行权限
            let chmodProcess = Process()
            chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProcess.arguments = ["+x", agyPath]
            try? chmodProcess.run()
            chmodProcess.waitUntilExit()

            appendLog("✓ 已赋予可执行权限: chmod +x \(agyPath)")

            // 运行 agy --version
            let version = await getAgyVersion(path: agyPath)
            self.installedVersion = version
            appendLog("🎉 反重力 CLI 验证成功！当前版本: \(version)")

            // 自动回填并持久化到设置
            StorageService.shared.agyCliPath = agyPath
            appendLog("✓ 已自动绑定路径至 BotMatrix 配置: \(agyPath)")

            self.installProgress = 1.0
            self.installStep = "🎉 安装并配置完成！反重力 CLI (v\(version)) 已就绪"
            self.isCompleted = true
            self.isInstalling = false
        } else {
            // 兜底尝试查找全局 PATH 中的 agy
            if let whichPath = await findAgyInPath() {
                appendLog("✓ 在系统全局路径找到 agy: \(whichPath)")
                let version = await getAgyVersion(path: whichPath)
                self.installedVersion = version
                StorageService.shared.agyCliPath = whichPath
                self.installProgress = 1.0
                self.installStep = "🎉 安装并配置完成！反重力 CLI (v\(version)) 已就绪"
                self.isCompleted = true
                self.isInstalling = false
            } else {
                self.isInstalling = false
                self.errorMessage = "未在 \(agyPath) 找到生成的 agy 可执行文件。"
                self.installStep = "❌ 二进制未找到"
                appendLog("❌ 校验失败：未在预定位置找到 agy。")
            }
        }
    }

    /// 取消正在进行的安装
    public func cancel() {
        if let proc = activeProcess, proc.isRunning {
            proc.terminate()
            appendLog("⚠️ 用户已手动中断安装过程。")
        }
        self.isInstalling = false
        self.installStep = "已取消安装"
    }

    // MARK: - 辅助执行方法
    private func runShellCommand(_ command: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]

                // 继承安全且完整的环境变量，并补充常见 PATH
                var env = ProcessInfo.processInfo.environment
                let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(NSHomeDirectory())/.local/bin"
                env["PATH"] = extraPaths + (env["PATH"].map { ":\($0)" } ?? "")
                env["TERM"] = "xterm-256color"
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                DispatchQueue.main.async {
                    self.activeProcess = process
                }

                let fileHandle = pipe.fileHandleForReading
                fileHandle.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                    let lines = text.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            DispatchQueue.main.async {
                                self?.appendLog(trimmed)
                            }
                        }
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    fileHandle.readabilityHandler = nil
                    let exitCode = process.terminationStatus
                    DispatchQueue.main.async {
                        self.activeProcess = nil
                    }
                    continuation.resume(returning: exitCode == 0)
                } catch {
                    fileHandle.readabilityHandler = nil
                    DispatchQueue.main.async {
                        self.appendLog("❌ 执行进程报错: \(error.localizedDescription)")
                        self.activeProcess = nil
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func getAgyVersion(path: String) async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return out.isEmpty ? "未知版本" : out
        } catch {
            return "未知版本"
        }
    }

    private func findAgyInPath() async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["agy"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return out.isEmpty ? nil : out
        } catch {
            return nil
        }
    }
}
