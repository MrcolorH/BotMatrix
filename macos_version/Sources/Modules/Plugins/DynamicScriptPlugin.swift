import Foundation

/// 动态热加载插件的包装实现，符合 BotServiceModule 协议
public final class DynamicScriptPlugin: BotServiceModule, ObservableObject {
    public var id: String { manifest.id }
    public var name: String { manifest.name }
    public var description: String { manifest.description }
    public var iconName: String { manifest.iconName ?? "puzzlepiece.extension" }

    @Published public var isEnabled: Bool

    public var commands: [BotCommand] {
        return manifest.commands.map { cmd in
            BotCommand(command: cmd, description: "\(manifest.name) 功能指令")
        }
    }

    public let manifest: PluginManifest
    public let pluginDirectory: URL

    public init(manifest: PluginManifest, directory: URL) {
        self.manifest = manifest
        self.pluginDirectory = directory
        self.isEnabled = manifest.isEnabled
    }

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

        let normalizedCommands = manifest.commands.map { $0.lowercased().replacingOccurrences(of: "/", with: "") }
        return normalizedCommands.contains(cmd)
    }

    public func handleMessage(message: TelegramMessage, client: TelegramClient, logger: LogService) async throws {
        guard let rawText = message.text,
              let (cmd, args) = extractCommand(from: rawText) else { return }

        let chatId = message.chat.id
        let userId = message.from?.id ?? chatId
        let username = message.from?.username ?? ""

        logger.info("Plugin", "插件 [\(name)] 响应指令: /\(cmd)")
        _ = try? await client.sendChatAction(chatId: chatId, action: "typing")

        switch manifest.type {
        case .script:
            let output = try await executeScript(cmd: cmd, args: args, userId: userId, chatId: chatId, username: username, rawText: rawText)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                _ = try? await client.sendMessage(chatId: chatId, text: trimmed, parseMode: nil)
            }
        case .agyPrompt:
            let templatePath = pluginDirectory.appendingPathComponent(manifest.entry).path
            var promptTemplate = "你是一个专业助理，请回答用户问题：\(args)"
            if FileManager.default.fileExists(atPath: templatePath),
               let content = try? String(contentsOfFile: templatePath, encoding: .utf8) {
                promptTemplate = content
            }
            let prompt = promptTemplate.replacingOccurrences(of: "{ARGS}", with: args)
                                       .replacingOccurrences(of: "{USER_ID}", with: "\(userId)")
                                       .replacingOccurrences(of: "{CMD}", with: cmd)
            let output = try await AgyService.shared.executePrompt(prompt)
            _ = try? await client.sendMessage(chatId: chatId, text: output, parseMode: nil)
        case .system:
            break
        }
    }

    private func executeScript(
        cmd: String,
        args: String,
        userId: Int64,
        chatId: Int64,
        username: String,
        rawText: String
    ) async throws -> String {
        let entryFile = pluginDirectory.appendingPathComponent(manifest.entry).path
        guard FileManager.default.fileExists(atPath: entryFile) else {
            throw NSError(domain: "PluginError", code: 404, userInfo: [NSLocalizedDescriptionKey: "入口文件不存在: \(manifest.entry)"])
        }
        let currentDirURL = self.pluginDirectory

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                var env = ProcessInfo.processInfo.environment
                env["TGBOT_CMD"] = cmd
                env["TGBOT_ARGS"] = args
                env["TGBOT_USER_ID"] = "\(userId)"
                env["TGBOT_CHAT_ID"] = "\(chatId)"
                env["TGBOT_USERNAME"] = username
                env["TGBOT_TEXT"] = rawText
                let userHome = NSHomeDirectory()
                env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(userHome)/.local/bin:\(userHome)/.gemini/bin"
                process.environment = env
                process.currentDirectoryURL = currentDirURL

                if entryFile.hasSuffix(".py") {
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                    process.arguments = [entryFile, args]
                } else if entryFile.hasSuffix(".sh") {
                    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    process.arguments = [entryFile, args]
                } else {
                    process.executableURL = URL(fileURLWithPath: entryFile)
                    process.arguments = [args]
                }

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()

                    let timeoutItem = DispatchWorkItem {
                        if process.isRunning { process.terminate() }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutItem)

                    process.waitUntilExit()
                    timeoutItem.cancel()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func canHandleCallback(query: TelegramCallbackQuery) -> Bool {
        return false
    }

    public func handleCallbackQuery(query: TelegramCallbackQuery, client: TelegramClient, logger: LogService) async throws {}
}
