import XCTest
@testable import FitRock

final class SamplePreviewDataTests: XCTestCase {
    func testSamplePreviewDataCanBeGenerated() {
        XCTAssertTrue(SamplePreviewData.workout.isCompleted)
        XCTAssertFalse(SamplePreviewData.workout.exercises.isEmpty)
        XCTAssertFalse(SamplePreviewData.muscleHeatmapSummary.intensities.isEmpty)
        XCTAssertEqual(SamplePreviewData.trainingPlan.weeks.count, 4)
    }

    func testSampleTrainingPlanUsesWeeklyPoolSessions() {
        let plan = SamplePreviewData.trainingPlan

        XCTAssertEqual(plan.weeks.first?.days.count, 3)
        XCTAssertFalse(plan.weeks.flatMap(\.days).contains { $0.status == .rest })
        XCTAssertEqual(plan.weeks.first?.days.map(\.sequenceIndex), [1, 2, 3])
        XCTAssertTrue(plan.weeks.first?.days.allSatisfy { $0.availableFrom != nil && $0.availableUntil != nil } == true)
    }

    func testSampleTrainingPlanShowsExerciseRotation() {
        let plan = SamplePreviewData.trainingPlan
        let firstWeekPush = plan.weeks[0].days[0].suggestedExerciseNames
        let secondWeekPush = plan.weeks[1].days[0].suggestedExerciseNames

        XCTAssertNotEqual(firstWeekPush, secondWeekPush)
    }

    func testSamplePreviewDoesNotCallDatabaseWrites() {
        let repository = MockSampleWriteRepository()

        _ = SamplePreviewData.workout
        _ = SamplePreviewData.muscleHeatmapSummary
        _ = SamplePreviewData.trainingPlan

        XCTAssertFalse(repository.didSaveWorkout)
    }
}

private final class MockSampleWriteRepository: WorkoutRepository {
    var didSaveWorkout = false

    func connect() throws {}
    func saveWorkout(_ workout: Workout) throws { didSaveWorkout = true }
    func getWorkouts(for date: Date) throws -> [Workout] { [] }
    func getAllCompletedWorkouts() throws -> [Workout] { [] }
    func getLastWorkoutSets(for exerciseIdValue: String) throws -> [ExerciseSet] { [] }
    func hasUnfinishedWorkout() throws -> Bool { false }
    func getUnfinishedWorkout() throws -> Workout? { nil }
    func deleteWorkout(_ workoutIdValue: String) throws {}
}
