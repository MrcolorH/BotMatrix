import SwiftUI
import AppKit

public struct NapCatInstallSheet: View {
    @ObservedObject var installer = NapCatInstallerService.shared
    @ObservedObject var qqController = QQController.shared
    @ObservedObject var storage = StorageService.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 顶栏标题
            HStack(spacing: 12) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NapCat 协议端一键配置向导")
                        .font(.system(size: 16, weight: .bold))
                    Text("极速下载部署 OneBot v11 协议网关并接管 QQ，原版日常 QQ 双开不受影响")
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
                    stepIndicator(index: 1, title: "环境自检", currentProgress: installer.installProgress, minProg: 0.0, maxProg: 0.10)
                    stepIndicator(index: 2, title: "极速下载", currentProgress: installer.installProgress, minProg: 0.10, maxProg: 0.65)
                    stepIndicator(index: 3, title: "部署组件", currentProgress: installer.installProgress, minProg: 0.65, maxProg: 0.80)
                    stepIndicator(index: 4, title: "挂接入口", currentProgress: installer.installProgress, minProg: 0.80, maxProg: 1.0)
                }

                // 进度条与当前状态
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(installer.installStep.isEmpty ? "等待开始配置..." : installer.installStep)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(Int(installer.installProgress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.indigo)
                    }

                    ProgressView(value: installer.installProgress, total: 1.0)
                        .progressViewStyle(.linear)
                }
                .padding(.horizontal, 4)

                // 实时安装日志终端视图
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("安装配置日志流")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if installer.isInstalling {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                if installer.installLogs.isEmpty {
                                    Text("💡 点击下方「开始一键配置」按钮，系统将自动从高速镜像下载 NapCat 并接管 QQ。")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(Array(installer.installLogs.enumerated()), id: \.offset) { idx, log in
                                        Text(log)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(log.contains("❌") ? .red : (log.contains("✓") || log.contains("🎉") ? .green : .primary))
                                            .id(idx)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                        .frame(height: 180)
                        .background(Color(NSColor.textBackgroundColor).opacity(0.8))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: installer.installLogs.count) { newCount in
                            if newCount > 0 {
                                withAnimation {
                                    proxy.scrollTo(newCount - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                // 错误提示条
                if let err = installer.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }

                // 底部操作按钮区域
                HStack(spacing: 12) {
                    if !storage.isMacQQInstalled {
                        Button("下载官方 Mac QQ") {
                            qqController.openQQDownload()
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if installer.isCompleted {
                        Button("完成") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Button("一键启动 QQ") {
                            dismiss()
                            qqController.start()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                    } else if installer.isInstalling {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在全自动部署中...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Button("取消") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Button(installer.errorMessage != nil ? "重新尝试配置" : "开始一键配置") {
                            Task {
                                await installer.startInstallation()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(!storage.isMacQQInstalled)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(width: 540)
    }

    @ViewBuilder
    private func stepIndicator(index: Int, title: String, currentProgress: Double, minProg: Double, maxProg: Double) -> some View {
        let isDone = currentProgress >= maxProg || installer.isCompleted
        let isInProgress = currentProgress >= minProg && currentProgress < maxProg && installer.isInstalling

        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isInProgress ? Color.indigo : Color.gray.opacity(0.3)))
                    .frame(width: 18, height: 18)

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else if isInProgress {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text("\(index)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Text(title)
                .font(.system(size: 11, weight: isInProgress ? .bold : .regular))
                .foregroundColor(isDone ? .primary : (isInProgress ? .indigo : .secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isInProgress ? Color.indigo.opacity(0.08) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
