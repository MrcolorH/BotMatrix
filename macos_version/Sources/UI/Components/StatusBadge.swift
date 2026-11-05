import SwiftUI

public struct StatusBadge: View {
    let isRunning: Bool
    let isBusy: Bool

    public init(isRunning: Bool, isBusy: Bool) {
        self.isRunning = isRunning
        self.isBusy = isBusy
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.4), lineWidth: 3)
                        .scaleEffect(isBusy || isRunning ? 1.4 : 1.0)
                        .opacity(isBusy || isRunning ? 0.8 : 0.0)
                )

            Text(statusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.12))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        if isBusy {
            return .orange
        } else if isRunning {
            return .green
        } else {
            return .secondary
        }
    }

    private var statusText: String {
        if isBusy {
            return "连接中..."
        } else if isRunning {
            return "运行中"
        } else {
            return "已停止"
        }
    }
}
