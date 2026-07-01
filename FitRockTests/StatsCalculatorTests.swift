import XCTest
@testable import FitRock

final class StatsCalculatorTests: XCTestCase {
    func testCalculatesTotalsAndRankingsForAllWorkouts() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let workouts = [
            workout(
                start: now.addingTimeInterval(-3600),
                exercises: [
                    workoutExercise(name: "杠铃卧推", bodyPart: .chest, sets: [
                        set(weight: 100, reps: 5),
                        set(weight: 80, reps: 8, type: .warmup),
                        set(weight: 90, reps: 6, type: .dropSet)
                    ])
                ]
            ),
            workout(
                start: now.addingTimeInterval(-7200),
                exercises: [
                    workoutExercise(name: "深蹲", bodyPart: .legs, sets: [
                        set(weight: 120, reps: 5)
                    ])
                ]
            )
        ]

        let summary = StatsCalculator().calculate(from: workouts, period: .all, now: now)

        XCTAssertEqual(summary.workoutCount, 2)
        XCTAssertEqual(summary.totalSets, 3)
        XCTAssertEqual(summary.totalVolume, 2280)
        XCTAssertEqual(summary.bodyPartData.first?.bodyPart, .chest)
        XCTAssertEqual(summary.exerciseRanking.first?.name, "杠铃卧推")
    }

    func testFiltersWeekAndMonthPeriods() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let workouts = [
            workout(start: now.addingTimeInterval(-2 * 24 * 3600)),
            workout(start: now.addingTimeInterval(-10 * 24 * 3600)),
            workout(start: now.addingTimeInterval(-40 * 24 * 3600))
        ]

        let calculator = StatsCalculator()

        XCTAssertEqual(calculator.calculate(from: workouts, period: .week, now: now, calendar: calendar).workoutCount, 1)
        XCTAssertEqual(calculator.calculate(from: workouts, period: .month, now: now, calendar: calendar).workoutCount, 2)
        XCTAssertEqual(calculator.calculate(from: workouts, period: .all, now: now, calendar: calendar).workoutCount, 3)
    }

    private func workout(start: Date, exercises: [WorkoutExercise] = []) -> Workout {
        Workout(startTime: start, endTime: start.addingTimeInterval(3600), exercises: exercises, isCompleted: true)
    }

    private func workoutExercise(name: String, bodyPart: BodyPart, sets: [ExerciseSet]) -> WorkoutExercise {
        WorkoutExercise(exerciseId: name, exerciseName: name, bodyPart: bodyPart, sets: sets)
    }

    private func set(weight: Double, reps: Int, type: ExerciseSetType = .normal) -> ExerciseSet {
        ExerciseSet(setNumber: 1, weight: weight, reps: reps, setType: type, isCompleted: true)
    }
}
