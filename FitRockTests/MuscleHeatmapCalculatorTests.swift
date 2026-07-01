import XCTest
@testable import FitRock

final class MuscleHeatmapCalculatorTests: XCTestCase {
    func testDbExerciseMapsToSpecificMuscles() {
        let workout = Workout(
            startTime: Date(),
            endTime: Date(),
            exercises: [
                WorkoutExercise(
                    exerciseId: "bench",
                    exerciseName: "杠铃卧推",
                    bodyPart: .chest,
                    sets: [ExerciseSet(setNumber: 1, weight: 100, reps: 5, isCompleted: true)]
                )
            ],
            isCompleted: true
        )

        let summary = MuscleHeatmapCalculator().calculate(workouts: [workout], period: .all)

        XCTAssertTrue(summary.rawVolumes[.chest, default: 0] > 0)
        XCTAssertTrue(summary.rawVolumes[.triceps, default: 0] > 0)
        XCTAssertGreaterThan(summary.rawVolumes[.chest, default: 0], summary.rawVolumes[.triceps, default: 0])
    }

    func testPeriodFiltersOlderWorkouts() {
        let now = Date()
        let recent = Workout(startTime: now, endTime: now, exercises: [
            WorkoutExercise(exerciseId: "squat", exerciseName: "深蹲", bodyPart: .legs, sets: [
                ExerciseSet(setNumber: 1, weight: 100, reps: 5, isCompleted: true)
            ])
        ], isCompleted: true)
        let old = Workout(startTime: now.addingTimeInterval(-40 * 24 * 3600), endTime: now, exercises: [
            WorkoutExercise(exerciseId: "bench", exerciseName: "杠铃卧推", bodyPart: .chest, sets: [
                ExerciseSet(setNumber: 1, weight: 100, reps: 5, isCompleted: true)
            ])
        ], isCompleted: true)

        let summary = MuscleHeatmapCalculator().calculate(workouts: [recent, old], period: .month, now: now)

        XCTAssertTrue(summary.rawVolumes[.quadriceps, default: 0] > 0)
        XCTAssertEqual(summary.rawVolumes[.chest, default: 0], 0)
    }

    func testJsonMuscleMappingWeightsPrimaryAndSecondary() {
        let info = ExerciseInfo(
            id: "row",
            nameEn: "Row",
            nameZh: "划船",
            equipmentId: nil,
            equipmentType: nil,
            primaryMuscles: ["middle back"],
            primaryMusclesZh: ["中背部"],
            secondaryMuscles: ["biceps"],
            secondaryMusclesZh: ["肱二头肌"],
            images: [],
            stepsZh: [],
            commonMistakesZh: [],
            difficulty: "新手友好"
        )

        let mapping = ExerciseMuscleMappingProvider.mapping(for: info)

        XCTAssertTrue(mapping.primaryMuscles.contains(.rhomboids))
        XCTAssertTrue(mapping.secondaryMuscles.contains(.biceps))
    }
}
