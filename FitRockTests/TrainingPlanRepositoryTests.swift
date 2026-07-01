import XCTest
@testable import FitRock

final class TrainingPlanRepositoryTests: XCTestCase {
    func testPastDuePlannedSessionsAreMarkedSkipped() throws {
        let suiteName = "fitrock.plan.repository.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repository = UserDefaultsTrainingPlanRepository(defaults: defaults)
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: start)!
        let nextWeek = calendar.date(byAdding: .day, value: 8, to: start)!
        let session = TrainingPlanDay(
            id: "session-1",
            date: start,
            sequenceIndex: 1,
            availableFrom: start,
            availableUntil: weekEnd,
            title: "Push",
            targetBodyParts: [.chest],
            suggestedExerciseNames: []
        )
        let plan = TrainingPlan(
            id: "plan-1",
            name: "Plan",
            goal: .hypertrophy,
            trainingDaysPerWeek: 1,
            recommendationReason: "",
            startDate: start,
            endDate: weekEnd,
            weeks: [TrainingPlanWeek(weekIndex: 1, days: [session])]
        )

        try repository.savePlan(plan)
        try repository.markPastDueSessionsSkipped(currentDate: nextWeek)

        XCTAssertEqual(try repository.getActivePlan()?.weeks.first?.days.first?.status, .skipped)
    }
}
