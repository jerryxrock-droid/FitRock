import XCTest
@testable import FitRock

final class TemplateCatalogTests: XCTestCase {
    func testTemplateCanSaveJsonExerciseAndCreateWorkout() throws {
        let db = DatabaseManager(databaseURL: temporaryDatabaseURL())
        try db.connect()
        let template = WorkoutTemplate(name: "器械背部")
        let templateExercise = WorkoutTemplateExercise(
            templateId: template.id,
            exerciseId: "json:seated-cable-row",
            exerciseName: "坐姿绳索划船",
            bodyPart: .back,
            sortOrder: 0,
            unit: .weight
        )
        let templateSet = WorkoutTemplateSet(
            templateExerciseId: templateExercise.id,
            setNumber: 1,
            weight: 40,
            reps: 12
        )

        try db.saveWorkoutTemplate(template, exercises: [templateExercise], sets: [templateSet])
        let workout = try XCTUnwrap(db.createWorkoutFromTemplate(template.id)?.0)

        XCTAssertEqual(workout.exercises.first?.exerciseId, "json:seated-cable-row")
        XCTAssertEqual(workout.exercises.first?.exerciseName, "坐姿绳索划船")
        XCTAssertEqual(workout.exercises.first?.sets.first?.weight, 40)
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("fitrock-template-catalog-\(UUID().uuidString).sqlite3")
    }
}
