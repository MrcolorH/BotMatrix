import SwiftUI
import AppKit
import Network

public struct QQSettingsView: View {
    @ObservedObject var storage: StorageService
    @ObservedObject var qqController: QQController

    // 🐧 QQ 账号接入状态
    @State private var inputQQWsUrl: String = ""
    @State private var inputQQMasterAdminId: String = ""
    @State private var inputQQAdminId: String = ""
    @State private var inputQQAccount: String = ""
    @State private var inputQQPassword: String = ""
    @State private var showSettingsLoginSheet: Bool = false
    @State private var isTestingQQ: Bool = false
    @State private var qqTestResult: String? = nil
    @State private var qqTestSuccess: Bool = false
    @State private var restoreQQResult: String? = nil
    @State private var isRestoringQQ: Bool = false
    @State private var isAddingMaster: Bool = false
    @State private var isAddingAdmin: Bool = false
    @State private var refreshingUserIds: Set<Int64> = []

    // 保存提示
    @State private var showSavedToast: Bool = false

    public init(storage: StorageService, qqController: QQController) {
        self.storage = storage
        self.qqController = qqController
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                daemonSection

                wsSection

                credentialsSection

                permissionsSection

                sessionSection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            inputQQWsUrl = storage.qqWsUrl
            inputQQAccount = storage.qqAccount
            inputQQPassword = storage.qqPassword
            Task {
                await qqController.refreshAllQQProfiles()
            }
        }
        .sheet(isPresented: $showSettingsLoginSheet) {
            QQLoginSheet()
        }
        .sheet(isPresented: $qqController.showNapCatInstallSheet) {
            NapCatInstallSheet()
        }
    }

    // MARK: - 顶栏标题与总控开关
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.indigo)
                    Text("QQ 机器人配置")
                        .font(.system(size: 22, weight: .bold))
                }

                Spacer()

                HStack(spacing: 12) {
                    Toggle("启用 QQ 接入", isOn: $storage.qqBotEnabled)
                        .toggleStyle(.switch)

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
            }

            Text("通过本地 OneBot v11 (NapCat / LLOneBot) 接入 QQ 账号，支持独立权限隔离、会话记忆隔离与群聊/私聊交互。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 守护进程与环境向导卡片
    private var daemonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("App 一键托管 QQ 守护进程 (NapCat)", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Toggle("启动主服务时自动拉起", isOn: $storage.qqManageDaemon)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: storage.isMacQQInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(storage.isMacQQInstalled ? .green : .secondary)
                    Text("官方 Mac QQ: \(storage.isMacQQInstalled ? "已安装" : "未安装")")
                        .font(.system(size: 11))
                }

                if !storage.isMacQQInstalled {
                    Button("下载安装 QQ") {
                        qqController.openQQDownload()
                    }
                    .buttonStyle(.bordered)
                    .font(.system(size: 11))
                }

                HStack(spacing: 6) {
                    Image(systemName: storage.isNapCatInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(storage.isNapCatInstalled ? .green : .secondary)
                    Text("NapCat 协议端: \(storage.isNapCatInstalled ? "已就绪" : "未配置")")
                        .font(.system(size: 11))
                }

                Spacer()

                Button(storage.isNapCatInstalled ? "重新配置 NapCat" : "一键配置 NapCat") {
                    qqController.presentNapCatInstaller()
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .font(.system(size: 11))

                if storage.isQQPatchedForNapCat {
                    Button(isRestoringQQ ? "恢复中..." : "恢复原版 QQ 入口") {
                        isRestoringQQ = true
                        Task {
                            let res = await NapCatInstallerService.shared.restoreOriginalQQ()
                            isRestoringQQ = false
                            restoreQQResult = res.message
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.system(size: 11))
                    .disabled(isRestoringQQ)
                }

                Button("打开扫码后台 (6099)") {
                    qqController.openWebUI()
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11))
            }
            .padding(10)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            if let msg = restoreQQResult {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("知道了") {
                        restoreQQResult = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                }
                .padding(8)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(6)
            }

            Text("💡 开启自动拉起后，点击「启动 QQ」按钮时，App 会在后台全自动唤醒 QQ 守护进程并连通，无需手动打开终端敲命令。")
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

    // MARK: - WebSocket 地址配置卡片
    private var wsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("OneBot WebSocket 协议端地址", systemImage: "network")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 8) {
                Text("本地 OneBot WebSocket 地址")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 8) {
                    TextField("ws://127.0.0.1:3001", text: $inputQQWsUrl)
                        .textFieldStyle(.roundedBorder)

                    Button("应用保存") {
                        storage.qqWsUrl = inputQQWsUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        triggerToast()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: testQQConnection) {
                        if isTestingQQ {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("测试 WS 握手")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingQQ || inputQQWsUrl.isEmpty)
                }

                if let result = qqTestResult {
                    HStack(spacing: 6) {
                        Image(systemName: qqTestSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(qqTestSuccess ? .green : .red)
                        Text(result)
                            .font(.system(size: 12))
                            .foregroundColor(qqTestSuccess ? .green : .red)
                    }
                    .padding(.top, 2)
                }

                Text("💡 提示：NapCat 默认监听 <code>ws://127.0.0.1:3001</code>。如连接断开 App 会在后台自动静默指数退避重连。")
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

    // MARK: - QQ 账号凭据与自动登录卡片
    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("QQ 账号凭据与免密登录", systemImage: "person.badge.key.fill")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Button(action: {
                    showSettingsLoginSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("打开登录管理与扫码")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("默认 QQ 号:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("如: 10001", text: $inputQQAccount)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("QQ 密码 (可选，支持免密登录):")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    SecureField("如无需密码可留空", text: $inputQQPassword)
                        .textFieldStyle(.roundedBorder)
                }

                Button("保存账号") {
                    storage.qqAccount = inputQQAccount.trimmingCharacters(in: .whitespacesAndNewlines)
                    storage.qqPassword = inputQQPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    triggerToast()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 16)
            }

            Toggle("一键启动 QQ 服务时，自动对该账号触发静默免密登录", isOn: $storage.qqAutoQuickLogin)
                .font(.system(size: 11))

            Text("💡 提示：当本地 NTQQ 曾登录过此号时，NapCat 将直接免密秒级完成一键登录，无需掏出手机扫码。")
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

    // MARK: - 权限分级隔离卡片
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("QQ 权限分级隔离配置 (系统所有者 vs 沙箱白名单)", systemImage: "person.2.badge.gearshape.fill")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                if qqController.isConnected {
                    Button(action: {
                        Task {
                            await qqController.refreshAllQQProfiles()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("刷新所有资料")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
            }

            // 1. 👑 系统所有者 (唯一宿主 - 主人仅限一位)
            masterAdminSubSection

            // 2. 🛡️ QQ 普通白名单 (沙箱安全隔离模式)
            sandboxAdminSubSection

            // 3. 👥 新的好友添加申请待审批
            if !qqController.pendingFriendRequests.isEmpty {
                pendingFriendRequestsSubSection
            }

            // 4. 📬 好友 AI 聊天申请待审批列表
            if !qqController.pendingRequests.isEmpty {
                pendingChatRequestsSubSection
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

    // MARK: - 1. 系统所有者 (唯一宿主)
    private var masterAdminSubSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("系统所有者 (唯一宿主 - 真机最高控制权)", systemImage: "crown.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.indigo)

                Spacer()

                Text(storage.qqMasterAdminList.isEmpty ? "未设所有者" : "已设 1 位系统所有者 (唯一主人)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.indigo.opacity(0.1))
                    .cornerRadius(4)
            }

            Text("系统所有者专享：具备 Mac mini 宿主设备文件的完整读写与终端命令执行权限，并可执行 /status 系统报告与额度监控。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if let masterId = storage.qqMasterAdminList.first {
                // 已有主人：卡片化展示，并锁定添加（主人仅限1位，只能删除）
                QQUserCard(
                    userId: masterId,
                    isMaster: true,
                    nickname: storage.getQQNickname(userId: masterId),
                    isRefreshing: refreshingUserIds.contains(masterId),
                    onRefresh: {
                        refreshUserProfile(userId: masterId)
                    },
                    onDelete: {
                        storage.removeQQMasterAdmin(id: masterId)
                        triggerToast()
                    }
                )

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("系统所有者（主人）仅限 1 位以确保宿主安全。如需更换，请先点击上方「移除」解除绑定后再添加。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            } else {
                // 尚未设置主人：提供输入框与自动查询添加
                HStack(spacing: 8) {
                    TextField("输入系统所有者的 QQ 号 (Owner QQ，如: 10001)", text: $inputQQMasterAdminId)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isAddingMaster)

                    Button(action: {
                        addMasterAdminAction()
                    }) {
                        if isAddingMaster {
                            HStack(spacing: 5) {
                                ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                                Text("查询添加中...")
                            }
                        } else {
                            Text("添加系统所有者")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(inputQQMasterAdminId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingMaster)
                }

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("尚未设置系统所有者。建议填入您的 QQ 号，以激活 Mac mini 宿主控制与维护权限。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.textBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 2. QQ 普通白名单 (沙箱模式)
    private var sandboxAdminSubSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("QQ 普通白名单 (沙箱安全隔离模式)", systemImage: "shield.checkered")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.blue)

                Spacer()

                Text("已授权 \(storage.qqAdminList.count) 位沙箱访客")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            Text("普通白名单用户可在 QQ 正常与 AI 拟人化自然对话，但工作区被硬隔离在独立沙箱中（~/.tgbot/sandbox/），严禁读取或修改 Mac 本机任何内容，严禁执行敏感主机维护指令。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("输入被授权的好友或群成员 QQ 号", text: $inputQQAdminId)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isAddingAdmin)

                Button(action: {
                    addSandboxAdminAction()
                }) {
                    if isAddingAdmin {
                        HStack(spacing: 5) {
                            ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                            Text("查询添加中...")
                        }
                    } else {
                        Text("添加沙箱白名单")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(inputQQAdminId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingAdmin)
            }

            if storage.qqAdminList.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("暂未添加沙箱白名单。非名单用户发送消息将被完全拦截，保护 Mac 算力。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(storage.qqAdminList, id: \.self) { adminId in
                        QQUserCard(
                            userId: adminId,
                            isMaster: false,
                            nickname: storage.getQQNickname(userId: adminId),
                            isRefreshing: refreshingUserIds.contains(adminId),
                            onRefresh: {
                                refreshUserProfile(userId: adminId)
                            },
                            onDelete: {
                                storage.removeQQAdmin(id: adminId)
                                triggerToast()
                            }
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(NSColor.textBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - 3. 好友添加待审批
    private var pendingFriendRequestsSubSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("👥 好友添加申请待审批 (\(qqController.pendingFriendRequests.count) 条)", systemImage: "person.crop.circle.badge.plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.blue)

                Spacer()

                Text("可在此直接同意/拒绝，或在 QQ 私聊回复【同意】/【拒绝】")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            ForEach(qqController.pendingFriendRequests) { req in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("申请人 QQ:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("\(req.userId)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        if !req.comment.isEmpty {
                            Text("申请附言: \(req.comment)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button("同意添加好友") {
                        Task {
                            _ = await qqController.approveFriendRequest(userId: req.userId)
                            triggerToast()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)

                    Button("拒绝") {
                        Task {
                            _ = await qqController.rejectFriendRequest(userId: req.userId)
                            triggerToast()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - 4. 聊天申请待审批
    private var pendingChatRequestsSubSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("📬 好友 AI 聊天申请待审核 (\(qqController.pendingRequests.count) 条)", systemImage: "tray.full.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.purple)

                Spacer()

                Text("可在此点击通过或在 QQ 私聊回复 /approve")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            ForEach(qqController.pendingRequests) { req in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(req.senderName)
                                .font(.system(size: 12, weight: .semibold))
                            Text("(\(req.userId))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        if !req.note.isEmpty {
                            Text("申请附言: \(req.note)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button("批准加入沙箱") {
                        Task {
                            _ = await qqController.approveRequest(userId: req.userId)
                            triggerToast()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)

                    Button("拒绝") {
                        Task {
                            _ = await qqController.rejectRequest(userId: req.userId)
                            triggerToast()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 成员操作与资料查询逻辑
    private func addMasterAdminAction() {
        let cleaned = inputQQMasterAdminId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uid = Int64(cleaned) else { return }
        isAddingMaster = true
        Task {
            _ = await qqController.fetchAndCacheQQUserInfo(userId: uid)
            await MainActor.run {
                storage.addQQMasterAdmin(id: uid)
                self.inputQQMasterAdminId = ""
                self.isAddingMaster = false
                self.triggerToast()
            }
        }
    }

    private func addSandboxAdminAction() {
        let cleaned = inputQQAdminId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uid = Int64(cleaned) else { return }
        isAddingAdmin = true
        Task {
            _ = await qqController.fetchAndCacheQQUserInfo(userId: uid)
            await MainActor.run {
                storage.addQQAdmin(id: uid)
                self.inputQQAdminId = ""
                self.isAddingAdmin = false
                self.triggerToast()
            }
        }
    }

    private func refreshUserProfile(userId: Int64) {
        refreshingUserIds.insert(userId)
        Task {
            _ = await qqController.fetchAndCacheQQUserInfo(userId: userId)
            await MainActor.run {
                refreshingUserIds.remove(userId)
                triggerToast()
            }
        }
    }

    // MARK: - 多租户会话隔离与记忆配置
    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("多租户会话隔离与记忆管理 (零混淆保证)", systemImage: "lock.shield")
                .font(.system(size: 15, weight: .bold))

            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Text("记忆轮数:")
                        .font(.system(size: 12))
                    Picker("", selection: $storage.sessionMaxTurns) {
                        Text("5 轮").tag(5)
                        Text("10 轮 (推荐)").tag(10)
                        Text("15 轮").tag(15)
                        Text("20 轮").tag(20)
                    }
                    .frame(width: 120)
                }

                HStack(spacing: 6) {
                    Text("闲置超时重置:")
                        .font(.system(size: 12))
                    Picker("", selection: $storage.sessionTimeoutMinutes) {
                        Text("15 分钟").tag(15)
                        Text("30 分钟 (推荐)").tag(30)
                        Text("60 分钟").tag(60)
                        Text("永不超时").tag(0)
                    }
                    .frame(width: 130)
                }

                Spacer()

                Button("一键清空全部记忆") {
                    SessionManager.shared.resetAll()
                    triggerToast()
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11))
            }

            Text("💡 Telegram 与 QQ 所有人会话完全独立。任意用户在聊天窗口发送 <code>/reset</code> 或 <code>清空记忆</code>，将只清空其个人记忆，绝不影响他人。")
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

    private func triggerToast() {
        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedToast = false
        }
    }

    private func testQQConnection() {
        let wsStr = inputQQWsUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: wsStr), let host = url.host else {
            qqTestSuccess = false
            qqTestResult = "WebSocket 地址格式错误"
            return
        }
        let port = url.port ?? (url.scheme == "wss" ? 443 : (url.scheme == "ws" ? 80 : 3001))

        isTestingQQ = true
        qqTestResult = nil

        let endpointHost = NWEndpoint.Host(host)
        let endpointPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        let conn = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)

        let lock = NSLock()
        var finished = false
        let finish = { (success: Bool, message: String) in
            lock.lock()
            defer { lock.unlock() }
            guard !finished else { return }
            finished = true
            conn.cancel()
            Task { @MainActor in
                self.isTestingQQ = false
                self.qqTestSuccess = success
                self.qqTestResult = message
                if success {
                    self.storage.qqWsUrl = wsStr
                    self.triggerToast()
                }
            }
        }

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(true, "握手成功！本地 QQ 守护服务端口已就绪并连通")
            case .failed(let err):
                finish(false, "连接失败: \(err.localizedDescription) (请确认 NapCat 已启动)")
            default:
                break
            }
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            finish(false, "连接超时 (2秒内端口无响应)")
        }

        conn.start(queue: DispatchQueue.global())
    }
}

// MARK: - QQ 用户卡片组件 (列表-卡片展示：昵称、头像小图、QQ号)
struct QQUserCard: View {
    let userId: Int64
    let isMaster: Bool
    let nickname: String?
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 1. 头像小图 (38x38 官方 CDN 实时加载，圆角矩形，平滑占位)
            AsyncImage(url: URL(string: "https://q1.qlogo.cn/g?b=qq&nk=\(userId)&s=100")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure(_):
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                        Image(systemName: isMaster ? "crown.fill" : "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 38, height: 38)
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                        ProgressView().scaleEffect(0.6)
                    }
                    .frame(width: 38, height: 38)
                @unknown default:
                    EmptyView()
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
            )

            // 2. 昵称与 QQ 账号
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(nickname?.isEmpty == false ? nickname! : "QQ 用户")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    if isMaster {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 8))
                            Text("系统宿主")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.indigo.opacity(0.12))
                        .foregroundColor(.indigo)
                        .cornerRadius(4)
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 8))
                            Text("沙箱隔离")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    }
                }

                HStack(spacing: 4) {
                    Text("QQ:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(userId)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("\(userId)", forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("复制 QQ 号")
                }
            }

            Spacer()

            // 3. 操作区：刷新资料与删除按钮
            HStack(spacing: 8) {
                Button(action: onRefresh) {
                    if isRefreshing {
                        ProgressView().scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing)
                .help("从 QQ 重新同步昵称资料")

                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("移除")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.red.opacity(0.85))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color(NSColor.textBackgroundColor).opacity(0.65))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
        )
    }
}
