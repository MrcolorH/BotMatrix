import Foundation
import AppKit

public final class DynamicPluginManager: ObservableObject {
    public static let shared = DynamicPluginManager()

    @Published public private(set) var dynamicPlugins: [DynamicScriptPlugin] = []
    @Published public private(set) var lastReloadAt: Date? = nil
    @Published public private(set) var reloadMessage: String = ""

    public let pluginsDirectory: URL = {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let folder = home.appendingPathComponent(".tgbot").appendingPathComponent("plugins")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    public init() {
        reloadPlugins()
    }

    /// 热重载所有动态插件 (不重启 App、不断开长轮询连接，毫秒级即时生效)
    @discardableResult
    public func reloadPlugins() -> Int {
        let fileManager = FileManager.default
        guard let subdirs = try? fileManager.contentsOfDirectory(at: pluginsDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            self.dynamicPlugins = []
            return 0
        }

        var loaded: [DynamicScriptPlugin] = []

        for dir in subdirs {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                let manifestPath = dir.appendingPathComponent("plugin.json")
                if fileManager.fileExists(atPath: manifestPath.path),
                   let data = try? Data(contentsOf: manifestPath),
                   let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) {
                    let plugin = DynamicScriptPlugin(manifest: manifest, directory: dir)
                    loaded.append(plugin)
                }
            }
        }

        DispatchQueue.main.async {
            self.dynamicPlugins = loaded
            self.lastReloadAt = Date()
            self.reloadMessage = "✅ 成功热重载 \(loaded.count) 个扩展插件 (服务零停机)"
        }

        // 自动同步最新指令菜单到 Telegram 客户端
        Task { @MainActor in
            await BotController.shared.syncCommandsToTelegram()
        }

        LogService.shared.success("Plugin", "⚡️ 动态插件热重载完成，当前生效插件数: \(loaded.count)")
        return loaded.count
    }

    /// 在 Finder 中打开插件主目录
    public func openPluginsDirectory() {
        NSWorkspace.shared.open(pluginsDirectory)
    }

    /// 安装/写入一个新插件
    public func installPlugin(manifest: PluginManifest, entryContent: String) throws {
        let pluginDir = pluginsDirectory.appendingPathComponent(manifest.id)
        try FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)

        // 写入 plugin.json
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: pluginDir.appendingPathComponent("plugin.json"), options: .atomic)

        // 写入入口文件
        let entryFile = pluginDir.appendingPathComponent(manifest.entry)
        try entryContent.write(to: entryFile, atomically: true, encoding: .utf8)

        // 赋予可执行权限
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: entryFile.path)

        // 立即热重载！
        reloadPlugins()
    }

    /// 卸载插件
    public func uninstallPlugin(id: String) {
        let pluginDir = pluginsDirectory.appendingPathComponent(id)
        try? FileManager.default.removeItem(at: pluginDir)
        reloadPlugins()
    }

    /// 切换某个插件的开关并持久化回 plugin.json
    public func togglePlugin(id: String, enabled: Bool) {
        if let idx = dynamicPlugins.firstIndex(where: { $0.id == id }) {
            let plugin = dynamicPlugins[idx]
            plugin.isEnabled = enabled
            var m = plugin.manifest
            m.isEnabled = enabled

            let manifestPath = plugin.pluginDirectory.appendingPathComponent("plugin.json")
            if let data = try? JSONEncoder().encode(m) {
                try? data.write(to: manifestPath)
            }
        }
    }
}
