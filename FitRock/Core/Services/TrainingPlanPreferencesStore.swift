import Foundation

protocol TrainingPlanPreferencesStoring {
    func load() -> TrainingPlanPreferences
    func save(_ preferences: TrainingPlanPreferences)
}

final class UserDefaultsTrainingPlanPreferencesStore: TrainingPlanPreferencesStoring {
    static let shared = UserDefaultsTrainingPlanPreferencesStore()

    private let defaults: UserDefaults
    private let key = "fitrock.trainingPlanPreferences"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TrainingPlanPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(TrainingPlanPreferences.self, from: data) else {
            return .default
        }
        return preferences
    }

    func save(_ preferences: TrainingPlanPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}
