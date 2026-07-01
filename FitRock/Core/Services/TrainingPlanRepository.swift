import Foundation

protocol TrainingPlanRepository {
    func getActivePlan() throws -> TrainingPlan?
    func savePlan(_ plan: TrainingPlan) throws
    func clearActivePlan() throws
    func updateDayStatus(planId: String, dayId: String, status: TrainingPlanDayStatus, matchedWorkoutId: String?) throws
    func markPastDueSessionsSkipped(currentDate: Date) throws
}

final class UserDefaultsTrainingPlanRepository: TrainingPlanRepository {
    static let shared = UserDefaultsTrainingPlanRepository()

    private let defaults: UserDefaults
    private let key = "fitrock.activeTrainingPlan"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func getActivePlan() throws -> TrainingPlan? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(TrainingPlan.self, from: data)
    }

    func savePlan(_ plan: TrainingPlan) throws {
        let data = try JSONEncoder().encode(plan)
        defaults.set(data, forKey: key)
    }

    func clearActivePlan() throws {
        defaults.removeObject(forKey: key)
    }

    func updateDayStatus(planId: String, dayId: String, status: TrainingPlanDayStatus, matchedWorkoutId: String?) throws {
        guard var plan = try getActivePlan(), plan.id == planId else { return }
        for weekIndex in plan.weeks.indices {
            guard let dayIndex = plan.weeks[weekIndex].days.firstIndex(where: { $0.id == dayId }) else { continue }
            plan.weeks[weekIndex].days[dayIndex].status = status
            plan.weeks[weekIndex].days[dayIndex].matchedWorkoutId = matchedWorkoutId
            plan.weeks[weekIndex].days[dayIndex].completedAt = status == .completed ? Date() : nil
            plan.updatedAt = Date()
            try savePlan(plan)
            return
        }
    }

    func markPastDueSessionsSkipped(currentDate: Date = Date()) throws {
        guard var plan = try getActivePlan() else { return }
        var didChange = false
        for weekIndex in plan.weeks.indices {
            for dayIndex in plan.weeks[weekIndex].days.indices {
                let day = plan.weeks[weekIndex].days[dayIndex]
                guard day.status == .planned || day.status == .moved else { continue }
                let availableUntil = day.availableUntil ?? day.date
                if availableUntil < Calendar.current.startOfDay(for: currentDate) {
                    plan.weeks[weekIndex].days[dayIndex].status = .skipped
                    didChange = true
                }
            }
        }
        if didChange {
            plan.updatedAt = Date()
            try savePlan(plan)
        }
    }
}
