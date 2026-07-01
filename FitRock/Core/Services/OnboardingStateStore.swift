import Foundation

final class OnboardingStateStore {
    static let shared = OnboardingStateStore()

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "hasSeenOnboarding") {
        self.defaults = defaults
        self.key = key
    }

    var hasSeenOnboarding: Bool {
        defaults.bool(forKey: key)
    }

    func markSeen() {
        defaults.set(true, forKey: key)
    }

    func resetForReplay() {
        defaults.set(false, forKey: key)
    }
}
