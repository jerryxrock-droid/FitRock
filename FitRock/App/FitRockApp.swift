import SwiftUI

@main
struct FitRockApp: App {
    @StateObject private var appState = AppState()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    appState.checkForUnfinishedWorkout()
                }
                .alert("检测到未保存的训练", isPresented: $appState.showRecoveryAlert) {
                    Button("恢复训练") {
                        appState.resumeWorkout()
                    }
                    Button("放弃", role: .destructive) {
                        appState.discardUnfinishedWorkout()
                    }
                } message: {
                    if let workout = appState.unfinishedWorkout {
                        Text("\(formatDate(workout.startTime)) · \(formatDuration(Date().timeIntervalSince(workout.startTime)))")
                    }
                }
        }
    }

    private func configureAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Theme.Colors.background)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(Theme.Colors.background)
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor(Theme.Colors.textPrimary)]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.Colors.textPrimary)]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return "\(minutes) 分钟"
    }
}

// MARK: - AppState
final class AppState: ObservableObject {
    @Published var unfinishedWorkout: Workout?
    @Published var showRecoveryAlert = false
    @Published var shouldResumeWorkout = false
    @Published var selectedTab = 0
    @Published var workoutStartedExternally = false

    private let db = DatabaseManager.shared

    func checkForUnfinishedWorkout() {
        do {
            try db.connect()
            if try db.hasUnfinishedWorkout() {
                unfinishedWorkout = try db.getUnfinishedWorkout()
                if unfinishedWorkout != nil {
                    showRecoveryAlert = true
                }
            }
        } catch {
            print("Error checking for unfinished workout: \(error)")
        }
    }

    func resumeWorkout() {
        shouldResumeWorkout = true
        showRecoveryAlert = false
    }

    func discardUnfinishedWorkout() {
        showRecoveryAlert = false
        if let workout = unfinishedWorkout {
            try? db.deleteWorkout(workout.id)
        }
        unfinishedWorkout = nil
        shouldResumeWorkout = false
    }
}
