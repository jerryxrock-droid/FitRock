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

    func testPrivacyConsentDefaultsToNotAccepted() {
        let defaults = UserDefaults(suiteName: "PrivacyConsentStoreTests.defaults")!
        defaults.removePersistentDomain(forName: "PrivacyConsentStoreTests.defaults")
        let store = PrivacyConsentStore(defaults: defaults)

        XCTAssertFalse(store.hasAcceptedCurrentConsent)
    }

    func testPrivacyConsentPersistsVersionAndDate() throws {
        let defaults = UserDefaults(suiteName: "PrivacyConsentStoreTests.persist")!
        defaults.removePersistentDomain(forName: "PrivacyConsentStoreTests.persist")
        let acceptedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let store = PrivacyConsentStore(defaults: defaults)

        store.accept(date: acceptedAt)

        let reloaded = PrivacyConsentStore(defaults: defaults)
        XCTAssertTrue(reloaded.hasAcceptedCurrentConsent)
        XCTAssertEqual(reloaded.acceptedVersion, PrivacyConsentStore.currentVersion)
        XCTAssertEqual(reloaded.acceptedDate, acceptedAt)
    }

    func testPrivacyConsentVersionMismatchRequiresConfirmationAgain() {
        let defaults = UserDefaults(suiteName: "PrivacyConsentStoreTests.version")!
        defaults.removePersistentDomain(forName: "PrivacyConsentStoreTests.version")
        defaults.set(true, forKey: "hasAcceptedPrivacyConsent")
        defaults.set("legacy", forKey: "acceptedPrivacyConsentVersion")
        let store = PrivacyConsentStore(defaults: defaults)

        XCTAssertFalse(store.hasAcceptedCurrentConsent)
    }

    func testPrivacyConsentReplayDoesNotTouchWorkoutData() {
        let repository = MockOnboardingWorkoutRepository()
        let defaults = UserDefaults(suiteName: "PrivacyConsentStoreTests.replay")!
        defaults.removePersistentDomain(forName: "PrivacyConsentStoreTests.replay")
        let appState = AppState(
            db: repository,
            onboardingStore: OnboardingStateStore(defaults: defaults, key: "seen"),
            privacyConsentStore: PrivacyConsentStore(defaults: defaults)
        )

        appState.showConsentGate = true

        XCTAssertTrue(appState.showConsentGate)
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
