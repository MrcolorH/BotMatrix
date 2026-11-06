import Foundation

public struct PersonaCard: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var prompt: String

    public init(id: String = UUID().uuidString, name: String, prompt: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }
}

public struct AppConfig: Codable {
    public var botToken: String
    public var twitterDownApiKey: String
    public var autoStart: Bool
    public var twitterModuleEnabled: Bool
    public var agyModuleEnabled: Bool
    public var adminUserIds: String
    public var masterAdminIds: String
    public var agyCliPath: String
    public var autoFoldMinutes: Int
    public var agyPersona: String
    public var agyEffort: String
    public var personaCards: [PersonaCard]?
    public var activePersonaId: String?

    // 🐧 QQ 账号与双端模块独立开关配置
    public var qqBotEnabled: Bool
    public var qqWsUrl: String
    public var qqAdminIds: String
    public var qqMasterAdminIds: String
    public var qqNicknames: [String: String]?
    public var qqManageDaemon: Bool
    public var qqLaunchCommand: String
    public var qqAccount: String
    public var qqPassword: String
    public var qqAutoQuickLogin: Bool

    public var videoEnabledTG: Bool
    public var videoEnabledQQ: Bool
    public var agyEnabledTG: Bool
    public var agyEnabledQQ: Bool
    public var morningNewsEnabledTG: Bool
    public var morningNewsEnabledQQ: Bool

    // 🔒 独立会话记忆与多租户隔离配置
    public var sessionMaxTurns: Int
    public var sessionTimeoutMinutes: Int

    public static var defaultAgyCliPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/agy",
            "\(home)/.gemini/bin/agy",
            "/usr/local/bin/agy",
            "/opt/homebrew/bin/agy"
        ]
        for p in candidates where FileManager.default.isExecutableFile(atPath: p) {
            return p
        }
        return "\(home)/.local/bin/agy"
    }

    public init(
        botToken: String = "",
        twitterDownApiKey: String = "",
        autoStart: Bool = false,
        twitterModuleEnabled: Bool = true,
        agyModuleEnabled: Bool = true,
        adminUserIds: String = "",
        masterAdminIds: String = "",
        agyCliPath: String = AppConfig.defaultAgyCliPath,
        autoFoldMinutes: Int = 3,
        agyPersona: String = "你是一个贴心、聪明且幽默的私人 AI 助理。回答生动自然，直接切中要害，避免冗长套话。",
        agyEffort: String = "low",
        personaCards: [PersonaCard]? = nil,
        activePersonaId: String? = nil,
        qqBotEnabled: Bool = false,
        qqWsUrl: String = "ws://127.0.0.1:3001",
        qqAdminIds: String = "",
        qqMasterAdminIds: String = "",
        qqNicknames: [String: String]? = nil,
        qqManageDaemon: Bool = true,
        qqLaunchCommand: String = "/Applications/QQ.app/Contents/MacOS/QQ",
        qqAccount: String = "",
        qqPassword: String = "",
        qqAutoQuickLogin: Bool = true,
        videoEnabledTG: Bool = true,
        videoEnabledQQ: Bool = true,
        agyEnabledTG: Bool = true,
        agyEnabledQQ: Bool = true,
        morningNewsEnabledTG: Bool = true,
        morningNewsEnabledQQ: Bool = false,
        sessionMaxTurns: Int = 10,
        sessionTimeoutMinutes: Int = 30
    ) {
        self.botToken = botToken
        self.twitterDownApiKey = twitterDownApiKey
        self.autoStart = autoStart
        self.twitterModuleEnabled = twitterModuleEnabled
        self.agyModuleEnabled = agyModuleEnabled
        self.adminUserIds = adminUserIds
        self.masterAdminIds = masterAdminIds
        self.agyCliPath = agyCliPath
        self.autoFoldMinutes = autoFoldMinutes
        self.agyPersona = agyPersona
        self.agyEffort = agyEffort
        self.personaCards = personaCards
        self.activePersonaId = activePersonaId
        self.qqBotEnabled = qqBotEnabled
        self.qqWsUrl = qqWsUrl
        self.qqAdminIds = qqAdminIds
        self.qqMasterAdminIds = qqMasterAdminIds
        self.qqNicknames = qqNicknames
        self.qqManageDaemon = qqManageDaemon
        self.qqLaunchCommand = qqLaunchCommand
        self.qqAccount = qqAccount
        self.qqPassword = qqPassword
        self.qqAutoQuickLogin = qqAutoQuickLogin
        self.videoEnabledTG = videoEnabledTG
        self.videoEnabledQQ = videoEnabledQQ
        self.agyEnabledTG = agyEnabledTG
        self.agyEnabledQQ = agyEnabledQQ
        self.morningNewsEnabledTG = morningNewsEnabledTG
        self.morningNewsEnabledQQ = morningNewsEnabledQQ
        self.sessionMaxTurns = sessionMaxTurns
        self.sessionTimeoutMinutes = sessionTimeoutMinutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.botToken = try container.decodeIfPresent(String.self, forKey: .botToken) ?? ""
        self.twitterDownApiKey = try container.decodeIfPresent(String.self, forKey: .twitterDownApiKey) ?? ""
        self.autoStart = try container.decodeIfPresent(Bool.self, forKey: .autoStart) ?? false
        self.twitterModuleEnabled = try container.decodeIfPresent(Bool.self, forKey: .twitterModuleEnabled) ?? true
        self.agyModuleEnabled = try container.decodeIfPresent(Bool.self, forKey: .agyModuleEnabled) ?? true
        self.adminUserIds = try container.decodeIfPresent(String.self, forKey: .adminUserIds) ?? ""
        self.masterAdminIds = try container.decodeIfPresent(String.self, forKey: .masterAdminIds) ?? ""
        self.agyCliPath = try container.decodeIfPresent(String.self, forKey: .agyCliPath) ?? AppConfig.defaultAgyCliPath
        self.autoFoldMinutes = try container.decodeIfPresent(Int.self, forKey: .autoFoldMinutes) ?? 3
        self.agyPersona = try container.decodeIfPresent(String.self, forKey: .agyPersona) ?? "你是一个贴心、聪明且幽默的私人 AI 助理。回答生动自然，直接切中要害，避免冗长套话。"
        self.agyEffort = try container.decodeIfPresent(String.self, forKey: .agyEffort) ?? "low"
        self.personaCards = try container.decodeIfPresent([PersonaCard].self, forKey: .personaCards)
        self.activePersonaId = try container.decodeIfPresent(String.self, forKey: .activePersonaId)

        // 增量字段无损容错解码
        self.qqBotEnabled = try container.decodeIfPresent(Bool.self, forKey: .qqBotEnabled) ?? false
        self.qqWsUrl = try container.decodeIfPresent(String.self, forKey: .qqWsUrl) ?? "ws://127.0.0.1:3001"
        self.qqAdminIds = try container.decodeIfPresent(String.self, forKey: .qqAdminIds) ?? ""
        self.qqMasterAdminIds = try container.decodeIfPresent(String.self, forKey: .qqMasterAdminIds) ?? ""
        self.qqNicknames = try container.decodeIfPresent([String: String].self, forKey: .qqNicknames)
        self.qqManageDaemon = try container.decodeIfPresent(Bool.self, forKey: .qqManageDaemon) ?? true
        self.qqLaunchCommand = try container.decodeIfPresent(String.self, forKey: .qqLaunchCommand) ?? "/Applications/QQ.app/Contents/MacOS/QQ"
        self.qqAccount = try container.decodeIfPresent(String.self, forKey: .qqAccount) ?? ""
        self.qqPassword = try container.decodeIfPresent(String.self, forKey: .qqPassword) ?? ""
        self.qqAutoQuickLogin = try container.decodeIfPresent(Bool.self, forKey: .qqAutoQuickLogin) ?? true

        self.videoEnabledTG = try container.decodeIfPresent(Bool.self, forKey: .videoEnabledTG) ?? self.twitterModuleEnabled
        self.videoEnabledQQ = try container.decodeIfPresent(Bool.self, forKey: .videoEnabledQQ) ?? true
        self.agyEnabledTG = try container.decodeIfPresent(Bool.self, forKey: .agyEnabledTG) ?? self.agyModuleEnabled
        self.agyEnabledQQ = try container.decodeIfPresent(Bool.self, forKey: .agyEnabledQQ) ?? true
        self.morningNewsEnabledTG = try container.decodeIfPresent(Bool.self, forKey: .morningNewsEnabledTG) ?? true
        self.morningNewsEnabledQQ = try container.decodeIfPresent(Bool.self, forKey: .morningNewsEnabledQQ) ?? false

        self.sessionMaxTurns = try container.decodeIfPresent(Int.self, forKey: .sessionMaxTurns) ?? 10
        self.sessionTimeoutMinutes = try container.decodeIfPresent(Int.self, forKey: .sessionTimeoutMinutes) ?? 30
    }
}

public final class StorageService: ObservableObject {
    public static let shared = StorageService()
    public static var defaultAgyCliPath: String { AppConfig.defaultAgyCliPath }

    private let configUrl: URL = {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let folder = home.appendingPathComponent(".tgbot")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("config.json")
    }()

    private let defaults = UserDefaults.standard

    @Published public var botToken: String { didSet { persist() } }
    @Published public var twitterDownApiKey: String { didSet { persist() } }
    @Published public var autoStart: Bool { didSet { persist() } }
    @Published public var twitterModuleEnabled: Bool { didSet { persist() } }
    @Published public var agyModuleEnabled: Bool { didSet { persist() } }
    @Published public var adminUserIds: String { didSet { persist() } }
    @Published public var masterAdminIds: String { didSet { persist() } }
    @Published public var agyCliPath: String { didSet { persist() } }
    @Published public var autoFoldMinutes: Int { didSet { persist() } }
    @Published public var agyPersona: String { didSet { persist() } }
    @Published public var agyEffort: String { didSet { persist() } }
    @Published public var personaCards: [PersonaCard] { didSet { persist() } }
    @Published public var activePersonaId: String {
        didSet {
            if let card = personaCards.first(where: { $0.id == activePersonaId }) {
                agyPersona = card.prompt
            }
            persist()
        }
    }

    // 🐧 QQ 账号与独立开关
    @Published public var qqBotEnabled: Bool { didSet { persist() } }
    @Published public var qqWsUrl: String { didSet { persist() } }
    @Published public var qqAdminIds: String { didSet { persist() } }
    @Published public var qqMasterAdminIds: String { didSet { persist() } }
    @Published public var qqNicknames: [String: String] { didSet { persist() } }
    @Published public var qqManageDaemon: Bool { didSet { persist() } }
    @Published public var qqLaunchCommand: String { didSet { persist() } }
    @Published public var qqAccount: String { didSet { persist() } }
    @Published public var qqPassword: String { didSet { persist() } }
    @Published public var qqAutoQuickLogin: Bool { didSet { persist() } }

    public var isMacQQInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Applications/QQ.app")
    }

    /// 检查 NapCat 核心框架与引导脚本是否部署就绪
    public var isNapCatFilesReady: Bool {
        let home = NSHomeDirectory()
        let docLoader = home + "/Library/Containers/com.tencent.qq/Data/Documents/loadNapCat.js"
        let docMjs = home + "/Library/Containers/com.tencent.qq/Data/Documents/napcat/napcat.mjs"
        let customLoader = home + "/.tgbot/napcat/loadNapCat.js"
        let customMjs = home + "/.tgbot/napcat/napcat.mjs"
        return (FileManager.default.fileExists(atPath: docLoader) && FileManager.default.fileExists(atPath: docMjs)) ||
               (FileManager.default.fileExists(atPath: customLoader) && FileManager.default.fileExists(atPath: customMjs))
    }

    /// 检查 QQ 的 package.json 是否已成功指向 NapCat 引导入口
    public var isQQPatchedForNapCat: Bool {
        let packagePath = "/Applications/QQ.app/Contents/Resources/app/package.json"
        guard FileManager.default.fileExists(atPath: packagePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: packagePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let main = json["main"] as? String else {
            return false
        }
        return main.contains("loadNapCat.js")
    }

    /// 综合判定 NapCat 是否已完整安装且接管就绪
    public var isNapCatInstalled: Bool {
        isNapCatFilesReady && isQQPatchedForNapCat
    }

    /// 手动广播环境变动通知
    public func notifyEnvironmentChanged() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    @Published public var videoEnabledTG: Bool {
        didSet {
            twitterModuleEnabled = videoEnabledTG
            persist()
        }
    }
    @Published public var videoEnabledQQ: Bool { didSet { persist() } }
    @Published public var agyEnabledTG: Bool {
        didSet {
            agyModuleEnabled = agyEnabledTG
            persist()
        }
    }
    @Published public var agyEnabledQQ: Bool { didSet { persist() } }
    @Published public var morningNewsEnabledTG: Bool { didSet { persist() } }
    @Published public var morningNewsEnabledQQ: Bool { didSet { persist() } }

    // 隔离记忆配置
    @Published public var sessionMaxTurns: Int { didSet { persist() } }
    @Published public var sessionTimeoutMinutes: Int { didSet { persist() } }

    public init() {
        var initialConfig = AppConfig()
        var loadedFromFile = false

        if FileManager.default.fileExists(atPath: configUrl.path),
           let data = try? Data(contentsOf: configUrl),
           let fileConfig = try? JSONDecoder().decode(AppConfig.self, from: data) {
            initialConfig = fileConfig
            loadedFromFile = true
        }

        // 兼容从 UserDefaults 迁移未同步项
        if !loadedFromFile || initialConfig.botToken.isEmpty {
            if let tokenObj = defaults.object(forKey: "tgbot_bot_token") {
                initialConfig.botToken = "\(tokenObj)".trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let adminObj = defaults.object(forKey: "tgbot_admin_user_ids") {
                initialConfig.adminUserIds = "\(adminObj)".trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let foldObj = defaults.object(forKey: "tgbot_auto_fold_minutes") as? Int {
                initialConfig.autoFoldMinutes = foldObj
            }
            if let agyObj = defaults.object(forKey: "tgbot_agy_cli_path") as? String, !agyObj.isEmpty {
                initialConfig.agyCliPath = agyObj
            }
        }

        // 默认检测可用 agy
        if !FileManager.default.isExecutableFile(atPath: initialConfig.agyCliPath) {
            let userHome = FileManager.default.homeDirectoryForCurrentUser.path
            let possibleAgy = [
                "\(userHome)/.local/bin/agy",
                "\(userHome)/.gemini/bin/agy",
                "/usr/local/bin/agy",
                "/opt/homebrew/bin/agy"
            ]
            for p in possibleAgy where FileManager.default.isExecutableFile(atPath: p) {
                initialConfig.agyCliPath = p
                break
            }
        }

        self.botToken = initialConfig.botToken
        self.twitterDownApiKey = initialConfig.twitterDownApiKey
        self.autoStart = initialConfig.autoStart
        self.twitterModuleEnabled = initialConfig.twitterModuleEnabled
        self.agyModuleEnabled = initialConfig.agyModuleEnabled
        self.adminUserIds = initialConfig.adminUserIds
        self.masterAdminIds = initialConfig.masterAdminIds
        self.agyCliPath = initialConfig.agyCliPath
        self.autoFoldMinutes = initialConfig.autoFoldMinutes
        self.agyPersona = initialConfig.agyPersona.isEmpty ? "你是一个贴心、聪明且幽默的私人 AI 助理。回答生动自然，直接切中要害，避免冗长套话。" : initialConfig.agyPersona
        self.agyEffort = initialConfig.agyEffort.isEmpty ? "low" : initialConfig.agyEffort

        // 🐧 QQ 与双端开关初始化
        self.qqBotEnabled = initialConfig.qqBotEnabled
        self.qqWsUrl = initialConfig.qqWsUrl.isEmpty ? "ws://127.0.0.1:3001" : initialConfig.qqWsUrl
        self.qqAdminIds = initialConfig.qqAdminIds
        self.qqMasterAdminIds = initialConfig.qqMasterAdminIds
        self.qqNicknames = initialConfig.qqNicknames ?? [:]
        self.qqManageDaemon = initialConfig.qqManageDaemon
        self.qqLaunchCommand = initialConfig.qqLaunchCommand.isEmpty ? "/Applications/QQ.app/Contents/MacOS/QQ" : initialConfig.qqLaunchCommand
        self.qqAccount = initialConfig.qqAccount
        self.qqPassword = initialConfig.qqPassword
        self.qqAutoQuickLogin = initialConfig.qqAutoQuickLogin
        self.videoEnabledTG = initialConfig.videoEnabledTG
        self.videoEnabledQQ = initialConfig.videoEnabledQQ
        self.agyEnabledTG = initialConfig.agyEnabledTG
        self.agyEnabledQQ = initialConfig.agyEnabledQQ
        self.morningNewsEnabledTG = initialConfig.morningNewsEnabledTG
        self.morningNewsEnabledQQ = initialConfig.morningNewsEnabledQQ
        self.sessionMaxTurns = initialConfig.sessionMaxTurns
        self.sessionTimeoutMinutes = initialConfig.sessionTimeoutMinutes

        // 角色卡初始化与无损迁移
        if let loadedCards = initialConfig.personaCards, !loadedCards.isEmpty {
            self.personaCards = loadedCards
            let activeId = initialConfig.activePersonaId ?? ""
            if loadedCards.contains(where: { $0.id == activeId }) {
                self.activePersonaId = activeId
            } else {
                self.activePersonaId = loadedCards.first?.id ?? ""
            }
        } else {
            let defaultPrompt = initialConfig.agyPersona.isEmpty ? "你是一个贴心、聪明且幽默的私人 AI 助理。回答生动自然，直接切中要害，避免冗长套话。" : initialConfig.agyPersona
            let defaultCard = PersonaCard(name: "默认助理", prompt: defaultPrompt)
            self.personaCards = [defaultCard]
            self.activePersonaId = defaultCard.id
        }

        persist()

        if self.botToken.isEmpty {
            self.tryImportFromEnvFile()
        }
    }

    public func persist() {
        let currentPrompt = activePersonaCard.prompt
        if !currentPrompt.isEmpty && agyPersona != currentPrompt {
            agyPersona = currentPrompt
        }

        let config = AppConfig(
            botToken: botToken,
            twitterDownApiKey: twitterDownApiKey,
            autoStart: autoStart,
            twitterModuleEnabled: twitterModuleEnabled,
            agyModuleEnabled: agyModuleEnabled,
            adminUserIds: adminUserIds,
            masterAdminIds: masterAdminIds,
            agyCliPath: agyCliPath,
            autoFoldMinutes: autoFoldMinutes,
            agyPersona: agyPersona,
            agyEffort: agyEffort,
            personaCards: personaCards,
            activePersonaId: activePersonaId,
            qqBotEnabled: qqBotEnabled,
            qqWsUrl: qqWsUrl,
            qqAdminIds: qqAdminIds,
            qqMasterAdminIds: qqMasterAdminIds,
            qqNicknames: qqNicknames,
            qqManageDaemon: qqManageDaemon,
            qqLaunchCommand: qqLaunchCommand,
            qqAccount: qqAccount,
            qqPassword: qqPassword,
            qqAutoQuickLogin: qqAutoQuickLogin,
            videoEnabledTG: videoEnabledTG,
            videoEnabledQQ: videoEnabledQQ,
            agyEnabledTG: agyEnabledTG,
            agyEnabledQQ: agyEnabledQQ,
            morningNewsEnabledTG: morningNewsEnabledTG,
            morningNewsEnabledQQ: morningNewsEnabledQQ,
            sessionMaxTurns: sessionMaxTurns,
            sessionTimeoutMinutes: sessionTimeoutMinutes
        )

        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configUrl, options: .atomic)
        }

        defaults.set(botToken, forKey: "tgbot_bot_token")
        defaults.set(twitterDownApiKey, forKey: "tgbot_twitterdown_api_key")
        defaults.set(autoStart, forKey: "tgbot_auto_start")
        defaults.set(twitterModuleEnabled, forKey: "tgbot_module_twitter_enabled")
        defaults.set(agyModuleEnabled, forKey: "tgbot_module_agy_enabled")
        defaults.set(adminUserIds, forKey: "tgbot_admin_user_ids")
        defaults.set(masterAdminIds, forKey: "tgbot_master_admin_ids")
        defaults.set(agyCliPath, forKey: "tgbot_agy_cli_path")
        defaults.set(autoFoldMinutes, forKey: "tgbot_auto_fold_minutes")
        defaults.set(agyPersona, forKey: "tgbot_agy_persona")
        defaults.set(agyEffort, forKey: "tgbot_agy_effort")
        defaults.set(qqBotEnabled, forKey: "tgbot_qq_bot_enabled")
        defaults.set(qqWsUrl, forKey: "tgbot_qq_ws_url")
        defaults.set(qqAdminIds, forKey: "tgbot_qq_admin_ids")
        defaults.set(qqMasterAdminIds, forKey: "tgbot_qq_master_admin_ids")
        defaults.set(videoEnabledTG, forKey: "tgbot_video_enabled_tg")
        defaults.set(videoEnabledQQ, forKey: "tgbot_video_enabled_qq")
        defaults.set(agyEnabledTG, forKey: "tgbot_agy_enabled_tg")
        defaults.set(agyEnabledQQ, forKey: "tgbot_agy_enabled_qq")
    }

    // MARK: - 角色卡管理

    public var activePersonaCard: PersonaCard {
        if let card = personaCards.first(where: { $0.id == activePersonaId }) {
            return card
        }
        if let first = personaCards.first {
            return first
        }
        return PersonaCard(id: "default", name: "默认助理", prompt: agyPersona)
    }

    @discardableResult
    public func addPersonaCard(name: String, prompt: String, activate: Bool = false) -> PersonaCard {
        let card = PersonaCard(name: name, prompt: prompt)
        personaCards.append(card)
        if activate || personaCards.count == 1 {
            activePersonaId = card.id
            agyPersona = card.prompt
        }
        persist()
        return card
    }

    public func updatePersonaCard(id: String, name: String, prompt: String) {
        guard let idx = personaCards.firstIndex(where: { $0.id == id }) else { return }
        personaCards[idx].name = name
        personaCards[idx].prompt = prompt
        if activePersonaId == id {
            agyPersona = prompt
        }
        persist()
    }

    public func deletePersonaCard(id: String) {
        guard personaCards.count > 1 else { return }
        personaCards.removeAll { $0.id == id }
        if activePersonaId == id {
            if let first = personaCards.first {
                activePersonaId = first.id
                agyPersona = first.prompt
            }
        }
        persist()
    }

    public func setActivePersona(id: String) {
        guard let card = personaCards.first(where: { $0.id == id }) else { return }
        activePersonaId = id
        agyPersona = card.prompt
        persist()
    }

    // MARK: - Telegram 管理员鉴权

    /// 👑 TG 系统所有者 (拥有 Mac 宿主真机读写与运维权限)
    public var masterAdminList: [Int64] {
        let trimmed = masterAdminIds.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        return trimmed.components(separatedBy: CharacterSet(charactersIn: ",;， \n\t"))
            .compactMap { Int64($0.trimmingCharacters(in: .whitespaces)) }
    }

    public func isMasterAdmin(userId: Int64) -> Bool {
        return masterAdminList.contains(userId)
    }

    public func addMasterAdmin(id: Int64) {
        var current = masterAdminList
        if !current.contains(id) {
            current.append(id)
            masterAdminIds = current.map { "\($0)" }.joined(separator: ", ")
        }
    }

    public func removeMasterAdmin(id: Int64) {
        var current = masterAdminList
        current.removeAll { $0 == id }
        masterAdminIds = current.map { "\($0)" }.joined(separator: ", ")
    }

    /// 🛡️ TG 普通白名单 (沙箱安全模式)
    public var adminList: [Int64] {
        let trimmed = adminUserIds.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        return trimmed.components(separatedBy: CharacterSet(charactersIn: ",;， \n\t"))
            .compactMap { Int64($0.trimmingCharacters(in: .whitespaces)) }
    }

    public func isAdmin(userId: Int64) -> Bool {
        return isMasterAdmin(userId: userId) || adminList.contains(userId)
    }

    public func addAdmin(id: Int64) {
        var current = adminList
        if !current.contains(id) {
            current.append(id)
            adminUserIds = current.map { "\($0)" }.joined(separator: ", ")
        }
    }

    public func removeAdmin(id: Int64) {
        var current = adminList
        current.removeAll { $0 == id }
        adminUserIds = current.map { "\($0)" }.joined(separator: ", ")
    }

    // MARK: - 🐧 QQ 鉴权 (分级权限：系统所有者 vs 沙箱白名单)

    /// 👑 QQ 系统所有者 (唯一宿主 - 拥有 Mac 宿主真机最高读写与运维权限)
    public var qqMasterAdminList: [Int64] {
        let trimmed = qqMasterAdminIds.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        if let first = trimmed.components(separatedBy: CharacterSet(charactersIn: ",;， \n\t"))
            .compactMap({ Int64($0.trimmingCharacters(in: .whitespaces)) })
            .first {
            return [first]
        }
        return []
    }

    public func isQQMasterAdmin(userId: Int64) -> Bool {
        return qqMasterAdminList.contains(userId)
    }

    /// 设置唯一系统所有者 (主人仅限一位)
    public func addQQMasterAdmin(id: Int64) {
        qqMasterAdminIds = "\(id)"
    }

    /// 移除系统所有者
    public func removeQQMasterAdmin(id: Int64) {
        qqMasterAdminIds = ""
    }

    /// 获取缓存的 QQ 昵称
    public func getQQNickname(userId: Int64) -> String? {
        return qqNicknames[String(userId)]
    }

    /// 缓存或更新 QQ 昵称
    public func setQQNickname(userId: Int64, nickname: String) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        var current = qqNicknames
        if trimmed.isEmpty {
            current.removeValue(forKey: String(userId))
        } else {
            current[String(userId)] = trimmed
        }
        qqNicknames = current
    }

    /// 🛡️ QQ 普通白名单 (沙箱安全隔离模式 - 绝不允许触碰本机任何文件)
    public var qqAdminList: [Int64] {
        let trimmed = qqAdminIds.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        return trimmed.components(separatedBy: CharacterSet(charactersIn: ",;， \n\t"))
            .compactMap { Int64($0.trimmingCharacters(in: .whitespaces)) }
    }

    public func isQQAdmin(userId: Int64) -> Bool {
        // 系统所有者自动拥有访问权限
        if isQQMasterAdmin(userId: userId) { return true }
        // 如果白名单为空，则默认不放行陌生人保护算力
        if qqAdminList.isEmpty { return false }
        return qqAdminList.contains(userId)
    }

    public func addQQAdmin(id: Int64) {
        var current = qqAdminList
        if !current.contains(id) {
            current.append(id)
            qqAdminIds = current.map { "\($0)" }.joined(separator: ", ")
        }
    }

    public func removeQQAdmin(id: Int64) {
        var current = qqAdminList
        current.removeAll { $0 == id }
        qqAdminIds = current.map { "\($0)" }.joined(separator: ", ")
    }

    public func tryImportFromEnvFile() {
        let possiblePaths = [
            ".env",
            "../.env",
            NSHomeDirectory() + "/.env"
        ]

        for path in possiblePaths {
            let fullPath = URL(fileURLWithPath: path).standardized.path
            if FileManager.default.fileExists(atPath: fullPath) {
                if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                    for line in content.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("#") || !trimmed.contains("=") { continue }
                        let parts = trimmed.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\"' \t")) }
                        if parts.count == 2 {
                            if parts[0] == "TELEGRAM_BOT_TOKEN" && self.botToken.isEmpty {
                                self.botToken = parts[1]
                            } else if parts[0] == "TWITTERDOWN_API_KEY" && self.twitterDownApiKey.isEmpty {
                                self.twitterDownApiKey = parts[1]
                            }
                        }
                    }
                }
            }
        }
    }
}
