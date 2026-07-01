import XCTest
@testable import FitRock

final class TrainingPlanPreferencesTests: XCTestCase {
    func testDefaultPreferencesUseHypertrophyAndNoEquipmentPreference() {
        let preferences = TrainingPlanPreferences.default

        XCTAssertEqual(preferences.goal, .hypertrophy)
        XCTAssertNil(preferences.preferredDaysPerWeek)
        XCTAssertNil(preferences.maxSessionMinutes)
        XCTAssertEqual(preferences.equipmentPreference, .noPreference)
        XCTAssertTrue(preferences.avoidedBodyParts.isEmpty)
        XCTAssertEqual(preferences.splitStyle, .ppl)
        XCTAssertEqual(preferences.rotationLevel, .moderate)
        XCTAssertTrue(preferences.enableWeakPointBoost)
    }

    func testPreferencesCodableRoundTrip() throws {
        let preferences = TrainingPlanPreferences(
            goal: .fatLoss,
            preferredDaysPerWeek: 5,
            maxSessionMinutes: 45,
            equipmentPreference: .machine,
            avoidedBodyParts: [.arms, .cardio],
            splitStyle: .custom,
            customSessionTemplates: [
                TrainingPlanSessionTemplate(id: "push", title: "Push", bodyParts: [.chest, .shoulders])
            ],
            lockedExerciseNames: ["杠铃卧推"],
            excludedExerciseNames: ["腿举"],
            rotationLevel: .highVariation,
            enableWeakPointBoost: false
        )

        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(TrainingPlanPreferences.self, from: data)

        XCTAssertEqual(decoded, preferences)
    }

    func testTrainingPlanDecodesWithoutNewOptionalConfigurationFields() throws {
        let json = """
        {
          "id": "legacy",
          "name": "旧计划",
          "goal": "hypertrophy",
          "trainingDaysPerWeek": 4,
          "recommendationReason": "legacy",
          "startDate": 700000000,
          "endDate": 700086400,
          "weeks": [],
          "createdAt": 700000000,
          "updatedAt": 700000000
        }
        """.data(using: .utf8)!

        let plan = try JSONDecoder().decode(TrainingPlan.self, from: json)

        XCTAssertEqual(plan.id, "legacy")
        XCTAssertNil(plan.recommendedSessionMinutes)
        XCTAssertNil(plan.equipmentPreference)
    }

    func testPreferencesDecodeLegacyPayloadWithDefaults() throws {
        let json = """
        {
          "goal": "hypertrophy",
          "preferredDaysPerWeek": 3,
          "maxSessionMinutes": 60,
          "equipmentPreference": "noPreference",
          "avoidedBodyParts": []
        }
        """.data(using: .utf8)!

        let preferences = try JSONDecoder().decode(TrainingPlanPreferences.self, from: json)

        XCTAssertEqual(preferences.splitStyle, .ppl)
        XCTAssertEqual(preferences.rotationLevel, .moderate)
        XCTAssertTrue(preferences.enableWeakPointBoost)
        XCTAssertTrue(preferences.lockedExerciseNames.isEmpty)
        XCTAssertTrue(preferences.excludedExerciseNames.isEmpty)
    }

    func testPreferencesStorePersistsValues() {
        let suiteName = "TrainingPlanPreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsTrainingPlanPreferencesStore(defaults: defaults)
        let preferences = TrainingPlanPreferences(
            goal: .fullBody,
            preferredDaysPerWeek: 2,
            maxSessionMinutes: 30,
            splitStyle: .upperLower,
            lockedExerciseNames: ["深蹲"]
        )

        store.save(preferences)

        XCTAssertEqual(store.load(), preferences)
    }
}
