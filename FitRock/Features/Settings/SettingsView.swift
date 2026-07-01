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

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(AppState())
}
