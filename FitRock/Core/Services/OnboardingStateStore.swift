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

final class PrivacyConsentStore {
    static let shared = PrivacyConsentStore()
    static let currentVersion = "2026-07-01"

    private let defaults: UserDefaults
    private let acceptedKey: String
    private let versionKey: String
    private let dateKey: String

    init(
        defaults: UserDefaults = .standard,
        acceptedKey: String = "hasAcceptedPrivacyConsent",
        versionKey: String = "acceptedPrivacyConsentVersion",
        dateKey: String = "acceptedPrivacyConsentDate"
    ) {
        self.defaults = defaults
        self.acceptedKey = acceptedKey
        self.versionKey = versionKey
        self.dateKey = dateKey
    }

    var hasAcceptedCurrentConsent: Bool {
        defaults.bool(forKey: acceptedKey) &&
        defaults.string(forKey: versionKey) == Self.currentVersion
    }

    var acceptedVersion: String? {
        defaults.string(forKey: versionKey)
    }

    var acceptedDate: Date? {
        defaults.object(forKey: dateKey) as? Date
    }

    func accept(date: Date = Date()) {
        defaults.set(true, forKey: acceptedKey)
        defaults.set(Self.currentVersion, forKey: versionKey)
        defaults.set(date, forKey: dateKey)
    }

    func resetForTesting() {
        defaults.removeObject(forKey: acceptedKey)
        defaults.removeObject(forKey: versionKey)
        defaults.removeObject(forKey: dateKey)
    }
}
