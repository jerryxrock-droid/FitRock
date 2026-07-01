import XCTest
@testable import FitRock

final class RepositoryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try super.tearDownWithError()
    }

    func testWorkoutSaveReadAndDeleteUseTemporaryDatabase() throws {
        let db = makeDatabase()
        try db.connect()
        let exercise = try XCTUnwrap(db.getAllExercises().first)
        let workout = Workout(
            startTime: Date(),
            endTime: Date().addingTimeInterval(1800),
            exercises: [
                WorkoutExercise(
                    exerciseId: exercise.id,
                    exerciseName: exercise.name,
                    bodyPart: exercise.bodyPart,
                    sets: [ExerciseSet(setNumber: 1, weight: 60, reps: 8, isCompleted: true)]
                )
            ],
            isCompleted: true
        )

        try db.saveWorkout(workout)

        XCTAssertEqual(try db.getAllCompletedWorkouts().count, 1)
        XCTAssertEqual(try db.getWorkouts(for: workout.startTime).first?.id, workout.id)

        try db.deleteWorkout(workout.id)
        XCTAssertTrue(try db.getAllCompletedWorkouts().isEmpty)
    }

    func testUserExerciseAndTemplateRoundTrip() throws {
        let db = makeDatabase()
        try db.connect()

        try db.saveUserExercise(name: "测试动作", bodyPart: .arms, unit: .reps)
        let userExercise = try XCTUnwrap(try db.getAllExercises().first { $0.name == "测试动作" })
        XCTAssertTrue(userExercise.isUserCreated)
        XCTAssertEqual(userExercise.unit, .reps)

        let template = WorkoutTemplate(name: "Push")
        let templateExercise = WorkoutTemplateExercise(
            templateId: template.id,
            exerciseId: userExercise.id,
            exerciseName: userExercise.name,
            bodyPart: userExercise.bodyPart,
            sortOrder: 0,
            unit: userExercise.unit
        )
        let templateSet = WorkoutTemplateSet(templateExerciseId: templateExercise.id, setNumber: 1, weight: 20, reps: 12)

        try db.saveWorkoutTemplate(template, exercises: [templateExercise], sets: [templateSet])

        XCTAssertEqual(try db.getWorkoutTemplates().count, 1)
        let detail = try XCTUnwrap(try db.getWorkoutTemplateDetail(templateId: template.id))
        XCTAssertEqual(detail.1.first?.exerciseName, "测试动作")

        let workout = try XCTUnwrap(try db.createWorkoutFromTemplate(template.id)?.0)
        XCTAssertEqual(workout.exercises.first?.exerciseName, "测试动作")
    }

    func testSchemaMigrationIsIdempotent() throws {
        let db = makeDatabase()
        try db.connect()
        try db.connect()
        XCTAssertFalse(try db.getAllExercises().isEmpty)
    }

    private func makeDatabase() -> DatabaseManager {
        DatabaseManager(databaseURL: temporaryDirectory.appendingPathComponent("fitrock.sqlite3"))
    }
}
