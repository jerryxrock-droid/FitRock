import XCTest
@testable import FitRock

final class OnboardingStateStoreTests: XCTestCase {
    func testDefaultsToNotSeen() {
        let defaults = UserDefaults(suiteName: "OnboardingStateStoreTests.defaults")!
        defaults.removePersistentDomain(forName: "OnboardingStateStoreTests.defaults")
        let store = OnboardingStateStore(defaults: defaults, key: "seen")

        XCTAssertFalse(store.hasSeenOnboarding)
    }

    func testMarkSeenPersists() {
        let defaults = UserDefaults(suiteName: "OnboardingStateStoreTests.persist")!
        defaults.removePersistentDomain(forName: "OnboardingStateStoreTests.persist")
        let store = OnboardingStateStore(defaults: defaults, key: "seen")

        store.markSeen()

        XCTAssertTrue(OnboardingStateStore(defaults: defaults, key: "seen").hasSeenOnboarding)
    }

    func testReplayDoesNotTouchWorkoutData() throws {
        let repository = MockOnboardingWorkoutRepository()
        let store = OnboardingStateStore(defaults: UserDefaults(suiteName: "OnboardingStateStoreTests.replay")!, key: "seen")
        let appState = AppState(db: repository, onboardingStore: store)

        appState.replayOnboarding()

        XCTAssertTrue(appState.showOnboarding)
        XCTAssertFalse(repository.didDeleteWorkout)
    }
}

private final class MockOnboardingWorkoutRepository: WorkoutRepository {
    var didDeleteWorkout = false

    func connect() throws {}
    func saveWorkout(_ workout: Workout) throws {}
    func getWorkouts(for date: Date) throws -> [Workout] { [] }
    func getAllCompletedWorkouts() throws -> [Workout] { [] }
    func getLastWorkoutSets(for exerciseIdValue: String) throws -> [ExerciseSet] { [] }
    func hasUnfinishedWorkout() throws -> Bool { false }
    func getUnfinishedWorkout() throws -> Workout? { nil }
    func deleteWorkout(_ workoutIdValue: String) throws { didDeleteWorkout = true }
}
