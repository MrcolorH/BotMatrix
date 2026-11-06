import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

public struct QQLoginSheet: View {
    @ObservedObject var qqController = QQController.shared
    @ObservedObject var storage = StorageService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var inputUin: String = ""
    @State private var inputPassword: String = ""
    @State private var autoLoginOnStart: Bool = true

    @State private var isLoggingIn: Bool = false
    @State private var statusMessage: String = ""
    @State private var isSuccess: Bool = false

    // 扫码相关
    @State private var qrCodeImage: NSImage? = nil
    @State private var isFetchingQR: Bool = false
    @State private var pollTimer: Timer? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 顶栏标题
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 20))
                        .foregroundColor(.indigo)
                    Text("QQ 账号管理与一键登录")
                        .font(.system(size: 16, weight: .bold))
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

            // 切换 Tab
            Picker("", selection: $selectedTab) {
                Text("⚡️ 免密一键登录").tag(0)
                Text("🔐 账号密码登录").tag(1)
                Text("📱 App 内扫码").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // 主内容区域
            ScrollView {
                VStack(spacing: 16) {
                    if selectedTab == 0 {
                        quickLoginTab
                    } else if selectedTab == 1 {
                        passwordLoginTab
                    } else {
                        qrCodeLoginTab
                    }

                    // 统一状态提示栏
                    if !statusMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "info.circle.fill")
                                .foregroundColor(isSuccess ? .green : .orange)
                            Text(statusMessage)
                                .font(.system(size: 12))
                                .foregroundColor(isSuccess ? .green : .primary)
                            Spacer()
                        }
                        .padding(10)
                        .background((isSuccess ? Color.green : Color.orange).opacity(0.12))
                        .cornerRadius(8)
                    }
                }
                .padding(20)
            }

            Divider()

            // 底部操作栏
            HStack {
                Text("💡 NapCat 已深度接管，所有凭据均只保存在本地设备")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 480, height: 490)
        .onAppear {
            inputUin = storage.qqAccount.isEmpty ? (qqController.quickLoginList.first ?? "") : storage.qqAccount
            inputPassword = storage.qqPassword
            autoLoginOnStart = storage.qqAutoQuickLogin

            // 预拉取快速登录列表与状态
            Task {
                _ = await qqController.syncLoginStatus()
                if qqController.quickLoginList.isEmpty {
                    if let list = try? await NapCatService.shared.getQuickLoginList(), !list.isEmpty {
                        if inputUin.isEmpty { inputUin = list[0] }
                    }
                }
            }
        }
        .onDisappear {
            stopPolling()
        }
        .onChange(of: selectedTab) { newTab in
            statusMessage = ""
            if newTab == 2 {
                loadQRCode()
                startPolling()
            } else {
                stopPolling()
            }
        }
    }

    // MARK: - 1. 免密一键登录 Tab

    private var quickLoginTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("本机 NTQQ 历史登录账号")
                .font(.system(size: 13, weight: .semibold))

            if qqController.quickLoginList.isEmpty && inputUin.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("暂未扫描到本机历史登录的 QQ 号")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("您可以切换到「📱 App 内扫码」登录一次，以后即可永久享受一键秒登！")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(Set([inputUin] + qqController.quickLoginList)).filter { !$0.isEmpty }, id: \.self) { uin in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.indigo)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("QQ: \(uin)")
                                    .font(.system(size: 14, weight: .medium))
                                if uin == "\(qqController.botUin)" && qqController.isConnected {
                                    Text("当前正在使用")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                } else {
                                    Text("本地已授权缓存")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button(action: {
                                performQuickLogin(uin: uin)
                            }) {
                                if isLoggingIn && inputUin == uin {
                                    ProgressView().scaleEffect(0.7).frame(width: 60)
                                } else {
                                    Text("一键登录")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoggingIn)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }

            Toggle("启动 QQ 服务时自动一键登录此账号", isOn: $autoLoginOnStart)
                .font(.system(size: 12))
                .onChange(of: autoLoginOnStart) { val in
                    storage.qqAutoQuickLogin = val
                }
        }
    }

    // MARK: - 2. 账号密码登录 Tab

    private var passwordLoginTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("输入 QQ 账号与密码直接登录")
                .font(.system(size: 13, weight: .semibold))

            VStack(spacing: 12) {
                HStack {
                    Text("QQ 账号:")
                        .font(.system(size: 13))
                        .frame(width: 75, alignment: .trailing)
                    TextField("输入 QQ 号", text: $inputUin)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("QQ 密码:")
                        .font(.system(size: 13))
                        .frame(width: 75, alignment: .trailing)
                    SecureField("输入 QQ 密码", text: $inputPassword)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Toggle("记住账号与密码（加密保存在本地配置）", isOn: $autoLoginOnStart)
                .font(.system(size: 12))
                .onChange(of: autoLoginOnStart) { val in
                    storage.qqAutoQuickLogin = val
                }

            Button(action: {
                performPasswordLogin()
            }) {
                HStack {
                    if isLoggingIn {
                        ProgressView().scaleEffect(0.8)
                    }
                    Text(isLoggingIn ? "正在登录..." : "立即登录")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoggingIn || inputUin.isEmpty || inputPassword.isEmpty)

            if statusMessage.contains("App 内扫码") {
                Button("👉 一键切换至「App 内扫码」") {
                    selectedTab = 2
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 3. App 内原生扫码登录 Tab

    private var qrCodeLoginTab: some View {
        VStack(spacing: 14) {
            Text("使用手机 QQ 扫一扫下方二维码")
                .font(.system(size: 13, weight: .medium))

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 210, height: 210)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                if let img = qrCodeImage {
                    Image(nsImage: img)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 190, height: 190)
                        .cornerRadius(6)
                } else if isFetchingQR {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("正在拉取最新二维码...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("点击刷新二维码")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: { loadQRCode() }) {
                    Label("刷新二维码", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)

                if qqController.isQrCodeAccepted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已扫描，请在手机上点击确认")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 业务操作

    private func performQuickLogin(uin: String) {
        inputUin = uin
        isLoggingIn = true
        statusMessage = "正在触发本地一键登录..."
        isSuccess = false

        Task {
            let ok = await qqController.performQuickLogin(uin: uin)
            await MainActor.run {
                isLoggingIn = false
                if ok {
                    isSuccess = true
                    statusMessage = "🎉 一键登录成功！已连通本地 QQ 节点"
                    storage.qqAccount = uin
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                } else {
                    statusMessage = qqController.lastError ?? "一键登录失败，请尝试扫码登录"
                }
            }
        }
    }

    private func performPasswordLogin() {
        guard !inputUin.isEmpty, !inputPassword.isEmpty else { return }
        isLoggingIn = true
        statusMessage = "正在通过账号密码登录..."
        isSuccess = false

        Task {
            let result = await qqController.performPasswordLogin(uin: inputUin, password: inputPassword)
            await MainActor.run {
                self.isLoggingIn = false
                if result.success {
                    self.isSuccess = true
                    self.statusMessage = "🎉 \(result.message.isEmpty ? "账号密码登录成功！" : result.message)"
                    self.storage.qqAccount = self.inputUin
                    self.storage.qqPassword = self.inputPassword
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.dismiss()
                    }
                } else {
                    if result.needNewDevice {
                        self.statusMessage = "⚠️ \(result.message)：检测到新设备保护，请切换至「📱 App 内扫码」扫码确认"
                    } else if result.needCaptcha {
                        self.statusMessage = "⚠️ 需要滑块验证码，建议切换至「📱 App 内扫码」直接免密扫码"
                    } else {
                        self.statusMessage = result.message.isEmpty ? (self.qqController.lastError ?? "登录失败") : result.message
                    }
                }
            }
        }
    }

    private func loadQRCode() {
        isFetchingQR = true
        qrCodeImage = nil
        Task {
            if let qrStr = await qqController.refreshQRCode() {
                let img = generateQRCode(from: qrStr)
                await MainActor.run {
                    self.qrCodeImage = img
                    self.isFetchingQR = false
                }
            } else {
                await MainActor.run {
                    self.isFetchingQR = false
                    self.statusMessage = "无法获取二维码，请确认本地 QQ 服务已启动"
                }
            }
        }
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task {
                if let status = await qqController.syncLoginStatus() {
                    if status.isLogin {
                        await MainActor.run {
                            self.isSuccess = true
                            self.statusMessage = "🎉 扫码登录成功！"
                            self.stopPolling()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// 使用 CoreImage 原生生成高清矢量二维码
    private func generateQRCode(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 8, y: 8)
        let scaled = output.transformed(by: transform)

        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
