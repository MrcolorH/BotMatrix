import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        QQController.shared.stop()
        BotController.shared.stop()
    }
}

@main
struct TGBotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var controller = BotController.shared
    @StateObject private var qqController = QQController.shared
    @StateObject private var storage = StorageService.shared

    init() {
        if StorageService.shared.autoStart {
            if !StorageService.shared.botToken.isEmpty {
                DispatchQueue.main.async {
                    BotController.shared.start()
                }
            }
            if StorageService.shared.qqBotEnabled {
                DispatchQueue.main.async {
                    QQController.shared.start()
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1040, height: 680)

        // macOS 菜单栏常驻托盘 (Menu Bar Extra)
        MenuBarExtra("TGBot", systemImage: (controller.isRunning || qqController.isRunning) ? "paperplane.fill" : "paperplane") {
            Text("🎬 TGBot 多端服务中心")
                .font(.headline)

            Divider()

            // Telegram 状态
            HStack {
                Text(controller.isRunning ? "🟢 Telegram: 运行中 (\(controller.uptimeString))" : "⚪️ Telegram: 已停止")
            }
            Button(controller.isRunning ? "停止 Telegram 监听" : "启动 Telegram 监听") {
                controller.toggle()
            }
            .disabled(controller.isBusy || (storage.botToken.isEmpty && !controller.isRunning))

            Divider()

            // QQ 账号状态
            HStack {
                Text(qqController.isRunning ? (qqController.isConnected ? "🟢 QQ: 已连接 (\(qqController.displayName))" : "🟡 QQ: 正在连接本地终端...") : "⚪️ QQ: 未启动")
            }
            Button(qqController.isRunning ? "停止 QQ 监听" : "启动 QQ 监听") {
                qqController.toggle()
            }
            .disabled(storage.qqWsUrl.isEmpty && !qqController.isRunning)

            Divider()

            Button("打开主控制台") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("退出 TGBot") {
                controller.stop()
                qqController.stop()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
