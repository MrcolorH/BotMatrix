import SwiftUI
import AppKit

public struct PersonaSettingsView: View {
    @ObservedObject var storage: StorageService

    @State private var selectedPersonaCardId: String = ""
    @State private var showSavedToast: Bool = false

    private var currentSelectedCard: PersonaCard? {
        if let card = storage.personaCards.first(where: { $0.id == selectedPersonaCardId }) {
            return card
        }
        return storage.activePersonaCard
    }

    public init(storage: StorageService) {
        self.storage = storage
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                personaLibraryCard
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if selectedPersonaCardId.isEmpty {
                selectedPersonaCardId = storage.activePersonaId
            }
        }
    }

    // MARK: - 顶栏标题与响应速度
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "theatermasks.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.purple)
                    Text("AI 角色卡与人设设定")
                        .font(.system(size: 22, weight: .bold))
                }

                Spacer()

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Text("响应速度:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Picker("", selection: Binding(
                            get: { storage.agyEffort },
                            set: {
                                storage.agyEffort = $0
                                triggerToast()
                            }
                        )) {
                            Text("⚡ 极速对话 (low)").tag("low")
                            Text("⚖️ 平衡思考 (medium)").tag("medium")
                            Text("🧠 深度推理 (high)").tag("high")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }

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

            Text("您可以为 AI 助理创建并保存多套独立角色卡设定（如日常助理、技术顾问、特定角色等），随时一键切换生效。所有角色卡仅保存在 Mac 本地，安全私密。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 角色卡库主卡片
    private var personaLibraryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶栏：标题 + 状态
            HStack {
                Text("私有角色卡设定库")
                    .font(.system(size: 15, weight: .bold))

                Text("仅 Mac 本地私有编辑")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.12))
                    .foregroundColor(.purple)
                    .cornerRadius(4)

                Spacer()

                Button(action: {
                    let newName = "新角色卡 \(storage.personaCards.count + 1)"
                    let defaultPrompt = "你是一个贴心、聪明且幽默的私人 AI 助理。请生动自然地交流，避免冗长套话。"
                    let newCard = storage.addPersonaCard(name: newName, prompt: defaultPrompt, activate: false)
                    selectedPersonaCardId = newCard.id
                    triggerToast()
                }) {
                    Label("新建角色卡", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // 角色卡水平滑动胶囊选择栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(storage.personaCards) { card in
                        let isSelected = (currentSelectedCard?.id == card.id)
                        let isActive = (storage.activePersonaId == card.id)

                        Button(action: {
                            selectedPersonaCardId = card.id
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isActive ? "checkmark.circle.fill" : "person.crop.circle")
                                    .foregroundColor(isActive ? .green : (isSelected ? .accentColor : .secondary))
                                    .font(.system(size: 13))

                                Text(card.name)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .primary : .secondary)

                                if isActive {
                                    Text("生效中")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(3)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.4), lineWidth: isSelected ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()

            // 选中的角色卡详情编辑面板
            if let card = currentSelectedCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("角色卡名称")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("输入角色卡名称", text: Binding(
                                get: { card.name },
                                set: { newName in
                                    storage.updatePersonaCard(id: card.id, name: newName, prompt: card.prompt)
                                    triggerToast()
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                        }

                        Spacer()

                        // 操作按钮组
                        HStack(spacing: 8) {
                            if storage.activePersonaId == card.id {
                                Label("当前全局生效中", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(6)
                            } else {
                                Button("设为当前生效角色") {
                                    storage.setActivePersona(id: card.id)
                                    triggerToast()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .controlSize(.small)
                            }

                            Button(role: .destructive, action: {
                                storage.deletePersonaCard(id: card.id)
                                selectedPersonaCardId = storage.activePersonaId
                                triggerToast()
                            }) {
                                Label("删除", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(storage.personaCards.count <= 1)
                            .help(storage.personaCards.count <= 1 ? "至少保留一个角色卡" : "删除此角色卡")
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("角色设定与系统指令 (System Prompt):")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextEditor(text: Binding(
                            get: { card.prompt },
                            set: { newPrompt in
                                storage.updatePersonaCard(id: card.id, name: card.name, prompt: newPrompt)
                                triggerToast()
                            }
                        ))
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .frame(minHeight: 180)
                        .padding(6)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                    }

                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        Text("私密安全保护：所有角色卡配置仅保存在本地 Mac mini 中，不对外开放编辑。在 Telegram 发送 /persona 仅管理员可查看当前生效内容。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("实时自动保存")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .background(Color(NSColor.textBackgroundColor).opacity(0.4))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
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

    private func triggerToast() {
        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedToast = false
        }
    }
}
