import SwiftUI
import AppKit

public struct AboutView: View {
    @ObservedObject var storage: StorageService

    public init(storage: StorageService) {
        self.storage = storage
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                appInfoCard

                authorCard

                storagePathsCard

                architectureCard
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - 顶栏标题
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                    Text("关于与说明")
                        .font(.system(size: 22, weight: .bold))
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("运行中 · macOS 原生构建")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            Text("查看 TGBot Hub 作者信息、系统环境、本地存储目录及核心技术架构。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 应用主信息卡片
    private var appInfoCard: some View {
        HStack(alignment: .top, spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("TGBot Hub for macOS")
                        .font(.system(size: 20, weight: .bold))

                    Text("v1.3.0")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }

                Text("专为 macOS 与 Mac mini 设计的高性能多端自动化中枢。支持 Telegram 与 QQ 双平台无缝接入、全网视频直链智能嗅探提取、本地反重力 (AGY) CLI 远程调度、多角色卡人设自由切换，以及宿主真机与隔离沙箱双模权限防护。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)

                HStack(spacing: 16) {
                    Label("Swift 5.9 原生", systemImage: "applelogo")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Label("SwiftUI 跨平台响应", systemImage: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Label("免外部 Python 依赖", systemImage: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 作者与开源信息卡片
    private var authorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("作者与开源生态", systemImage: "person.crop.circle.fill")
                .font(.system(size: 15, weight: .bold))

            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "person.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("MrcolorH")
                            .font(.system(size: 15, weight: .bold))

                        Text("作者 / 开发者")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }

                    Text("GitHub: @MrcolorH · 高性能自动化与多端跨平台研发")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/MrcolorH") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.crop.circle")
                            Text("作者主页")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: {
                        if let url = URL(string: "https://github.com/MrcolorH/TGBot") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text("GitHub 仓库")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .background(Color(NSColor.textBackgroundColor).opacity(0.4))
            .cornerRadius(10)

            HStack(spacing: 16) {
                Label("开源协议: MIT License", systemImage: "doc.text.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Label("仓库地址: github.com/MrcolorH/TGBot", systemImage: "link")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 本地数据与目录卡片
    private var storagePathsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("本地数据存储与工作空间", systemImage: "folder.fill")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 10) {
                PathRow(
                    label: "主配置文件",
                    desc: "持久化存储 Token、白名单、QQ 账号凭据与角色卡库",
                    path: "~/.tgbot/config.json"
                )

                Divider()

                PathRow(
                    label: "隔离沙箱工作区",
                    desc: "非系统所有者的白名单访客执行 CLI 时的隔离物理沙箱目录",
                    path: "~/.tgbot/sandbox"
                )

                Divider()

                PathRow(
                    label: "服务运行日志",
                    desc: "Telegram、QQ 网关与模块调度实时持久化日志",
                    path: "~/.tgbot/logs"
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

    // MARK: - 技术架构矩阵卡片
    private var architectureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("技术架构特性矩阵", systemImage: "square.grid.2x2.fill")
                .font(.system(size: 15, weight: .bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ArchFeatureItem(
                    title: "双平台中枢架构",
                    desc: "Telegram Bot API 长轮询与 OneBot v11 WebSocket 全双工双轨并行，支持统一消息调度。",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .blue
                )

                ArchFeatureItem(
                    title: "防死锁并发管道",
                    desc: "独立 GCD 串行派发队列与 Swift Concurrency，保证大模型长文本流式输出安全不阻塞 UI。",
                    icon: "arrow.triangle.swap",
                    color: .green
                )

                ArchFeatureItem(
                    title: "零依赖全网视频嗅探",
                    desc: "自主识别 Twitter/X、B站、YouTube、TikTok 等链接，纯原生请求直链提取并直传视频。",
                    icon: "play.circle.fill",
                    color: .orange
                )

                ArchFeatureItem(
                    title: "多级白名单安全壁垒",
                    desc: "宿主真机完全读写 vs 沙箱访客严格隔离，杜绝外部提示词注入对本地主机造成任何破坏。",
                    icon: "shield.lefthalf.filled",
                    color: .purple
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
}

// 辅助路径展示行
private struct PathRow: View {
    let label: String
    let desc: String
    let path: String

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(4)
                }
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("在访达中打开") {
                openInFinder(path: path)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.system(size: 11))
        }
    }

    private func openInFinder(path: String) {
        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        if FileManager.default.fileExists(atPath: expanded) {
            NSWorkspace.shared.selectFile(expanded, inFileViewerRootedAtPath: "")
        } else {
            // 如果文件暂不存在，尝试确保上级目录并打开上级
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            NSWorkspace.shared.open(dir)
        }
    }
}

private struct ArchFeatureItem: View {
    let title: String
    let desc: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }

            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}
