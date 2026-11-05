import SwiftUI

/// 订阅者管理与标签定制面板
public struct MorningNewsSubscribersSheet: View {
    @ObservedObject var newsService = MorningNewsService.shared
    @ObservedObject var controller = BotController.shared
    @Environment(\.dismiss) private var dismiss

    @State private var testingUserId: Int64? = nil
    @State private var statusMessage: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("☀️ 每日晨报订阅名单与标签")
                        .font(.system(size: 16, weight: .bold))
                    Text("所有通过 /getNews 加入推送名单的用户，及其自主定制的关注标签。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(18)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 状态提示
            if !statusMessage.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(statusMessage)
                        .font(.system(size: 12))
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
            }

            // 订阅者列表
            if newsService.subscribers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("当前暂无订阅用户")
                        .font(.system(size: 14, weight: .medium))
                    Text("用户向机器人发送 <code>/getNews</code> 即可自动加入推送名单。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List {
                    ForEach(newsService.subscribers) { sub in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(sub.isActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: sub.isActive ? "bell.fill" : "bell.slash")
                                    .foregroundColor(sub.isActive ? .green : .gray)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(sub.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("ID: \(sub.userId)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    if !sub.isActive {
                                        Text("已暂停")
                                            .font(.system(size: 10))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.12))
                                            .foregroundColor(.red)
                                            .cornerRadius(4)
                                    }
                                }

                                // 关注的标签
                                HStack(spacing: 4) {
                                    Text("关注标签:")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    ForEach(sub.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 10))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    }
                                }
                            }

                            Spacer()

                            // 单独发送测试按钮
                            Button(action: {
                                testSend(to: sub)
                            }) {
                                HStack(spacing: 4) {
                                    if testingUserId == sub.userId {
                                        ProgressView().scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "paperplane")
                                    }
                                    Text("发送测试")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(testingUserId != nil || !controller.isRunning)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(minWidth: 540, minHeight: 380)
    }

    private func testSend(to sub: NewsSubscriber) {
        testingUserId = sub.userId
        statusMessage = "正在为 [\(sub.displayName)] 调用后台 CLI 生成测试晨报并推送..."

        Task {
            do {
                try await controller.sendTestMorningNews(to: sub)
                await MainActor.run {
                    self.testingUserId = nil
                    self.statusMessage = "✅ 成功向 [\(sub.displayName)] 发送测试晨报！"
                }
            } catch {
                await MainActor.run {
                    self.testingUserId = nil
                    self.statusMessage = "❌ 发送失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
