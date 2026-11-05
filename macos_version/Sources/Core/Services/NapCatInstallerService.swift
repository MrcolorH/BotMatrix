import Foundation
import Combine
import AppKit

/// NapCat 安装与环境管理服务 (支持内置多线路极速下载、自动部署双开引导器与 QQ 入口接管)
@MainActor
public final class NapCatInstallerService: ObservableObject {
    public static let shared = NapCatInstallerService()

    @Published public private(set) var isInstalling: Bool = false
    @Published public private(set) var installStep: String = ""
    @Published public private(set) var installProgress: Double = 0.0
    @Published public private(set) var installLogs: [String] = []
    @Published public private(set) var errorMessage: String? = nil
    @Published public private(set) var isCompleted: Bool = false

    @Published public private(set) var isRestoring: Bool = false
    @Published public private(set) var restoreMessage: String? = nil

    private let fileManager = FileManager.default
    private let logger = LogService.shared

    // 相关关键路径
    public let qqAppURL = URL(fileURLWithPath: "/Applications/QQ.app")
    public let qqPackageURL = URL(fileURLWithPath: "/Applications/QQ.app/Contents/Resources/app/package.json")
    public let qqPackageBakURL = URL(fileURLWithPath: "/Applications/QQ.app/Contents/Resources/app/package.json.bak")
    
    public var docURL: URL {
        URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Containers/com.tencent.qq/Data/Documents")
    }
    public var napcatDirURL: URL {
        docURL.appendingPathComponent("napcat", isDirectory: true)
    }
    public var loaderURL: URL {
        docURL.appendingPathComponent("loadNapCat.js")
    }
    public var versionsURL: URL {
        URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/versions")
    }

    // 候选下载源 (优先尝试国内镜像加速线路，加速失效时自动回退官方 GitHub Release)
    private let downloadCandidates: [(name: String, url: String)] = [
        ("国内镜像加速 1 (ghproxy.net)", "https://ghproxy.net/https://github.com/NapNeko/NapCatQQ/releases/latest/download/NapCat.Framework.zip"),
        ("国内镜像加速 2 (mirror.ghproxy.com)", "https://mirror.ghproxy.com/https://github.com/NapNeko/NapCatQQ/releases/latest/download/NapCat.Framework.zip"),
        ("GitHub 官方线路 (Direct)", "https://github.com/NapNeko/NapCatQQ/releases/latest/download/NapCat.Framework.zip")
    ]

    private init() {}

    private func appendLog(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(text)"
        self.installLogs.append(line)
        self.logger.info("NapCat-Installer", text)
    }

    public func reset() {
        self.isInstalling = false
        self.installStep = ""
        self.installProgress = 0.0
        self.installLogs = []
        self.errorMessage = nil
        self.isCompleted = false
    }

    /// 一键开始全自动安装
    public func startInstallation() async {
        guard !isInstalling else { return }
        self.reset()
        self.isInstalling = true

        do {
            // 步骤 1: 检查环境
            self.installStep = "步骤 1/4: 检测系统 QQ 运行环境..."
            self.installProgress = 0.05
            self.appendLog("正在检测 Mac QQ 客户端环境...")

            guard fileManager.fileExists(atPath: qqAppURL.path) else {
                throw NSError(domain: "NapCatInstaller", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "未检测到 /Applications/QQ.app。请先安装官方 Mac QQ 客户端。"
                ])
            }
            self.appendLog("✓ 已检测到官方 Mac QQ 客户端 (/Applications/QQ.app)")

            // 检查 QQ 是否在运行
            if isQQRunning() {
                self.appendLog("💡 提示：当前检测到 QQ 进程在运行，安装后重新启动即可生效。")
            }

            // 步骤 2: 下载核心框架
            self.installStep = "步骤 2/4: 正在极速拉取 NapCat.Framework 核心依赖包..."
            self.installProgress = 0.15
            self.appendLog("准备连接下载线路拉取 NapCat 核心依赖压缩包...")

            let downloadedZip = try await downloadNapCatZip()
            let fileSize = (try? fileManager.attributesOfItem(atPath: downloadedZip.path)[.size] as? Int64) ?? 0
            self.appendLog("✓ 核心组件压缩包下载完成 (\(String(format: "%.1f", Double(fileSize) / 1048576)) MB)")

            // 步骤 3: 解压并部署核心框架与默认配置
            self.installStep = "步骤 3/4: 部署 NapCat 组件与 OneBot 网关配置..."
            self.installProgress = 0.70
            self.appendLog("正在解压核心组件至 QQ 沙盒 Documents 目录...")

            try extractAndDeploy(zipURL: downloadedZip)
            self.appendLog("✓ NapCat 核心框架部署完成")

            self.appendLog("正在写入双开引导器 (loadNapCat.js)...")
            try writeLoaderScript()
            self.appendLog("✓ 双开引导脚本生成完成")

            self.appendLog("正在初始化 OneBot v11 与 WebUI 基础配置...")
            try ensureDefaultConfigs()
            self.appendLog("✓ 默认端口 (WebSocket 3001, WebUI 6099) 初始化完成")

            // 步骤 4: 安全接管 QQ 入口
            self.installStep = "步骤 4/4: 正在接管 QQ 启动入口并挂接守护..."
            self.installProgress = 0.85
            self.appendLog("正在安全修改 QQ package.json 启动项...")

            try patchQQEntryPoint()
            self.appendLog("✓ 官方 QQ 启动入口已成功指向 NapCat 引导器")

            // 尝试同步热更新目录
            let hotPatched = try patchHotUpdatePackages()
            if hotPatched > 0 {
                self.appendLog("✓ 同步接管了 \(hotPatched) 个 QQ 热更新版本入口")
            }

            self.installProgress = 1.0
            self.installStep = "🎉 一键安装配置已圆满完成！"
            self.isCompleted = true
            self.isInstalling = false
            self.appendLog("======================================")
            self.appendLog("🚀 NapCat 协议端已无缝就绪，现在您可以直接点击【一键启动 QQ】登录体验！")
            StorageService.shared.notifyEnvironmentChanged()

        } catch {
            self.isInstalling = false
            self.errorMessage = error.localizedDescription
            self.appendLog("❌ 安装中断: \(error.localizedDescription)")
            self.logger.error("NapCat-Installer", "安装失败: \(error.localizedDescription)")
        }
    }

    /// 检查是否有 QQ 实例运行
    private func isQQRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == "com.tencent.qq" || app.localizedName == "QQ"
        }
    }

    /// 多线路下载 NapCat.Framework.zip
    private func downloadNapCatZip() async throws -> URL {
        var lastError: Error?
        let tempZipPath = fileManager.temporaryDirectory.appendingPathComponent("NapCat_\(UUID().uuidString).zip")

        for (index, candidate) in downloadCandidates.enumerated() {
            self.appendLog("[\(index + 1)/\(downloadCandidates.count)] 正在连接 \(candidate.name)...")
            guard let downloadUrl = URL(string: candidate.url) else { continue }

            do {
                let downloadedURL = try await downloadWithProgress(url: downloadUrl, targetURL: tempZipPath)
                return downloadedURL
            } catch {
                lastError = error
                self.appendLog("⚠️ 线路 \(candidate.name) 异常: \(error.localizedDescription)，尝试下一线路...")
            }
        }

        throw lastError ?? NSError(domain: "NapCatInstaller", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "所有下载线路均尝试失败，请检查网络连接后重试。"
        ])
    }

    /// 带进度反馈的下载辅助类
    private func downloadWithProgress(url: URL, targetURL: URL) async throws -> URL {
        let delegate = DownloadProgressDelegate { [weak self] progress, received, total in
            Task { @MainActor in
                // 下载在 0.15 ~ 0.65 之间平滑推进
                self?.installProgress = 0.15 + progress * 0.50
            }
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (tempFile, response) = try await session.download(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 200 || httpResponse.statusCode >= 400 {
            throw NSError(domain: "DownloadError", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP 响应错误状态码: \(httpResponse.statusCode)"
            ])
        }

        if fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }
        try fileManager.moveItem(at: tempFile, to: targetURL)
        return targetURL
    }

    /// 解压并部署
    private func extractAndDeploy(zipURL: URL) throws {
        let stagingDir = fileManager.temporaryDirectory.appendingPathComponent("NapCat_Extract_\(UUID().uuidString)")
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDir) }

        // 使用系统内置的 ditto 解压
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-xk", zipURL.path, stagingDir.path]
        try proc.run()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            throw NSError(domain: "ExtractError", code: Int(proc.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "解压核心包失败，ditto 退出码: \(proc.terminationStatus)"
            ])
        }

        // 确保目标目录已存在
        try fileManager.createDirectory(at: docURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: napcatDirURL, withIntermediateDirectories: true)

        // 寻找实际包含 napcat.mjs 的来源目录
        var sourceDir = stagingDir
        if !fileManager.fileExists(atPath: stagingDir.appendingPathComponent("napcat.mjs").path) {
            if fileManager.fileExists(atPath: stagingDir.appendingPathComponent("NapCat/napcat.mjs").path) {
                sourceDir = stagingDir.appendingPathComponent("NapCat")
            } else if let subdirs = try? fileManager.contentsOfDirectory(at: stagingDir, includingPropertiesForKeys: nil) {
                if let found = subdirs.first(where: { fileManager.fileExists(atPath: $0.appendingPathComponent("napcat.mjs").path) }) {
                    sourceDir = found
                }
            }
        }

        // 移动/同步文件到 docURL/napcat
        let items = try fileManager.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil)
        for item in items {
            let itemName = item.lastPathComponent
            let dest = napcatDirURL.appendingPathComponent(itemName)

            if ["config", "plugins"].contains(itemName) && fileManager.fileExists(atPath: dest.path) {
                // 保留已有用户自定义配置，仅补充新文件
                if let subItems = try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                    for sub in subItems {
                        let subDest = dest.appendingPathComponent(sub.lastPathComponent)
                        if !fileManager.fileExists(atPath: subDest.path) {
                            try? fileManager.copyItem(at: sub, to: subDest)
                        }
                    }
                }
            } else {
                if fileManager.fileExists(atPath: dest.path) {
                    try? fileManager.removeItem(at: dest)
                }
                try fileManager.copyItem(at: item, to: dest)
            }
        }
    }

    /// 写入双开兼容版 loadNapCat.js
    private func writeLoaderScript() throws {
        try fileManager.createDirectory(at: docURL, withIntermediateDirectories: true)
        let script = #"""
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const loadNapcat = process.argv.includes('--no-sandbox');
const package = require('/Applications/QQ.app/Contents/Resources/app/package.json');

if (loadNapcat) {
    (async () => {
        await import(pathToFileURL(path.join(__dirname, 'napcat/napcat.mjs')).href);
    })();
} else {
    const fs = require('node:fs');
    const baseAppDir = '/Applications/QQ.app/Contents/Resources/app';
    const versionsDir = path.resolve(__dirname, '../Library/Application Support/QQ/versions');
    const frameworkVersion = (appDir) => {
        try {
            const plist = fs.readFileSync(path.resolve(appDir, '../../Frameworks/QQNT.framework/Resources/Info.plist'), 'utf8');
            const m = plist.match(/<key>CFBundleVersion<\/key>\s*<string>([^<]+)<\/string>/);
            return m ? m[1] : null;
        } catch {
            return null;
        }
    };
    const candidates = [];
    const configPath = path.join(versionsDir, 'config.json');
    if (fs.existsSync(configPath)) {
        try {
            const { curVersion } = JSON.parse(fs.readFileSync(configPath, 'utf8'));
            if (curVersion) candidates.push(path.join(versionsDir, curVersion, 'QQUpdate.app/Contents/Resources/app'));
        } catch {}
    }
    candidates.push(baseAppDir);
    const runtime = process.versions.electron;
    const launcherAppDir = candidates.find((dir) => frameworkVersion(dir) === runtime) || baseAppDir;
    const launcherEntry = path.join(launcherAppDir, 'app_launcher/index.js');
    if (fs.existsSync(launcherEntry)) {
        require(launcherEntry);
    } else {
        require('/Applications/QQ.app/Contents/Resources/app/app_launcher/index.js');
    }
    setImmediate(() => {
        if (global.launcher && global.launcher.installPathPkgJson) {
            global.launcher.installPathPkgJson.main = ((version) => {
                if (version >= 29271) return "./application.asar/app_launcher/index.js";
                if (version >= 28060) return "./application/app_launcher/index.js";
                return "./app_launcher/index.js";
            })(package.buildVersion);
        }
    });
}
"""#
        try script.write(to: loaderURL, atomically: true, encoding: .utf8)
    }

    /// 保证基础配置文件存在 (onebot11.json, napcat.json, webui.json)
    private func ensureDefaultConfigs() throws {
        let configDir = napcatDirURL.appendingPathComponent("config", isDirectory: true)
        try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)

        let onebotURL = configDir.appendingPathComponent("onebot11.json")
        if !fileManager.fileExists(atPath: onebotURL.path) {
            let onebotContent = #"""
{
  "network": {
    "httpServers": [],
    "httpSseServers": [],
    "httpClients": [],
    "websocketServers": [
      {
        "name": "websocket-server",
        "enable": true,
        "host": "127.0.0.1",
        "port": 3001,
        "messagePostFormat": "array",
        "reportSelfMessage": false,
        "token": "",
        "enableForcePushEvent": true,
        "debug": false,
        "heartInterval": 30000
      }
    ],
    "websocketClients": [],
    "plugins": []
  },
  "musicSignUrl": "",
  "enableLocalFile2Url": false,
  "parseMultMsg": false,
  "imageDownloadProxy": "",
  "timeout": {
    "baseTimeout": 10000,
    "uploadSpeedKBps": 256,
    "downloadSpeedKBps": 256,
    "maxTimeout": 1800000
  }
}
"""#
            try onebotContent.write(to: onebotURL, atomically: true, encoding: .utf8)
        }

        let napcatJsonURL = configDir.appendingPathComponent("napcat.json")
        if !fileManager.fileExists(atPath: napcatJsonURL.path) {
            let napcatContent = #"""
{
  "fileLog": false,
  "consoleLog": true,
  "fileLogLevel": "debug",
  "consoleLogLevel": "info",
  "packetBackend": "auto",
  "packetServer": "",
  "o3HookMode": 1
}
"""#
            try napcatContent.write(to: napcatJsonURL, atomically: true, encoding: .utf8)
        }
    }

    /// 接管 QQ 入口
    private func patchQQEntryPoint() throws {
        guard fileManager.fileExists(atPath: qqPackageURL.path) else {
            throw NSError(domain: "PatchError", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "未找到 /Applications/QQ.app 中的 package.json 文件"
            ])
        }

        // 备份 package.json.bak
        if !fileManager.fileExists(atPath: qqPackageBakURL.path) {
            do {
                try fileManager.copyItem(at: qqPackageURL, to: qqPackageBakURL)
            } catch {
                // 如果权限不足，尝试通过特权命令备份
                _ = runPrivilegedShell(command: "cp '\(qqPackageURL.path)' '\(qqPackageBakURL.path)'")
            }
        }

        let data = try Data(contentsOf: qqPackageURL)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "PatchError", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "QQ package.json 格式解析错误"
            ])
        }

        // 计算相对路径
        let appDir = qqPackageURL.deletingLastPathComponent()
        let relPath = relativePath(from: appDir, to: loaderURL)
        json["main"] = relPath

        let newData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .withoutEscapingSlashes])

        // 尝试直接写入
        do {
            try newData.write(to: qqPackageURL)
        } catch {
            // 直接写入由于权限拒绝时，写临时文件后调用 AppleScript 系统提权
            let tmpFile = fileManager.temporaryDirectory.appendingPathComponent("qq_pkg_\(UUID().uuidString).json")
            try newData.write(to: tmpFile)
            let success = runPrivilegedShell(command: "cp '\(tmpFile.path)' '\(qqPackageURL.path)' && chmod 644 '\(qqPackageURL.path)'")
            try? fileManager.removeItem(at: tmpFile)

            if !success {
                throw NSError(domain: "PatchError", code: -3, userInfo: [
                    NSLocalizedDescriptionKey: "修改 QQ 入口需要管理员授权，授权取消或失败。"
                ])
            }
        }
    }

    /// 同步接管热更新版本
    @discardableResult
    private func patchHotUpdatePackages() throws -> Int {
        guard fileManager.fileExists(atPath: versionsURL.path),
              let versionDirs = try? fileManager.contentsOfDirectory(atPath: versionsURL.path) else {
            return 0
        }

        var count = 0
        for dir in versionDirs {
            let pkgURL = versionsURL.appendingPathComponent(dir)
                .appendingPathComponent("QQUpdate.app/Contents/Resources/app/package.json")
            guard fileManager.fileExists(atPath: pkgURL.path),
                  let data = try? Data(contentsOf: pkgURL),
                  var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let appDir = pkgURL.deletingLastPathComponent()
            let relPath = relativePath(from: appDir, to: loaderURL)
            if json["main"] as? String != relPath {
                json["main"] = relPath
                if let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .withoutEscapingSlashes]) {
                    try? newData.write(to: pkgURL)
                    count += 1
                }
            }
        }
        return count
    }

    /// 一键恢复官方原版 QQ
    public func restoreOriginalQQ() async -> (success: Bool, message: String) {
        self.isRestoring = true
        defer { self.isRestoring = false }

        guard fileManager.fileExists(atPath: qqPackageURL.path) else {
            return (false, "未检测到 /Applications/QQ.app")
        }

        var restoredCount = 0
        var mainRestored = false

        // 1. 恢复主 package.json
        if fileManager.fileExists(atPath: qqPackageBakURL.path) {
            do {
                if fileManager.isWritableFile(atPath: qqPackageURL.path) {
                    try? fileManager.removeItem(at: qqPackageURL)
                    try fileManager.copyItem(at: qqPackageBakURL, to: qqPackageURL)
                    mainRestored = true
                } else {
                    mainRestored = runPrivilegedShell(command: "cp '\(qqPackageBakURL.path)' '\(qqPackageURL.path)'")
                }
            } catch {
                mainRestored = runPrivilegedShell(command: "cp '\(qqPackageBakURL.path)' '\(qqPackageURL.path)'")
            }
        } else {
            // 没有备份，重置为标准入口
            if let data = try? Data(contentsOf: qqPackageURL),
               var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                json["main"] = "./application.asar/app_launcher/index.js"
                if let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .withoutEscapingSlashes]) {
                    do {
                        try newData.write(to: qqPackageURL)
                        mainRestored = true
                    } catch {
                        let tmpFile = fileManager.temporaryDirectory.appendingPathComponent("qq_pkg_restore.json")
                        try? newData.write(to: tmpFile)
                        mainRestored = runPrivilegedShell(command: "cp '\(tmpFile.path)' '\(qqPackageURL.path)'")
                        try? fileManager.removeItem(at: tmpFile)
                    }
                }
            }
        }

        // 2. 恢复热更新包
        if fileManager.fileExists(atPath: versionsURL.path),
           let versionDirs = try? fileManager.contentsOfDirectory(atPath: versionsURL.path) {
            for dir in versionDirs {
                let pkgURL = versionsURL.appendingPathComponent(dir)
                    .appendingPathComponent("QQUpdate.app/Contents/Resources/app/package.json")
                if fileManager.fileExists(atPath: pkgURL.path),
                   let data = try? Data(contentsOf: pkgURL),
                   var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                   let main = json["main"] as? String,
                   main.contains("loadNapCat.js") {
                    json["main"] = "./application.asar/app_launcher/index.js"
                    if let newData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .withoutEscapingSlashes]) {
                        try? newData.write(to: pkgURL)
                        restoredCount += 1
                    }
                }
            }
        }

        StorageService.shared.notifyEnvironmentChanged()

        if mainRestored {
            let msg = restoredCount > 0 ? "已成功恢复官方原版 QQ 启动入口（含 \(restoredCount) 个更新包）" : "已成功恢复官方原版 QQ 启动入口"
            self.restoreMessage = msg
            self.logger.success("NapCat-Installer", msg)
            return (true, msg)
        } else {
            let msg = "恢复官方 QQ 入口失败，请检查是否授权了管理员权限"
            self.restoreMessage = msg
            self.logger.error("NapCat-Installer", msg)
            return (false, msg)
        }
    }

    /// 执行提权 shell 命令
    @discardableResult
    private func runPrivilegedShell(command: String) -> Bool {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"
        var errorDict: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&errorDict)
            return errorDict == nil
        }
        return false
    }

    /// 计算相对路径
    private func relativePath(from sourceDir: URL, to targetFile: URL) -> String {
        let src = sourceDir.standardized.pathComponents
        let dst = targetFile.standardized.pathComponents
        var i = 0
        while i < src.count && i < dst.count && src[i] == dst[i] {
            i += 1
        }
        var parts = Array(repeating: "..", count: src.count - i)
        parts.append(contentsOf: dst[i...])
        return parts.joined(separator: "/")
    }
}

/// 下载进度代理
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double, Int64, Int64) -> Void

    init(onProgress: @escaping (Double, Int64, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        onProgress(progress, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 由 download(for: request) 自带返回
    }
}
