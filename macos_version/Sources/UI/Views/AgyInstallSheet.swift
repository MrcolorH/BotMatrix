import SwiftUI
import AppKit

public struct AgyInstallSheet: View {
    @ObservedObject var installer = AgyInstallerService.shared
    @ObservedObject var storage = StorageService.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 顶栏标题
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("反重力 (AGY) CLI 一键安装与环境向导")
                        .font(.system(size: 16, weight: .bold))
                    Text("智能检测 Gemini 魔法网络连通性、一键极速安装最新官方 Antigravity 并自动完成配置绑定")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            VStack(spacing: 16) {
                // 四步骤状态卡片
                HStack(spacing: 8) {
                    stepIndicator(index: 1, title: "网络预检", currentProgress: installer.installProgress, minProg: 0.0, maxProg: 0.20)
                    stepIndicator(index: 2, title: "环境目录", currentProgress: installer.installProgress, minProg: 0.20, maxProg: 0.40)
                    stepIndicator(index: 3, title: "脚本安装", currentProgress: installer.installProgress, minProg: 0.40, maxProg: 0.80)
                    stepIndicator(index: 4, title: "验证绑定", currentProgress: installer.installProgress, minProg: 0.80, maxProg: 1.0)
                }

                // 网络状态特别警示卡片 (若网络测试未通过，醒目提示调整网络环境)
                if let passed = installer.networkCheckPassed {
                    if !passed {
                        networkWarningCard
                    } else {
                        networkSuccessCard
                    }
                }

                // 进度条与当前状态
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(installer.installStep.isEmpty ? "就绪：点击下方按钮开始检测与安装" : installer.installStep)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(Int(installer.installProgress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }

                    ProgressView(value: installer.installProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.green)
                }
                .padding(.horizontal, 4)

                // 实时安装日志终端视图
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("安装与环境日志")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if installer.isInstalling || installer.isTestingNetwork {
                            ProgressView()
                                .controlSize(.small)
                        }

                        if !installer.installLogs.isEmpty {
                            Button("复制日志") {
                                let text = installer.installLogs.joined(separator: "\n")
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11))
                        }
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                if installer.installLogs.isEmpty {
                                    Text("💡 点击下方「一键检测网络并开始安装」按钮，系统将首先验证 Gemini/Google 网络可达性，随后自动调用官方脚本完成安装并绑定。")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(Array(installer.installLogs.enumerated()), id: \.offset) { idx, log in
                                        Text(log)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(logColor(log))
                                            .id(idx)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                        .background(Color(NSColor.textBackgroundColor).opacity(0.8))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
                        )
                        .onChange(of: installer.installLogs.count) { newCount in
                            if newCount > 0 {
                                proxy.scrollTo(newCount - 1, anchor: .bottom)
                            }
                        }
                    }
                    .frame(height: 180)
                }

                // 底部操作按钮区域
                HStack(spacing: 12) {
                    if installer.isInstalling {
                        Button("取消安装") {
                            installer.cancel()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        ProgressView()
                            .controlSize(.small)
                        Text("正在处理中...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else if installer.isCompleted {
                        Spacer()

                        Button("完成并关闭") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        Button(action: {
                            Task {
                                _ = await installer.testNetworkConnectivity()
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "network")
                                Text("仅测试 Gemini 网络")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(installer.isTestingNetwork)

                        Spacer()

                        Button(action: {
                            Task {
                                await installer.startInstallation()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                Text(installer.networkCheckPassed == false ? "已配置代理，重试并安装" : "一键检测网络并开始安装")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(installer.isTestingNetwork)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(width: 620, height: 530)
    }

    // MARK: - 网络连通异常醒目警示卡片
    private var networkWarningCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 24))
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 6) {
                Text("⚠️ 网络未连通：无法访问 Gemini / Google 节点")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.red)

                Text("反重力 (AGY) 底层依赖 Google 链路，未挂魔法网络环境下将无法下载组件及运行大模型。")
                    .font(.system(size: 11))
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("💡 推荐调整方案：")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("1. 开启科学上网软件（推荐开启 Clash / Surge 的 **TUN 虚拟网卡模式**）")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("2. 或在软件中启用系统全局代理模式，确保浏览器能正常访问 https://antigravity.google")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - 网络连通畅通卡片
    private var networkSuccessCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)

            Text("Gemini API 与 Antigravity 官方服务连接畅通\(installer.networkLatencyMs.map { " (延迟: \($0)ms)" } ?? "")，具备安装与运行条件")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.green)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 步骤指示器
    private func stepIndicator(index: Int, title: String, currentProgress: Double, minProg: Double, maxProg: Double) -> some View {
        let isDone = currentProgress >= maxProg
        let isCurrent = currentProgress >= minProg && currentProgress < maxProg

        return HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isCurrent ? Color.green.opacity(0.2) : Color.secondary.opacity(0.15)))
                    .frame(width: 18, height: 18)

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isCurrent ? .green : .secondary)
                }
            }

            Text(title)
                .font(.system(size: 11, weight: isCurrent || isDone ? .semibold : .regular))
                .foregroundColor(isDone ? .primary : (isCurrent ? .green : .secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isCurrent ? Color.green.opacity(0.06) : Color.clear)
        .cornerRadius(6)
    }

    private func logColor(_ log: String) -> Color {
        if log.contains("❌") || log.contains("Error") || log.contains("error") {
            return .red
        }
        if log.contains("✓") || log.contains("✅") || log.contains("🎉") {
            return .green
        }
        if log.contains("⚠️") || log.contains("Warning") {
            return .orange
        }
        return .primary
    }
}
