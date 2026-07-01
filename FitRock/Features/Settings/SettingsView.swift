import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            List {
                Section {
                    Button {
                        appState.replayOnboarding()
                    } label: {
                        HStack {
                            Label("查看新手引导", systemImage: "sparkles")
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textMuted)
                        }
                    }
                    .listRowBackground(Theme.Colors.surface)
                } header: {
                    Text("帮助")
                        .foregroundColor(Theme.Colors.textMuted)
                }

                Section {
                    NavigationLink(destination: PrivacyConsentView(onAccept: { }, showsAcceptAction: false, embedsInNavigation: false)) {
                        Label("重新查看隐私条款", systemImage: "doc.text.magnifyingglass")
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .listRowBackground(Theme.Colors.surface)

                    NavigationLink(destination: PrivacyAndHealthDataView()) {
                        Label("隐私与健康数据", systemImage: "lock.shield")
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .listRowBackground(Theme.Colors.surface)

                    NavigationLink(destination: TrainingDisclaimerView()) {
                        Label("训练免责声明", systemImage: "exclamationmark.triangle")
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .listRowBackground(Theme.Colors.surface)

                    NavigationLink(destination: OpenSourceLicensesView()) {
                        Label("开源与图片来源", systemImage: "curlybraces.square")
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .listRowBackground(Theme.Colors.surface)
                } header: {
                    Text("上架合规")
                        .foregroundColor(Theme.Colors.textMuted)
                }

                Section {
                    HStack {
                        Text("版本")
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .listRowBackground(Theme.Colors.surface)
                } header: {
                    Text("关于")
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyConsentView: View {
    let onAccept: () -> Void
    var showsAcceptAction = true
    var embedsInNavigation = true

    @State private var hasCheckedAgreement = false

    var body: some View {
        Group {
            if embedsInNavigation {
                NavigationStack {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(Theme.Colors.accent)
                        Text("隐私政策与训练免责声明")
                            .font(Theme.Fonts.title)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("请阅读并同意以下条款后继续使用 FitRock。此确认不等同于 Apple 健康授权，健康数据权限仍由 iOS 系统单独管理。")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textMuted)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    complianceCard(
                        title: "隐私政策摘要",
                        icon: "lock.shield",
                        text: "FitRock 不需要账号。训练记录、模板、计划和个人纪录默认保存在本机。当前版本不接入第三方广告 SDK，不使用健康数据做广告、追踪、画像或出售。"
                    )

                    complianceCard(
                        title: "Apple 健康数据",
                        icon: "heart.text.square",
                        text: "如果你之后主动授权，FitRock 只读取体重、心率、静息心率和活动能量，用于本机训练计划建议和统计参考。拒绝授权不影响记录训练。"
                    )

                    complianceCard(
                        title: "训练免责声明摘要",
                        icon: "exclamationmark.triangle",
                        text: "训练计划、肌肉热力图和动作建议仅作为一般健身记录与训练参考，不构成医疗建议。训练中出现疼痛、胸闷、头晕等异常应立即停止。"
                    )

                    VStack(spacing: Theme.Spacing.sm) {
                        NavigationLink(destination: PrivacyAndHealthDataView()) {
                            settingsLinkRow(title: "查看完整隐私政策", icon: "doc.text")
                        }

                        NavigationLink(destination: TrainingDisclaimerView()) {
                            settingsLinkRow(title: "查看完整训练免责声明", icon: "doc.plaintext")
                        }
                    }
                }
                .padding()
            }

            if showsAcceptAction {
                VStack(spacing: Theme.Spacing.md) {
                    Button {
                        hasCheckedAgreement.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Image(systemName: hasCheckedAgreement ? "checkmark.square.fill" : "square")
                                .foregroundColor(hasCheckedAgreement ? Theme.Colors.accent : Theme.Colors.textMuted)
                            Text("我已阅读并同意隐私政策和训练免责声明")
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("privacy-consent-checkbox")

                    Button(action: onAccept) {
                        Text("同意并继续")
                            .font(Theme.Fonts.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(hasCheckedAgreement ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.35))
                            .cornerRadius(Theme.CornerRadius.medium)
                    }
                    .disabled(!hasCheckedAgreement)
                }
                .padding()
                .background(Theme.Colors.background)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("隐私条款")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyAndHealthDataView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                complianceCard(
                    title: "本地优先",
                    icon: "iphone",
                    text: "FitRock 不需要账号。训练记录、模板、计划和个人纪录默认保存在本机 SQLite 数据库中。"
                )

                complianceCard(
                    title: "健康数据用途",
                    icon: "heart.text.square",
                    text: "如果你授权 Apple 健康，FitRock 只读取体重、心率、静息心率和活动能量，用于生成更贴近当前状态的训练计划建议和统计参考。"
                )

                complianceCard(
                    title: "可选授权",
                    icon: "checkmark.shield",
                    text: "拒绝健康数据授权不会影响记录训练、查看动作库、统计训练或手动管理计划。你可以在 iOS 设置中随时调整授权。"
                )

                complianceCard(
                    title: "不用于广告",
                    icon: "hand.raised",
                    text: "FitRock 不使用健康数据做广告、追踪、画像或出售。当前版本不接入第三方广告 SDK。"
                )
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("隐私与健康数据")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TrainingDisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                complianceCard(
                    title: "训练建议性质",
                    icon: "figure.strengthtraining.traditional",
                    text: "FitRock 提供的训练计划、肌肉热力图和动作建议仅作为一般健身记录与训练参考，不构成医疗建议、诊断或治疗方案。"
                )

                complianceCard(
                    title: "量力而行",
                    icon: "speedometer",
                    text: "开始新计划、增加重量或改变训练频率前，请根据自己的经验、恢复状态和身体反应调整强度。"
                )

                complianceCard(
                    title: "必要时咨询专业人士",
                    icon: "person.crop.circle.badge.questionmark",
                    text: "如果你有受伤、慢性疾病、心血管风险、孕期或其他健康顾虑，请先咨询医生、物理治疗师或合格教练。训练中出现疼痛、胸闷、头晕等异常应立即停止。"
                )
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("训练免责声明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OpenSourceLicensesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                complianceCard(
                    title: "SQLite.swift",
                    icon: "externaldrive",
                    text: "FitRock 使用 stephencelis/SQLite.swift 读写本机 SQLite 数据库。该依赖通过 Swift Package Manager 集成，遵循项目自身开源许可。"
                )

                complianceCard(
                    title: "动作图片来源",
                    icon: "photo.on.rectangle",
                    text: "动作教学图片来自 yuhonas/free-exercise-db。该项目采用 Unlicense / public domain 授权，允许复制、修改、发布、商用和非商用分发。"
                )

                complianceCard(
                    title: "本地打包",
                    icon: "shippingbox",
                    text: "动作图片和器械 JSON 数据随 App 本地打包，用于离线动作教学展示，不会从远程服务器加载用户训练数据。"
                )
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle("开源与图片来源")
        .navigationBarTitleDisplayMode(.inline)
    }
}

func complianceCard(title: String, icon: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.accent)
            Text(title)
                .font(Theme.Fonts.headline)
                .foregroundColor(Theme.Colors.textPrimary)
        }

        Text(text)
            .font(Theme.Fonts.body)
            .foregroundColor(Theme.Colors.textSecondary)
            .lineSpacing(4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Theme.Colors.surface)
    .cornerRadius(Theme.CornerRadius.medium)
}

private func settingsLinkRow(title: String, icon: String) -> some View {
    HStack {
        Label(title, systemImage: icon)
            .font(Theme.Fonts.body)
            .foregroundColor(Theme.Colors.textPrimary)
        Spacer()
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(Theme.Colors.textMuted)
    }
    .padding()
    .background(Theme.Colors.surface)
    .cornerRadius(Theme.CornerRadius.small)
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(AppState())
}
