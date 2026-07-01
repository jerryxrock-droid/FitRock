import XCTest
@testable import FitRock

final class ExerciseCatalogHistoryResolverTests: XCTestCase {
    func testDbItemMatchesHistoryByExerciseId() {
        let workout = completedWorkout(exerciseId: "bench", exerciseName: "旧名称", bodyPart: .chest)
        let item = ExerciseCatalogItem(
            catalogId: "db:bench",
            source: .db,
            dbExerciseId: "bench",
            jsonExerciseId: nil,
            nameZh: "杠铃卧推",
            nameEn: nil,
            bodyPart: .chest,
            unit: .weight,
            equipmentId: nil,
            equipmentNameZh: nil,
            equipmentNameEn: nil,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            isUserCreated: false,
            images: []
        )

        let summary = ExerciseCatalogHistoryResolver().resolve(item: item, workouts: [workout], personalRecords: [])

        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.totalSets, 1)
    }

    func testJsonItemMatchesHistoryByChineseOrEnglishName() {
        let workout = completedWorkout(exerciseId: "legacy", exerciseName: "Seated Cable Row", bodyPart: .back)
        let item = ExerciseCatalogItem(
            catalogId: "json:row",
            source: .json,
            dbExerciseId: nil,
            jsonExerciseId: "row",
            nameZh: "坐姿绳索划船",
            nameEn: "Seated Cable Row",
            bodyPart: .back,
            unit: .weight,
            equipmentId: "cable-row",
            equipmentNameZh: "坐姿划船机",
            equipmentNameEn: "Cable Row",
            primaryMuscles: [.upperBack],
            secondaryMuscles: [.biceps],
            isUserCreated: false,
            images: []
        )

        let summary = ExerciseCatalogHistoryResolver().resolve(item: item, workouts: [workout], personalRecords: [])

        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertTrue(summary.relatedMuscles.contains(.biceps))
        XCTAssertTrue(summary.relatedMuscles.contains(.upperBack))
    }

    func testNoHistoryKeepsCatalogMuscles() {
        let item = ExerciseCatalogItem(
            catalogId: "json:no-history",
            source: .json,
            dbExerciseId: nil,
            jsonExerciseId: "no-history",
            nameZh: "无历史动作",
            nameEn: "No History",
            bodyPart: .legs,
            unit: .weight,
            equipmentId: nil,
            equipmentNameZh: nil,
            equipmentNameEn: nil,
            primaryMuscles: [.quadriceps],
            secondaryMuscles: [.gluteal],
            isUserCreated: false,
            images: []
        )

        let summary = ExerciseCatalogHistoryResolver().resolve(item: item, workouts: [], personalRecords: [])

        XCTAssertEqual(summary.workoutCount, 0)
        XCTAssertEqual(summary.relatedMuscles, [.gluteal, .quadriceps])
    }

    private func completedWorkout(exerciseId: String, exerciseName: String, bodyPart: BodyPart) -> Workout {
        var workout = Workout(startTime: Date(timeIntervalSince1970: 1_700_000_000))
        workout.endTime = workout.startTime.addingTimeInterval(3_600)
        workout.isCompleted = true
        workout.exercises = [
            WorkoutExercise(
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                bodyPart: bodyPart,
                sets: [ExerciseSet(setNumber: 1, weight: 50, reps: 10, isCompleted: true)]
            )
        ]
        return workout
    }
}
