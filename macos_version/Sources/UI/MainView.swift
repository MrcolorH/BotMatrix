import SwiftUI

public struct MainView: View {
    @StateObject private var controller = BotController.shared
    @StateObject private var storage = StorageService.shared
    @StateObject private var registry = ServiceRegistry.shared
    @StateObject private var logger = LogService.shared

    @State private var selectedTab: String = "dashboard"

    public init() {}

    public var body: some View {
        NavigationSplitView {
            // 侧边栏分栏菜单
            List(selection: $selectedTab) {
                Section("主控面板") {
                    NavigationLink(value: "dashboard") {
                        Label("控制台", systemImage: "gauge.with.needle")
                    }

                    NavigationLink(value: "services") {
                        Label("插件中心", systemImage: "puzzlepiece.extension")
                    }

                    NavigationLink(value: "logs") {
                        Label("实时日志", systemImage: "terminal")
                    }
                }

                Section("平台参数") {
                    NavigationLink(value: "tg_settings") {
                        Label("Telegram 设置", systemImage: "paperplane.fill")
                    }

                    NavigationLink(value: "qq_settings") {
                        Label("QQ 机器人", systemImage: "message.fill")
                    }
                }

                Section("AI 与能力") {
                    NavigationLink(value: "persona") {
                        Label("角色卡管理", systemImage: "theatermasks.fill")
                    }

                    NavigationLink(value: "cli") {
                        Label("反重力 CLI", systemImage: "command.square.fill")
                    }
                }

                Section("系统") {
                    NavigationLink(value: "about") {
                        Label("关于与说明", systemImage: "info.circle.fill")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 215, max: 260)
        } detail: {
            Group {
                switch selectedTab {
                case "dashboard":
                    DashboardView(
                        controller: controller,
                        storage: storage,
                        registry: registry,
                        logger: logger,
                        selectedTab: $selectedTab
                    )
                case "services":
                    ServicesView(
                        registry: registry,
                        storage: storage,
                        selectedTab: $selectedTab
                    )
                case "logs":
                    LogConsoleView(
                        logger: logger
                    )
                case "tg_settings", "settings":
                    TelegramSettingsView(
                        storage: storage,
                        controller: controller
                    )
                case "qq_settings":
                    QQSettingsView(
                        storage: storage,
                        qqController: QQController.shared
                    )
                case "persona":
                    PersonaSettingsView(
                        storage: storage
                    )
                case "cli":
                    CliSettingsView(
                        storage: storage
                    )
                case "about":
                    AboutView(
                        storage: storage
                    )
                default:
                    Text("请选择侧边栏项目")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 12) {
                    StatusBadge(
                        isRunning: controller.isRunning,
                        isBusy: controller.isBusy
                    )

                    Button(action: {
                        controller.toggle()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: controller.isRunning ? "stop.fill" : "play.fill")
                            Text(controller.isRunning ? "停止服务" : "启动服务")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(controller.isRunning ? .red : .blue)
                    .disabled(controller.isBusy || (storage.botToken.isEmpty && !controller.isRunning))
                }
            }
        }
        .frame(minWidth: 920, minHeight: 600)
        .onAppear {
            if storage.autoStart && !storage.botToken.isEmpty {
                controller.start()
            }
        }
    }
}
