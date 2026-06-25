import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tabItem {
                        Label("日历", systemImage: "calendar")
                    }
                    .tag(0)

                RecordView()
                    .tabItem {
                        Label("训练", systemImage: "figure.strengthtraining.traditional")
                    }
                    .tag(1)

                ExerciseLibraryView()
                    .tabItem {
                        Label("动作库", systemImage: "dumbbell")
                    }
                    .tag(2)

                StatsView()
                    .tabItem {
                        Label("统计", systemImage: "chart.bar")
                    }
                    .tag(3)
            }
            .tint(Theme.Colors.accent)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
