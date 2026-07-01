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
                    if ProcessInfo.processInfo.arguments.contains("--reset-ui-data") {
                        UserDefaults.standard.removeObject(forKey: "fitrock.activeTrainingPlan")
                    }
                    appState.prepareForLaunch()
                }
                .fullScreenCover(isPresented: $appState.showConsentGate) {
                    PrivacyConsentView(
                        onAccept: {
                            appState.acceptPrivacyConsent()
                        }
                    )
                }
                .fullScreenCover(isPresented: $appState.showOnboarding) {
                    OnboardingView(
                        onStartFirstWorkout: {
                            appState.completeOnboarding(startFirstWorkout: true)
                        },
                        onFinish: {
                            appState.completeOnboarding(startFirstWorkout: false)
                        }
                    )
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
    @Published var showOnboarding = false
    @Published var showConsentGate = false

    private let db: WorkoutRepository
    private let onboardingStore: OnboardingStateStore
    private let privacyConsentStore: PrivacyConsentStore

    init(
        db: WorkoutRepository = DatabaseManager.shared,
        onboardingStore: OnboardingStateStore = .shared,
        privacyConsentStore: PrivacyConsentStore = .shared
    ) {
        self.db = db
        self.onboardingStore = onboardingStore
        self.privacyConsentStore = privacyConsentStore
    }

    func prepareForLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) {
        checkForUnfinishedWorkout()
        showConsentOrOnboardingIfNeeded(arguments: arguments)
    }

    func checkForUnfinishedWorkout() {
        do {
            try db.connect()
            if try db.hasUnfinishedWorkout() {
                unfinishedWorkout = try db.getUnfinishedWorkout()
                if unfinishedWorkout != nil {
                    showRecoveryAlert = true
                }
            } else {
                clearRecoveryState()
            }
        } catch {
            print("Error checking for unfinished workout: \(error)")
        }
    }

    func resumeWorkout() {
        shouldResumeWorkout = true
        showRecoveryAlert = false
        selectedTab = 1
    }

    func discardUnfinishedWorkout() {
        showRecoveryAlert = false
        if let workout = unfinishedWorkout {
            try? db.deleteWorkout(workout.id)
        }
        clearRecoveryState()
    }

    func markWorkoutCompleted(_ workoutId: String?) {
        guard workoutId == nil || unfinishedWorkout?.id == workoutId else { return }
        clearRecoveryState()
    }

    func showConsentOrOnboardingIfNeeded(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if arguments.contains("--ui-testing"), arguments.contains("--reset-privacy-consent") {
            privacyConsentStore.resetForTesting()
        }
        if arguments.contains("--ui-testing"), arguments.contains("--accept-privacy-consent") {
            privacyConsentStore.accept()
        }

        guard privacyConsentStore.hasAcceptedCurrentConsent else {
            showConsentGate = true
            showOnboarding = false
            return
        }

        showConsentGate = false
        showOnboardingIfNeeded(arguments: arguments)
    }

    func showOnboardingIfNeeded(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if arguments.contains("--skip-onboarding") {
            onboardingStore.markSeen()
            showOnboarding = false
            return
        }
        if arguments.contains("--reset-onboarding") {
            onboardingStore.resetForReplay()
        }
        guard !onboardingStore.hasSeenOnboarding else { return }
        showOnboarding = true
    }

    func completeOnboarding(startFirstWorkout: Bool) {
        onboardingStore.markSeen()
        showOnboarding = false
        if startFirstWorkout {
            selectedTab = 1
        }
    }

    func replayOnboarding() {
        showOnboarding = true
    }

    func acceptPrivacyConsent() {
        privacyConsentStore.accept()
        showConsentGate = false
        showOnboardingIfNeeded()
    }

    private func clearRecoveryState() {
        unfinishedWorkout = nil
        shouldResumeWorkout = false
        showRecoveryAlert = false
        workoutStartedExternally = false
    }
}
