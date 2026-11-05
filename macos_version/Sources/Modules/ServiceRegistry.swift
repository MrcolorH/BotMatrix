import Foundation
import Combine

public final class ServiceRegistry: ObservableObject {
    public static let shared = ServiceRegistry()

    @Published public private(set) var modules: [BotServiceModule] = []
    public let videoModule: VideoModule
    public let agyModule: AgyModule
    public let morningNewsModule: MorningNewsModule
    public let pluginManager: DynamicPluginManager

    private var cancellables = Set<AnyCancellable>()

    public init() {
        let storage = StorageService.shared
        let vm = VideoModule(storage: storage)
        let am = AgyModule(storage: storage)
        let nm = MorningNewsModule()
        let pm = DynamicPluginManager.shared

        self.videoModule = vm
        self.agyModule = am
        self.morningNewsModule = nm
        self.pluginManager = pm
        self.modules = [vm, nm, am]

        // 监听动态插件变化，保持响应式更新
        pm.$dynamicPlugins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// 所有激活模块总数 (含原生核心模块 + 动态已加载插件)
    public var enabledCount: Int {
        let coreCount = modules.filter { $0.isEnabled }.count
        let dynamicCount = pluginManager.dynamicPlugins.filter { $0.isEnabled }.count
        return coreCount + dynamicCount
    }

    /// 所有活跃插件列表
    public var allActiveModules: [BotServiceModule] {
        var list: [BotServiceModule] = modules.filter { $0.isEnabled }
        list.append(contentsOf: pluginManager.dynamicPlugins.filter { $0.isEnabled })
        return list
    }

    public func dispatchMessage(
        message: TelegramMessage,
        client: TelegramClient,
        logger: LogService
    ) async {
        // 1. 优先原生核心模块派发 (晨报指令、视频解析、反重力AI)
        for module in modules where module.isEnabled {
            if module.canHandle(message: message) {
                do {
                    try await module.handleMessage(message: message, client: client, logger: logger)
                    return
                } catch {
                    logger.error(module.name, "处理消息异常: \(error.localizedDescription)")
                    return
                }
            }
        }

        // 2. 派发给动态热加载插件
        for dynamicPlugin in pluginManager.dynamicPlugins where dynamicPlugin.isEnabled {
            if dynamicPlugin.canHandle(message: message) {
                do {
                    try await dynamicPlugin.handleMessage(message: message, client: client, logger: logger)
                    return
                } catch {
                    logger.error(dynamicPlugin.name, "动态插件执行异常: \(error.localizedDescription)")
                    return
                }
            }
        }
    }

    public func dispatchCallbackQuery(
        query: TelegramCallbackQuery,
        client: TelegramClient,
        logger: LogService
    ) async {
        for module in modules where module.isEnabled {
            if module.canHandleCallback(query: query) {
                do {
                    try await module.handleCallbackQuery(query: query, client: client, logger: logger)
                    return
                } catch {
                    logger.error(module.name, "处理按钮回调异常: \(error.localizedDescription)")
                    return
                }
            }
        }

        for dynamicPlugin in pluginManager.dynamicPlugins where dynamicPlugin.isEnabled {
            if dynamicPlugin.canHandleCallback(query: query) {
                do {
                    try await dynamicPlugin.handleCallbackQuery(query: query, client: client, logger: logger)
                    return
                } catch {
                    logger.error(dynamicPlugin.name, "动态插件回调异常: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
}
