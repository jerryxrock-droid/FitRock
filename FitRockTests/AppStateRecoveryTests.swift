import XCTest
@testable import FitRock

final class AppStateRecoveryTests: XCTestCase {
    func testCheckForUnfinishedWorkoutClearsStaleRecoveryStateWhenDatabaseHasNoUnfinishedWorkout() {
        let repository = MockWorkoutRepository()
        repository.unfinishedWorkout = nil
        let appState = AppState(db: repository)
        appState.unfinishedWorkout = Workout(isCompleted: false)
        appState.showRecoveryAlert = true
        appState.shouldResumeWorkout = true

        appState.checkForUnfinishedWorkout()

        XCTAssertNil(appState.unfinishedWorkout)
        XCTAssertFalse(appState.showRecoveryAlert)
        XCTAssertFalse(appState.shouldResumeWorkout)
    }

    func testMarkWorkoutCompletedClearsMatchingRecoveryState() {
        let workout = Workout(isCompleted: false)
        let appState = AppState(db: MockWorkoutRepository())
        appState.unfinishedWorkout = workout
        appState.shouldResumeWorkout = true
        appState.showRecoveryAlert = true

        appState.markWorkoutCompleted(workout.id)

        XCTAssertNil(appState.unfinishedWorkout)
        XCTAssertFalse(appState.shouldResumeWorkout)
        XCTAssertFalse(appState.showRecoveryAlert)
    }

    func testResumeWorkoutSwitchesToRecordTab() {
        let appState = AppState(db: MockWorkoutRepository())
        appState.selectedTab = 0

        appState.resumeWorkout()

        XCTAssertTrue(appState.shouldResumeWorkout)
        XCTAssertEqual(appState.selectedTab, 1)
    }
}

private final class MockWorkoutRepository: WorkoutRepository {
    var unfinishedWorkout: Workout?
    var deletedWorkoutId: String?

    func connect() throws {}
    func saveWorkout(_ workout: Workout) throws {}
    func getWorkouts(for date: Date) throws -> [Workout] { [] }
    func getAllCompletedWorkouts() throws -> [Workout] { [] }
    func getLastWorkoutSets(for exerciseIdValue: String) throws -> [ExerciseSet] { [] }
    func hasUnfinishedWorkout() throws -> Bool { unfinishedWorkout != nil }
    func getUnfinishedWorkout() throws -> Workout? { unfinishedWorkout }
    func deleteWorkout(_ workoutIdValue: String) throws {
        deletedWorkoutId = workoutIdValue
        unfinishedWorkout = nil
    }
}
