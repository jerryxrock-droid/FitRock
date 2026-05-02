import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            List {
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
}
