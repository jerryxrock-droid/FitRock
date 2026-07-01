import XCTest
@testable import FitRock

final class ExerciseHistoryTests: XCTestCase {
    func testAggregatesHistoryByExerciseId() {
        let exerciseId = "bench"
        let workout = Workout(startTime: Date(), endTime: Date(), exercises: [
            WorkoutExercise(exerciseId: exerciseId, exerciseName: "杠铃卧推", bodyPart: .chest, sets: [
                ExerciseSet(setNumber: 1, weight: 100, reps: 5, isCompleted: true)
            ]),
            WorkoutExercise(exerciseId: "squat", exerciseName: "深蹲", bodyPart: .legs, sets: [
                ExerciseSet(setNumber: 1, weight: 120, reps: 5, isCompleted: true)
            ])
        ], isCompleted: true)
        let pr = PersonalRecord(
            id: 1,
            exerciseId: exerciseId,
            exerciseName: "杠铃卧推",
            bodyPart: .chest,
            prType: .maxWeight,
            value: 100,
            weight: 100,
            reps: 5,
            volume: nil,
            workoutId: workout.id,
            workoutExerciseId: nil,
            setId: nil,
            achievedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )

        let summary = ExerciseHistoryCalculator().calculate(
            exerciseId: exerciseId,
            exerciseName: "杠铃卧推",
            bodyPart: .chest,
            workouts: [workout],
            personalRecords: [pr]
        )

        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.totalSets, 1)
        XCTAssertEqual(summary.personalRecords.first?.value, 100)
        XCTAssertTrue(summary.relatedMuscles.contains(.chest))
    }

    func testEmptyHistoryKeepsMuscleFallback() {
        let summary = ExerciseHistoryCalculator().calculate(
            exerciseId: "missing",
            exerciseName: "自定义动作",
            bodyPart: .arms,
            workouts: [],
            personalRecords: []
        )

        XCTAssertEqual(summary.workoutCount, 0)
        XCTAssertTrue(summary.relatedMuscles.contains(.biceps))
    }
}
