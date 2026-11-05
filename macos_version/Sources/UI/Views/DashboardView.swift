import SwiftUI

public struct DashboardView: View {
    @ObservedObject var controller: BotController
    @ObservedObject var qqController = QQController.shared
    @ObservedObject var storage: StorageService
    @ObservedObject var registry: ServiceRegistry
    @ObservedObject var logger: LogService

    @Binding var selectedTab: String
    @State private var showQQLoginSheet: Bool = false

    public init(
        controller: BotController,
        storage: StorageService,
        registry: ServiceRegistry,
        logger: LogService,
        selectedTab: Binding<String>
    ) {
        self.controller = controller
        self.storage = storage
        self.registry = registry
        self.logger = logger
        self._selectedTab = selectedTab
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Telegram 主控卡片
                telegramMasterCard

                // 🐧 QQ 小号网关主控卡片
                qqMasterCard

                // 指标行
                metricsGrid

                // 最近活动卡片
                recentLogsSection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showQQLoginSheet) {
            QQLoginSheet()
        }
        .sheet(isPresented: $qqController.showNapCatInstallSheet) {
            NapCatInstallSheet()
        }
    }

    // MARK: - 1. Telegram 主控卡片

    private var telegramMasterCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: controller.isRunning
                                    ? [Color.blue, Color.cyan]
                                    : [Color.gray.opacity(0.3), Color.gray.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(color: controller.isRunning ? Color.blue.opacity(0.3) : Color.clear, radius: 6, y: 3)

                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }

                // 信息
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        Text(controller.botUser?.displayName ?? "Telegram 机器人服务")
                            .font(.system(size: 18, weight: .bold))
                            .lineLimit(1)

                        StatusBadge(
                            isRunning: controller.isRunning,
                            isBusy: controller.isBusy
                        )
                    }

                    if let botUser = controller.botUser {
                        Text("ID: \(botUser.id) · 在线时长: \(controller.uptimeString)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else if storage.botToken.isEmpty {
                        HStack(spacing: 4) {
                            Text("⚠️ 尚未配置 Telegram Bot Token，")
                                .foregroundColor(.orange)
                            Button("前往配置") {
                                selectedTab = "tg_settings"
                            }
                            .buttonStyle(.link)
                        }
                        .font(.system(size: 12))
                    } else {
                        Text("点击右侧按钮即可启动长轮询监听")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        selectedTab = "tg_settings"
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                            Text("TG配置")
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)

                    // 启动 / 停止按钮
                    Button(action: {
                        controller.toggle()
                    }) {
                    HStack(spacing: 8) {
                        if controller.isBusy {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: controller.isRunning ? "stop.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                        }

                        Text(controller.isBusy ? "处理中..." : (controller.isRunning ? "停止服务" : "启动 Telegram"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(minWidth: 125, minHeight: 36)
                    .foregroundColor(.white)
                    .background(controller.isRunning ? Color.red : Color.blue)
                    .cornerRadius(9)
                }
                .buttonStyle(.plain)
                .disabled(controller.isBusy || (storage.botToken.isEmpty && !controller.isRunning))
            }
        }

            if !controller.isRunning, let error = controller.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 2. 🐧 QQ 小号网关主控卡片

    private var qqMasterCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: qqController.isRunning
                                    ? [Color.cyan, Color.indigo]
                                    : [Color.gray.opacity(0.3), Color.gray.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(color: qqController.isRunning ? Color.cyan.opacity(0.3) : Color.clear, radius: 6, y: 3)

                    Image(systemName: "message.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }

                // 信息
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        Text(qqController.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(qqController.isConnected ? Color.green : (qqController.isRunning ? Color.yellow : Color.gray))
                                .frame(width: 8, height: 8)
                            Text(qqController.statusDescription)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(qqController.isConnected ? .green : (qqController.isRunning ? .orange : .secondary))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (qqController.isConnected ? Color.green : (qqController.isRunning ? Color.yellow : Color.gray)).opacity(0.12)
                        )
                        .cornerRadius(6)
                    }

                    HStack(spacing: 8) {
                        Text("终端: <code>\(storage.qqWsUrl)</code>")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        if qqController.isRunning && qqController.isConnected {
                            Text("· 在线时长: \(qqController.uptimeString)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        selectedTab = "qq_settings"
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                            Text("QQ配置")
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)

                    if qqController.isRunning {
                        Button(action: {
                            showQQLoginSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.key.fill")
                                Text("登录管理")
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                    }

                    // 启动 / 停止按钮
                    Button(action: {
                        qqController.toggle()
                    }) {
                        HStack(spacing: 8) {
                            if qqController.isStopping {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: qqController.isRunning ? "stop.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                            }

                            Text(qqController.isStopping ? "停止中..." : (qqController.isRunning ? "停止服务" : "一键启动 QQ"))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(minWidth: 125, minHeight: 36)
                        .foregroundColor(.white)
                        .background(qqController.isRunning ? Color.red : Color.indigo)
                        .cornerRadius(9)
                    }
                    .buttonStyle(.plain)
                    .disabled(qqController.isStopping || (storage.qqWsUrl.isEmpty && !qqController.isRunning))
                }
            }

            // 首次环境检测与一键向导横幅
            if !storage.isMacQQInstalled {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("💡 首次一键托管：需检测到官方 Mac QQ，安装后本 App 即可在后台全自动拉起并连通！")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    Spacer()
                    Button("下载官方 QQ") {
                        qqController.openQQDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 11))
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            } else if !storage.isNapCatInstalled {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.indigo)
                    Text("💡 首次接入：已检测到官方 Mac QQ，点击右侧按钮即可在 App 内一键秒级配置 NapCat 协议端！")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    Spacer()
                    Button("一键配置 NapCat") {
                        qqController.presentNapCatInstaller()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .font(.system(size: 11, weight: .bold))
                }
                .padding(10)
                .background(Color.indigo.opacity(0.12))
                .cornerRadius(8)
            }

            if !qqController.isConnected, let error = qqController.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 3. 指标行

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 14) {
            MetricCard(
                title: "消息处理总数",
                value: "\(controller.totalProcessed + qqController.totalProcessed)",
                subtitle: "TG: \(controller.totalProcessed) · QQ: \(qqController.totalProcessed)",
                iconName: "arrow.triangle.2.circlepath",
                color: .blue
            )

            MetricCard(
                title: "隔离会话总数",
                value: "\(SessionManager.shared.activeSessionCount)",
                subtitle: "独立记忆上下文 (零混淆)",
                iconName: "person.2.badge.gearshape.fill",
                color: .purple
            )

            MetricCard(
                title: "激活服务模块",
                value: "\(registry.enabledCount) / \(registry.modules.count + registry.pluginManager.dynamicPlugins.count)",
                subtitle: "晨报/视频/AI/热更插件就绪",
                iconName: "puzzlepiece.extension.fill",
                color: .green
            )

            MetricCard(
                title: "运行架构",
                value: "macOS Native",
                subtitle: "SwiftUI 原生多端中枢",
                iconName: "applelogo",
                color: .orange
            )
        }
    }

    // MARK: - 4. 最近日志

    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("最新运行动态", systemImage: "terminal.fill")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Button("查看完整日志 →") {
                    selectedTab = "logs"
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }

            VStack(alignment: .leading, spacing: 6) {
                if logger.entries.isEmpty {
                    Text("暂无日志，启动服务后将在此显示实时输出...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(logger.entries.suffix(5).reversed()) { entry in
                        HStack(spacing: 8) {
                            Text(entry.formattedTime)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)

                            Text("[\(entry.tag)]")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(colorForLevel(entry.level))

                            Text(entry.message)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .padding(14)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
