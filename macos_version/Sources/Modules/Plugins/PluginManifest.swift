import Foundation

/// 插件类型
public enum PluginType: String, Codable {
    case script = "script"           // 执行外部脚本 (Python, Shell 等)
    case agyPrompt = "agy_prompt"    // 基于反重力 CLI 的 Prompt 智能体
    case system = "system"           // 内置原生系统模块
}

/// 插件元信息配置 (plugin.json)
public struct PluginManifest: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var version: String
    public var description: String
    public var author: String
    public var commands: [String]
    public var entry: String
    public var type: PluginType
    public var isEnabled: Bool
    public var iconName: String?

    public init(
        id: String,
        name: String,
        version: String = "1.0.0",
        description: String,
        author: String = "Community",
        commands: [String] = [],
        entry: String = "main.py",
        type: PluginType = .script,
        isEnabled: Bool = true,
        iconName: String? = "puzzlepiece.extension"
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.commands = commands
        self.entry = entry
        self.type = type
        self.isEnabled = isEnabled
        self.iconName = iconName
    }
}
