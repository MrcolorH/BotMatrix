import SwiftUI
import AppKit

public struct CliSettingsView: View {
    @ObservedObject var storage: StorageService

    @State private var inputAgyPath: String = ""
    @State private var isTestingAgy: Bool = false
    @State private var agyTestResult: String? = nil
    @State private var agyTestSuccess: Bool = false
    @State private var showSavedToast: Bool = false

    public init(storage: StorageService) {
        self.storage = storage
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                cliConfigSection

                featuresSection

                commandsHelpSection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            inputAgyPath = storage.agyCliPath
        }
    }

    // MARK: - 顶栏标题
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "command.square.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                    Text("反重力 CLI 环境配置")
                        .font(.system(size: 22, weight: .bold))
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(showSavedToast ? "已保存生效" : "配置热更新 (~/.tgbot/config.json)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(showSavedToast ? .green : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(showSavedToast ? 0.2 : 0.1))
                .cornerRadius(8)
                .animation(.easeInOut, value: showSavedToast)
            }

            Text("配置 Mac mini 本地反重力 (AGY) CLI 二进制可执行路径，供 Telegram 与 QQ 机器人调度执行任务。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - CLI 路径配置卡片
    private var cliConfigSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Mac mini 本地反重力 (AGY) CLI 配置", systemImage: "terminal.fill")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("反重力 CLI 二进制可执行路径")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 8) {
                    TextField("/Users/colorh/.local/bin/agy", text: $inputAgyPath)
                        .textFieldStyle(.roundedBorder)

                    Button("浏览选择...") {
                        selectCliFile()
                    }
                    .buttonStyle(.bordered)

                    Button("应用保存") {
                        storage.agyCliPath = inputAgyPath.trimmingCharacters(in: .whitespacesAndNewlines)
                        triggerToast()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: testAgyCli) {
                        if isTestingAgy {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("测试 CLI 连通")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingAgy || inputAgyPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let result = agyTestResult {
                    HStack(spacing: 6) {
                        Image(systemName: agyTestSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(agyTestSuccess ? .green : .red)
                        Text(result)
                            .font(.system(size: 12))
                            .foregroundColor(agyTestSuccess ? .green : .red)
                    }
                    .padding(.top, 4)
                }

                Text("💡 提示：常见路径为 <code>~/.local/bin/agy</code> 或 <code>/opt/homebrew/bin/agy</code>。请确保具有可执行权限 (chmod +x)。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 运行机制说明卡片
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("核心执行架构与安全加固", systemImage: "cpu.fill")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(
                    icon: "arrow.triangle.swap",
                    iconColor: .blue,
                    title: "防死锁并发流式读取管道",
                    desc: "后台采用独立 stdout / stderr 双重异步并发流式读取，杜绝输出过长导致的缓冲区死锁挂起。"
                )

                Divider()

                FeatureRow(
                    icon: "checkmark.shield.fill",
                    iconColor: .green,
                    title: "自动授权与免交互 (--dangerously-skip-permissions)",
                    desc: "后台调度自动注入免密执行标志与 UTF-8 环境，杜绝交互式 TTY 挂起等待提示。"
                )

                Divider()

                FeatureRow(
                    icon: "theatermasks.fill",
                    iconColor: .purple,
                    title: "动态角色卡与人设实时注入",
                    desc: "每次派发 CLI 任务前自动提取当前生效的角色卡 Prompt，并拼接用户个性化多轮历史记录。"
                )

                Divider()

                FeatureRow(
                    icon: "lock.shield.fill",
                    iconColor: .orange,
                    title: "双模权限与沙箱绝对物理隔离",
                    desc: "真实管理员具备 Mac mini 宿主设备全权读写；普通访客与群聊用户工作区硬隔离于 ~/.tgbot/sandbox/ 独立沙箱中。"
                )
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 常用指令参考卡片
    private var commandsHelpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("常用交互指令速查", systemImage: "text.book.closed.fill")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                CommandRow(cmd: "/ai <提示词>", role: "所有人", desc: "向反重力 CLI 提问或派发自动化任务 (群聊中 @机器人 + 内容 亦可)")
                CommandRow(cmd: "/persona", role: "管理员", desc: "查看当前生效的 AI 角色卡人设与设定详情")
                CommandRow(cmd: "/reset", role: "所有人", desc: "清空自己的当前多轮上下文记忆，开启新对话")
                CommandRow(cmd: "/quota", role: "真实管理员", desc: "查询后台反重力 CLI 模型消耗与额度监控")
                CommandRow(cmd: "/status", role: "真实管理员", desc: "查看 Mac mini 宿主系统负载、内存与运行状态")
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    private func selectCliFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.showsHiddenFiles = true
        panel.title = "选择反重力 CLI 二进制可执行文件 (如 agy)"
        if panel.runModal() == .OK, let url = panel.url {
            inputAgyPath = url.path
            storage.agyCliPath = url.path
            triggerToast()
        }
    }

    private func triggerToast() {
        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedToast = false
        }
    }

    private func testAgyCli() {
        let path = inputAgyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }

        isTestingAgy = true
        agyTestResult = nil

        Task {
            do {
                let output = try await AgyService.shared.executePrompt("Say 'AGY is connected!'", cliPath: path)
                await MainActor.run {
                    self.isTestingAgy = false
                    self.agyTestSuccess = true
                    self.agyTestResult = "CLI 测试成功！输出: \(output.prefix(60))"
                    self.storage.agyCliPath = path
                    self.triggerToast()
                }
            } catch {
                await MainActor.run {
                    self.isTestingAgy = false
                    self.agyTestSuccess = false
                    self.agyTestResult = "CLI 调用失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// 辅助行展示组件
private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 15))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
    }
}

private struct CommandRow: View {
    let cmd: String
    let role: String
    let desc: String

    var body: some View {
        HStack(spacing: 10) {
            Text(cmd)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)

            Text(role)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(4)

            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}
