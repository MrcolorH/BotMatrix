import SwiftUI
import AppKit

public struct LogConsoleView: View {
    @ObservedObject var logger: LogService
    @State private var selectedLevel: String = "ALL"
    @State private var searchText: String = ""
    @State private var autoScroll: Bool = true

    public init(logger: LogService) {
        self.logger = logger
    }

    private var filteredEntries: [LogEntry] {
        logger.entries.filter { entry in
            let matchesLevel = (selectedLevel == "ALL") || (entry.level.rawValue == selectedLevel)
            let matchesSearch = searchText.isEmpty
                || entry.message.localizedCaseInsensitiveContains(searchText)
                || entry.tag.localizedCaseInsensitiveContains(searchText)
            return matchesLevel && matchesSearch
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 顶栏控制栏
            topBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 日志主列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        if filteredEntries.isEmpty {
                            emptyView
                        } else {
                            ForEach(filteredEntries) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .padding(12)
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: logger.entries.count) { _ in
                    if autoScroll, let last = filteredEntries.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            // 等级筛选 Picker
            Picker("", selection: $selectedLevel) {
                Text("全部 (\(logger.entries.count))").tag("ALL")
                Text("ℹ️ 信息").tag("INFO")
                Text("✅ 成功").tag("SUCCESS")
                Text("⚠️ 警告").tag("WARN")
                Text("❌ 错误").tag("ERROR")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索日志...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            Spacer()

            // 自动滚屏开关
            Toggle(isOn: $autoScroll) {
                Label("随新滚动", systemImage: "arrow.down.to.line.compact")
                    .font(.system(size: 11))
            }
            .toggleStyle(.button)
            .controlSize(.small)

            // 复制全部
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(logger.exportText(), forType: .string)
            }) {
                Label("复制全部", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // 清空
            Button(action: {
                logger.clear()
            }) {
                Label("清空", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut("k", modifiers: [.command])
        }
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.formattedTime)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(entry.level.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(colorForLevel(entry.level))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(colorForLevel(entry.level).opacity(0.12))
                .cornerRadius(4)
                .frame(width: 60, alignment: .center)

            Text("[\(entry.tag)]")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 70, alignment: .leading)

            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.6))
            Text("控制台暂无匹配日志")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
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
