import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            TabView {
                HomeView()
                    .tabItem {
                        Label("日历", systemImage: "calendar")
                    }

                RecordView()
                    .tabItem {
                        Label("训练", systemImage: "figure.strengthtraining.traditional")
                    }

                StatsView()
                    .tabItem {
                        Label("统计", systemImage: "chart.bar")
                    }
            }
            .tint(Theme.Colors.accent)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
