import SwiftUI
import AppKit

public struct TelegramSettingsView: View {
    @ObservedObject var storage: StorageService
    @ObservedObject var controller: BotController

    @State private var inputToken: String = ""
    @State private var showToken: Bool = false
    @State private var isTestingToken: Bool = false
    @State private var tokenTestResult: String? = nil
    @State private var tokenTestSuccess: Bool = false

    // 白名单管理状态
    @State private var newMasterAdminIdText: String = ""
    @State private var newAdminIdText: String = ""
    @State private var showBatchEdit: Bool = false
    @State private var batchAdminText: String = ""

    // 提示状态
    @State private var showSavedToast: Bool = false

    public init(storage: StorageService, controller: BotController) {
        self.storage = storage
        self.controller = controller
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                tokenSection

                multiAdminSection

                privacySection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            inputToken = storage.botToken
            batchAdminText = storage.adminUserIds
        }
    }

    // MARK: - 顶栏标题
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                    Text("Telegram 平台配置")
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

            Text("配置 Telegram 机器人凭据、系统所有者、沙箱白名单访问控制及消息防窥折叠。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Token 凭据卡片
    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Telegram 机器人凭据", systemImage: "key.fill")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Telegram Bot Token")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 8) {
                    if showToken {
                        TextField("例如: 123456789:ABCdef...", text: $inputToken)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("例如: 123456789:ABCdef...", text: $inputToken)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { showToken.toggle() }) {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.bordered)

                    Button("应用保存") {
                        storage.botToken = inputToken.trimmingCharacters(in: .whitespacesAndNewlines)
                        triggerToast()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: testConnection) {
                        if isTestingToken {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("测试有效性")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingToken || inputToken.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let result = tokenTestResult {
                    HStack(spacing: 6) {
                        Image(systemName: tokenTestSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(tokenTestSuccess ? .green : .red)
                        Text(result)
                            .font(.system(size: 12))
                            .foregroundColor(tokenTestSuccess ? .green : .red)
                    }
                    .padding(.top, 4)
                }
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

    // MARK: - 白名单与权限分级卡片
    private var multiAdminSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Telegram 权限分级管理 (系统所有者 vs 沙箱白名单)", systemImage: "person.2.badge.gearshape.fill")
                    .font(.system(size: 15, weight: .bold))

                Spacer()
            }

            // 1. 👑 TG 系统所有者 (拥有真机完全读写权限)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("系统所有者 (拥有 Mac 宿主真机完全读写与维护权限)", systemImage: "crown.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.indigo)

                    Spacer()

                    Text("\(storage.masterAdminList.count) 位系统所有者")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(4)
                }

                Text("系统所有者专享：具备 Mac mini 本地读写与终端命令能力，独享 /status 宿主系统运行状态与 /quota 额度查询。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("输入系统所有者 Telegram ID (Owner ID，例如: 123456789)", text: $newMasterAdminIdText)
                        .textFieldStyle(.roundedBorder)

                    Button("添加系统所有者") {
                        let cleaned = newMasterAdminIdText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let uid = Int64(cleaned) {
                            storage.addMasterAdmin(id: uid)
                            newMasterAdminIdText = ""
                            triggerToast()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(newMasterAdminIdText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if storage.masterAdminList.isEmpty {
                    Text("尚未指定系统所有者。建议填入您的 Telegram User ID，以解锁宿主真机最高权限与运维指令。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(storage.masterAdminList, id: \.self) { adminId in
                            HStack(spacing: 5) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.indigo)
                                Text("\(adminId)")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))

                                Button(action: {
                                    storage.removeMasterAdmin(id: adminId)
                                    triggerToast()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.indigo.opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.textBackgroundColor).opacity(0.45))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.indigo.opacity(0.18), lineWidth: 1)
            )

            // 2. 🛡️ TG 普通白名单 (沙箱安全隔离模式)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("🛡️ 普通白名单 (沙箱隔离模式 - 绝不触碰本机内容)", systemImage: "shield.checkered")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)

                    Spacer()

                    Text("\(storage.adminList.count) 位白名单成员")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(4)
                }

                Text("白名单用户可向 Bot 发送消息与 AI 对话，但被严格物理限制在隔离沙箱目录中，严禁读取或修改 Mac 本地个人文件。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // 当前已添加的管理员标签列表 (Chips)
                if storage.adminList.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("暂未添加任何白名单 ID。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(storage.adminList, id: \.self) { adminId in
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(.blue)
                                Text("\(adminId)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                                Button(action: {
                                    storage.removeAdmin(id: adminId)
                                    batchAdminText = storage.adminUserIds
                                    triggerToast()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("输入 Telegram 纯数字 ID，例如: 123456789", text: $newAdminIdText)
                        .textFieldStyle(.roundedBorder)

                    Button("➕ 添加白名单") {
                        addAdminsFromInput()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newAdminIdText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button(showBatchEdit ? "收起批量" : "批量文本编辑") {
                        showBatchEdit.toggle()
                        batchAdminText = storage.adminUserIds
                    }
                    .buttonStyle(.bordered)
                }

                if showBatchEdit {
                    VStack(alignment: .leading, spacing: 6) {
                        TextEditor(text: $batchAdminText)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 60)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)

                        Button("保存批量列表") {
                            storage.adminUserIds = batchAdminText
                            showBatchEdit = false
                            triggerToast()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color.blue.opacity(0.04))
            .cornerRadius(8)

            Text("💡 如何获取自己的 User ID：在 Telegram 中给 @userinfobot 发送任意消息即可获得纯数字 ID。当未授权用户发送 /ai 时，Bot 也会在拦截回复中给出对方的 ID。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 隐私防护与消息折叠卡片
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("隐私保护与阅后自动折叠", systemImage: "eye.slash.fill")
                .font(.system(size: 15, weight: .bold))

            HStack {
                Text("推文展开后自动折叠超时时间")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Picker("", selection: Binding(
                    get: { storage.autoFoldMinutes },
                    set: {
                        storage.autoFoldMinutes = $0
                        triggerToast()
                    }
                )) {
                    Text("1 分钟后自动折叠").tag(1)
                    Text("3 分钟后自动折叠 (当前)").tag(3)
                    Text("5 分钟后自动折叠").tag(5)
                    Text("10 分钟后自动折叠").tag(10)
                    Text("从不自动折叠 (仅手动)").tag(0)
                }
                .pickerStyle(.menu)
                .frame(width: 180)
            }

            Text("💡 机制说明：推文解析发送到 Telegram 时，默认采用【图文双重剧透毛玻璃】保护。若处于展开状态，超时无操作时 Bot 会自动调用 API 抹除文案并折叠隐藏，杜绝误窥。随时可点击 [👁️ 展开] 重新恢复查看。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Divider()

            Toggle("应用启动时自动开启 Telegram 监听服务", isOn: $storage.autoStart)
                .font(.system(size: 12))
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    private func addAdminsFromInput() {
        let parts = newAdminIdText.components(separatedBy: CharacterSet(charactersIn: ",;， \n\t"))
        for part in parts {
            if let id = Int64(part.trimmingCharacters(in: .whitespaces)) {
                storage.addAdmin(id: id)
            }
        }
        newAdminIdText = ""
        batchAdminText = storage.adminUserIds
        triggerToast()
    }

    private func triggerToast() {
        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedToast = false
        }
    }

    private func testConnection() {
        let token = inputToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }

        isTestingToken = true
        tokenTestResult = nil

        Task {
            do {
                let user = try await controller.testToken(token)
                await MainActor.run {
                    self.isTestingToken = false
                    self.tokenTestSuccess = true
                    self.tokenTestResult = "连接成功！机器人：\(user.displayName) (ID: \(user.id))"
                    self.storage.botToken = token
                    self.triggerToast()
                }
            } catch {
                await MainActor.run {
                    self.isTestingToken = false
                    self.tokenTestSuccess = false
                    self.tokenTestResult = "连接失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
