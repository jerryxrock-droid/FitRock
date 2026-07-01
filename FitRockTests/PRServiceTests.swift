import XCTest
@testable import FitRock

final class PRServiceTests: XCTestCase {
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

    func testWeightExerciseCreatesMaxWeightAndVolumePRs() throws {
        let db = makeDatabase()
        try db.connect()
        let exercise = try XCTUnwrap(try db.getAllExercises().first { $0.unit == .weight })
        let service = PRService(personalRecordRepository: db, exerciseRepository: db, workoutRepository: db)
        let workout = workout(exercise: exercise, sets: [
            ExerciseSet(setNumber: 1, weight: 40, reps: 10, setType: .warmup, isCompleted: true),
            ExerciseSet(setNumber: 2, weight: 100, reps: 5, isCompleted: true)
        ])

        let events = try service.evaluateAndSave(workout: workout)

        XCTAssertTrue(events.contains { $0.prType == .maxWeight && $0.newValue == 100 })
        XCTAssertTrue(events.contains { $0.prType == .exerciseVolume && $0.newValue == 900 })
        XCTAssertEqual(try db.getPersonalRecords(for: exercise.id).count, 2)
    }

    func testDurationExerciseCreatesDurationPR() throws {
        let db = makeDatabase()
        try db.connect()
        let exercise = try XCTUnwrap(try db.getAllExercises().first { $0.unit == .duration })
        let service = PRService(personalRecordRepository: db, exerciseRepository: db, workoutRepository: db)
        let workout = workout(exercise: exercise, sets: [
            ExerciseSet(setNumber: 1, weight: 90, reps: 1, setType: .warmup, isCompleted: true),
            ExerciseSet(setNumber: 2, weight: 180, reps: 1, isCompleted: true)
        ])

        let events = try service.evaluateAndSave(workout: workout)

        XCTAssertEqual(events.first?.prType, .duration)
        XCTAssertEqual(events.first?.newValue, 180)
    }

    func testRebuildAllPersonalRecordsAfterWorkoutDeletion() throws {
        let db = makeDatabase()
        try db.connect()
        let exercise = try XCTUnwrap(try db.getAllExercises().first { $0.unit == .weight })
        let service = PRService(personalRecordRepository: db, exerciseRepository: db, workoutRepository: db)
        let first = workout(exercise: exercise, sets: [ExerciseSet(setNumber: 1, weight: 80, reps: 5, isCompleted: true)])
        let second = workout(exercise: exercise, sets: [ExerciseSet(setNumber: 1, weight: 120, reps: 3, isCompleted: true)])

        try db.saveWorkout(first)
        try db.saveWorkout(second)
        try service.rebuildAllPersonalRecords()
        XCTAssertEqual(try db.getPersonalRecords(for: exercise.id).first { $0.prType == .maxWeight }?.value, 120)

        try db.deleteWorkout(second.id)
        try service.rebuildAllPersonalRecords()
        XCTAssertEqual(try db.getPersonalRecords(for: exercise.id).first { $0.prType == .maxWeight }?.value, 80)
    }

    private func makeDatabase() -> DatabaseManager {
        DatabaseManager(databaseURL: temporaryDirectory.appendingPathComponent("fitrock.sqlite3"))
    }

    private func workout(exercise: Exercise, sets: [ExerciseSet]) -> Workout {
        Workout(
            startTime: Date(),
            endTime: Date(),
            exercises: [
                WorkoutExercise(
                    exerciseId: exercise.id,
                    exerciseName: exercise.name,
                    bodyPart: exercise.bodyPart,
                    sets: sets
                )
            ],
            isCompleted: true
        )
    }
}
