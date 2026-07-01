import XCTest
@testable import FitRock

final class TrainingPlanCompletionTests: XCTestCase {
    func testMatchesWorkoutBySameDayAndTargetBodyPart() {
        let date = Date()
        let day = TrainingPlanDay(
            date: date,
            title: "Push",
            targetBodyParts: [.chest],
            suggestedExerciseNames: ["杠铃卧推"]
        )
        let plan = TrainingPlan(
            name: "Plan",
            goal: .hypertrophy,
            trainingDaysPerWeek: 4,
            recommendationReason: "",
            startDate: date,
            endDate: date,
            weeks: [TrainingPlanWeek(weekIndex: 1, days: [day])]
        )
        let workout = Workout(startTime: date, endTime: date, exercises: [
            WorkoutExercise(exerciseId: "bench", exerciseName: "杠铃卧推", bodyPart: .chest)
        ], isCompleted: true)

        let match = TrainingPlanCompletionMatcher().matchCompletedWorkout(workout, in: plan)

        XCTAssertEqual(match?.dayId, day.id)
        XCTAssertEqual(match?.status, .completed)
    }

    func testExplicitPlanDayMatchTakesPriorityOverBodyPartGuessing() {
        let date = Date()
        let plannedDay = TrainingPlanDay(
            id: "planned-day",
            date: date,
            title: "Push",
            targetBodyParts: [.chest],
            suggestedExerciseNames: ["杠铃卧推"]
        )
        let otherDay = TrainingPlanDay(
            id: "same-day-back",
            date: date,
            title: "Pull",
            targetBodyParts: [.back],
            suggestedExerciseNames: ["坐姿划船"]
        )
        let plan = TrainingPlan(
            id: "plan-1",
            name: "Plan",
            goal: .hypertrophy,
            trainingDaysPerWeek: 2,
            recommendationReason: "",
            startDate: date,
            endDate: date,
            weeks: [TrainingPlanWeek(weekIndex: 1, days: [otherDay, plannedDay])]
        )
        let workout = Workout(
            startTime: date,
            endTime: date,
            exercises: [WorkoutExercise(exerciseId: "row", exerciseName: "坐姿划船", bodyPart: .back)],
            isCompleted: true,
            trainingPlanId: "plan-1",
            plannedDayId: "planned-day"
        )

        let match = TrainingPlanCompletionMatcher().matchCompletedWorkout(workout, in: plan)

        XCTAssertEqual(match?.dayId, "planned-day")
        XCTAssertEqual(match?.status, .completed)
    }

    func testWeeklyPlanResolverReturnsCurrentWeekAndRecommendedSession() {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: today)!
        let firstSession = TrainingPlanDay(
            date: today,
            sequenceIndex: 1,
            availableFrom: today,
            availableUntil: weekEnd,
            title: "Push",
            targetBodyParts: [.chest],
            suggestedExerciseNames: []
        )
        let secondSession = TrainingPlanDay(
            date: today,
            sequenceIndex: 2,
            availableFrom: today,
            availableUntil: weekEnd,
            title: "Pull",
            targetBodyParts: [.back],
            suggestedExerciseNames: []
        )
        let plan = TrainingPlan(
            name: "Plan",
            goal: .hypertrophy,
            trainingDaysPerWeek: 2,
            recommendationReason: "",
            startDate: today,
            endDate: weekEnd,
            weeks: [TrainingPlanWeek(weekIndex: 1, days: [
                firstSession,
                secondSession
            ])]
        )

        let result = WeeklyPlanResolver().resolve(plan: plan, date: today, calendar: calendar)

        XCTAssertEqual(result?.plan.id, plan.id)
        XCTAssertEqual(result?.recommendedSession?.id, firstSession.id)
        XCTAssertEqual(result?.totalCount, 2)
    }

    func testFreeWorkoutMatchesBestCurrentWeekSessionByBodyPartOverlap() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        let push = TrainingPlanDay(date: start, sequenceIndex: 1, availableFrom: start, availableUntil: end, title: "Push", targetBodyParts: [.chest], suggestedExerciseNames: [])
        let fullBody = TrainingPlanDay(date: start, sequenceIndex: 2, availableFrom: start, availableUntil: end, title: "Full", targetBodyParts: [.chest, .back], suggestedExerciseNames: [])
        let plan = TrainingPlan(
            name: "Plan",
            goal: .hypertrophy,
            trainingDaysPerWeek: 2,
            recommendationReason: "",
            startDate: start,
            endDate: end,
            weeks: [TrainingPlanWeek(weekIndex: 1, days: [push, fullBody])]
        )
        let workout = Workout(startTime: start, endTime: start, exercises: [
            WorkoutExercise(exerciseId: "bench", exerciseName: "杠铃卧推", bodyPart: .chest),
            WorkoutExercise(exerciseId: "row", exerciseName: "坐姿划船", bodyPart: .back)
        ], isCompleted: true)

        let match = TrainingPlanCompletionMatcher().matchCompletedWorkout(workout, in: plan, calendar: calendar)

        XCTAssertEqual(match?.dayId, fullBody.id)
    }

    func testCompletionRateIgnoresRestDays() {
        let date = Date()
        let plan = TrainingPlan(
            name: "Plan",
            goal: .hypertrophy,
            trainingDaysPerWeek: 2,
            recommendationReason: "",
            startDate: date,
            endDate: date,
            weeks: [TrainingPlanWeek(weekIndex: 1, days: [
                TrainingPlanDay(date: date, title: "A", targetBodyParts: [.chest], suggestedExerciseNames: [], status: .completed),
                TrainingPlanDay(date: date, title: "B", targetBodyParts: [.legs], suggestedExerciseNames: [], status: .planned),
                TrainingPlanDay(date: date, title: "休息", targetBodyParts: [], suggestedExerciseNames: [], status: .rest)
            ])]
        )

        let completion = TrainingPlanCompletionMatcher().completion(plan: plan)

        XCTAssertEqual(completion.completed, 1)
        XCTAssertEqual(completion.rest, 1)
        XCTAssertEqual(completion.completionRate, 0.5)
    }
}
