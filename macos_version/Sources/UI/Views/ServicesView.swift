import SwiftUI

/// 合并后的统一插件中心视图 (内置核心服务 + 动态热更新插件 + 插件市场推荐)
public struct ServicesView: View {
    @ObservedObject var registry: ServiceRegistry
    @ObservedObject var storage: StorageService
    @ObservedObject var newsService = MorningNewsService.shared
    @ObservedObject var controller = BotController.shared
    @ObservedObject var pluginManager = DynamicPluginManager.shared
    @ObservedObject var store = MarketplaceStore.shared
    @Binding var selectedTab: String

    @State private var selectedSubTab: Int = 0 // 0: 内置核心服务, 1: 动态热加载插件, 2: 插件市场推荐
    @State private var showSubscribersSheet: Bool = false
    @State private var isBroadcastingTest: Bool = false
    @State private var broadcastStatus: String = ""
    @State private var toastMessage: String = ""

    public init(
        registry: ServiceRegistry,
        storage: StorageService,
        selectedTab: Binding<String>
    ) {
        self.registry = registry
        self.storage = storage
        self._selectedTab = selectedTab
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 顶部统一功能栏
            topHeaderBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 热更新机制说明横幅
                    hotReloadBanner

                    // 统一分段切换器
                    Picker("", selection: $selectedSubTab) {
                        Text("🧩 内置核心服务 (\(registry.modules.count))").tag(0)
                        Text("🔥 动态热更插件 (\(pluginManager.dynamicPlugins.count))").tag(1)
                        Text("🛍️ 插件市场推荐 (\(store.storeItems.count))").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 460)

                    // 内容分发
                    switch selectedSubTab {
                    case 0:
                        nativeCoreServicesSection
                    case 1:
                        dynamicPluginsSection
                    case 2:
                        marketplaceStoreSection
                    default:
                        EmptyView()
                    }
                }
                .padding(24)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showSubscribersSheet) {
            MorningNewsSubscribersSheet()
        }
    }

    // MARK: - 顶部统一功能栏

    private var topHeaderBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("插件与服务中心")
                    .font(.system(size: 20, weight: .bold))
                Text("插槽式架构与运行时热更新：内置核心服务独立配置，动态扩展插件零停机热加载。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 同步指令到 TG 按钮
            Button(action: {
                Task {
                    await controller.syncCommandsToTelegram()
                    triggerToast("✅ 已成功将所有指令同步至 Telegram 官方菜单！")
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("同步指令至 TG")
                }
            }
            .buttonStyle(.bordered)
            .disabled(!controller.isRunning)

            // 打开插件目录按钮
            Button(action: {
                pluginManager.openPluginsDirectory()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                    Text("打开插件目录")
                }
            }
            .buttonStyle(.bordered)

            // 立即热重载按钮
            Button(action: {
                _ = pluginManager.reloadPlugins()
                triggerToast("⚡️ 热重载成功！当前共 \(registry.enabledCount) 个功能模块在线，Bot 保持长轮询不掉线。")
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                    Text("⚡️ 立即热重载")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - 热更新横幅

    private var hotReloadBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("🔥 零重启热更新机制已生效")
                    .font(.system(size: 13, weight: .bold))
                Text("添加或修改外部脚本插件时无需重启 App，机器人网络连接长轮询不断线。点击右上角「立即热重载」毫秒级无缝生效！")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !toastMessage.isEmpty {
                Text(toastMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Tab 0: 内置核心服务

    private var nativeCoreServicesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 全网视频解析卡片 (公共服务)
            videoModuleCard

            // 每日晨报推送卡片 (定向专属服务)
            morningNewsCard

            // 反重力 AI 远程控制卡片 (管理员私有)
            agyModuleCard
        }
    }

    // 1. 全网视频解析模块卡片
    private var videoModuleCard: some View {
        let vm = registry.videoModule

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(vm.name)
                            .font(.system(size: 16, weight: .bold))
                        Text("公共服务 (全员可用)")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }

                    Text("自主识别 Twitter/X、TikTok/抖音、B站、YouTube。支持剧透毛玻璃与可逆交互折叠。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                PlatformToggles(
                    tgEnabled: $storage.videoEnabledTG,
                    qqEnabled: $storage.videoEnabledQQ
                )
            }

            Divider()

            // 功能亮点标签
            HStack(spacing: 8) {
                FeaturePill(icon: "sparkles", text: "全平台智能识别")
                FeaturePill(icon: "eye.slash.fill", text: "图文双重毛玻璃")
                FeaturePill(icon: "arrow.triangle.2.circlepath", text: "随时可逆折叠")
                FeaturePill(icon: "clock.badge.checkmark", text: "\(storage.autoFoldMinutes)分钟自动收起")
            }

            // API Key 配置区域
            VStack(alignment: .leading, spacing: 6) {
                Text("Twitter 高清直链解析 (TwitterDown.com API Key):")
                    .font(.system(size: 12, weight: .semibold))

                HStack {
                    SecureField("输入 API Key (选填，留空自动启用通用解析引擎)", text: $storage.twitterDownApiKey)
                        .textFieldStyle(.roundedBorder)

                    Button("清空") {
                        storage.twitterDownApiKey = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(storage.twitterDownApiKey.isEmpty)
                }
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // 2. 每日晨报模块卡片
    private var morningNewsCard: some View {
        let nm = registry.morningNewsModule

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(nm.name)
                            .font(.system(size: 16, weight: .bold))
                        Text("指定订阅用户推送")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }

                    Text("用户输入 /getNews 加入推送名单；自定义标签（AI大事/机器人/大肥鱼现状等）；每天 08:00 后台 CLI 智能拼接推送。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                PlatformToggles(
                    tgEnabled: $storage.morningNewsEnabledTG,
                    qqEnabled: $storage.morningNewsEnabledQQ
                )
            }

            Divider()

            // 状态与指标
            HStack(spacing: 12) {
                FeaturePill(icon: "person.2.fill", text: "\(newsService.activeSubscriberCount) 位用户已订阅")
                FeaturePill(icon: "clock.fill", text: "推送时间: 每天 \(String(format: "%02d:%02d", newsService.pushHour, newsService.pushMinute))")
                FeaturePill(icon: "tag.fill", text: "支持自由增删标签")
                FeaturePill(icon: "terminal.fill", text: "反重力 CLI 每天自动汇总")

                Spacer()
            }

            // 快捷操作栏
            HStack(spacing: 12) {
                Button(action: {
                    showSubscribersSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("👥 查看订阅名单与标签 (\(newsService.subscribers.count))")
                    }
                }
                .buttonStyle(.bordered)

                Button(action: {
                    triggerBroadcastTest()
                }) {
                    HStack(spacing: 5) {
                        if isBroadcastingTest {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text("⚡️ 立即向所有订阅者广播测试")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isBroadcastingTest || !controller.isRunning || newsService.activeSubscriberCount == 0)

                if !broadcastStatus.isEmpty {
                    Text(broadcastStatus)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // 用户指令指引提示
            HStack(spacing: 12) {
                Text("用户端交互指令:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("<code>/getNews</code> 订阅")
                    .font(.system(size: 11, design: .monospaced))
                Text("<code>/addTag &lt;标签&gt;</code> 定制")
                    .font(.system(size: 11, design: .monospaced))
                Text("<code>/stopNews</code> 退出")
                    .font(.system(size: 11, design: .monospaced))
                Text("<code>/previewNews</code> 试读")
                    .font(.system(size: 11, design: .monospaced))
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .cornerRadius(6)
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    private func triggerBroadcastTest() {
        guard controller.isRunning else {
            broadcastStatus = "⚠️ 机器人未启动，请先启动服务"
            return
        }

        isBroadcastingTest = true
        broadcastStatus = "正在调用后台 CLI 拼接并发送..."

        Task {
            await controller.broadcastMorningNewsManually()
            await MainActor.run {
                self.isBroadcastingTest = false
                self.broadcastStatus = "✅ 广播测试发送完毕！"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.broadcastStatus == "✅ 广播测试发送完毕！" {
                        self.broadcastStatus = ""
                    }
                }
            }
        }
    }

    // 3. 反重力 AI 模块卡片
    private var agyModuleCard: some View {
        let am = registry.agyModule

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(am.name)
                            .font(.system(size: 16, weight: .bold))
                        Text("管理员私有 (白名单拦截)")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }

                    Text("直接调用本地反重力 CLI 实现免前缀拟人对话与远程运维。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                PlatformToggles(
                    tgEnabled: $storage.agyEnabledTG,
                    qqEnabled: $storage.agyEnabledQQ
                )
            }

            Divider()

            // 功能亮点标签
            HStack(spacing: 8) {
                FeaturePill(icon: "shield.lefthalf.filled", text: "非白名单静默拦截")
                FeaturePill(icon: "text.bubble", text: "拟人化输入状态")
                FeaturePill(icon: "theatermasks.fill", text: "人设与角色卡注入")
                FeaturePill(icon: "server.rack", text: "Mac 宿主系统巡检 (/status)")
            }

            // CLI 路径提示
            HStack {
                Text("当前绑定的反重力 CLI 路径:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(storage.agyCliPath)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(4)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
                Spacer()
                Button("配置 CLI 路径") {
                    selectedTab = "cli"
                }
                .buttonStyle(.link)
                .font(.system(size: 12))

                Text("·")
                    .foregroundColor(.secondary)

                Button("配置白名单") {
                    selectedTab = "tg_settings"
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Tab 1: 动态热加载插件

    private var dynamicPluginsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("当前已挂载的动态热加载插件")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Button("前往插件市场添加更多 →") {
                    selectedSubTab = 2
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }

            if pluginManager.dynamicPlugins.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("当前暂无外部动态插件")
                        .font(.system(size: 14, weight: .medium))
                    Text("您可以切换到「插件市场推荐」一键安装常用插件，或点击右上角「打开插件目录」放入您自建的 Python/Shell 脚本。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)

                    Button("浏览推荐插件市场") {
                        selectedSubTab = 2
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(14)
            } else {
                ForEach(pluginManager.dynamicPlugins, id: \.id) { dyn in
                    dynamicPluginRow(dyn)
                }
            }
        }
    }

    private func dynamicPluginRow(_ plugin: DynamicScriptPlugin) -> some View {
        HStack(spacing: 14) {
            Image(systemName: plugin.iconName)
                .font(.system(size: 22))
                .foregroundColor(.orange)
                .frame(width: 42, height: 42)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(plugin.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text("v\(plugin.manifest.version)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("热加载脚本")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }

                Text(plugin.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("响应指令:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    ForEach(plugin.manifest.commands, id: \.self) { c in
                        Text("/\(c)")
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            // 开关
            Toggle("", isOn: Binding(
                get: { plugin.isEnabled },
                set: { pluginManager.togglePlugin(id: plugin.id, enabled: $0) }
            ))
            .toggleStyle(.switch)

            // 卸载
            Button(action: {
                pluginManager.uninstallPlugin(id: plugin.id)
                triggerToast("已卸载插件 [\(plugin.name)]")
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Tab 2: 插件市场推荐

    private var marketplaceStoreSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("官方精选扩展插件模板 (一键安装即时热加载)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)

            ForEach(store.storeItems) { item in
                let installed = store.isInstalled(id: item.manifest.id)

                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: item.manifest.iconName ?? "puzzlepiece.extension")
                        .font(.system(size: 26))
                        .foregroundColor(.accentColor)
                        .frame(width: 46, height: 46)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(item.manifest.name)
                                .font(.system(size: 15, weight: .semibold))
                            Text("v\(item.manifest.version)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            if item.isOfficial {
                                Text("官方认证")
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }

                        Text(item.manifest.description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(NSColor.separatorColor).opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()

                    // 一键安装/更新按钮
                    Button(action: {
                        store.installItem(item)
                        triggerToast("🎉 插件 [\(item.manifest.name)] 安装成功，已热加载上线！")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: installed ? "arrow.clockwise" : "arrow.down.circle.fill")
                            Text(installed ? "更新代码" : "一键安装")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(installed ? .blue : .green)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }

    private func triggerToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if toastMessage == msg {
                toastMessage = ""
            }
        }
    }
}

private struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.separatorColor).opacity(0.2))
        .cornerRadius(6)
    }
}

public struct PlatformToggles: View {
    @Binding var tgEnabled: Bool
    @Binding var qqEnabled: Bool

    public var body: some View {
        HStack(spacing: 8) {
            // Telegram 开关胶囊
            HStack(spacing: 5) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 10))
                    .foregroundColor(tgEnabled ? .blue : .secondary)
                Text("TG")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tgEnabled ? .primary : .secondary)
                Toggle("", isOn: $tgEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tgEnabled ? Color.blue.opacity(0.12) : Color(NSColor.textBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tgEnabled ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )

            // 🐧 QQ 小号开关胶囊
            HStack(spacing: 5) {
                Image(systemName: "message.fill")
                    .font(.system(size: 10))
                    .foregroundColor(qqEnabled ? .cyan : .secondary)
                Text("QQ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(qqEnabled ? .primary : .secondary)
                Toggle("", isOn: $qqEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(qqEnabled ? Color.cyan.opacity(0.12) : Color(NSColor.textBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(qqEnabled ? Color.cyan.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }
}
