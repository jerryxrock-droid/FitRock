import Foundation

struct TrainingPlanCompletionMatcher {
    func completion(plan: TrainingPlan) -> TrainingPlanCompletion {
        let days = plan.weeks.flatMap(\.days)
        return TrainingPlanCompletion(
            completed: days.filter { $0.status == .completed }.count,
            skipped: days.filter { $0.status == .skipped }.count,
            planned: days.filter { $0.status == .planned || $0.status == .moved }.count,
            rest: days.filter { $0.status == .rest }.count
        )
    }

    func matchCompletedWorkout(_ workout: Workout, in plan: TrainingPlan, calendar: Calendar = .current) -> (dayId: String, status: TrainingPlanDayStatus)? {
        guard workout.isCompleted else { return nil }
        if workout.trainingPlanId == plan.id,
           let plannedDayId = workout.plannedDayId,
           plan.weeks.flatMap(\.days).contains(where: { $0.id == plannedDayId && $0.status != .rest }) {
            return (plannedDayId, .completed)
        }

        let workoutBodyParts = Set(workout.exercises.map(\.bodyPart))
        guard !workoutBodyParts.isEmpty,
              let week = WeeklyPlanResolver().resolve(plan: plan, date: workout.startTime, calendar: calendar) else {
            return nil
        }

        return week.sessions
            .filter { $0.status == .planned || $0.status == .moved }
            .map { day -> (day: TrainingPlanDay, score: Int) in
                let targets = Set(day.targetBodyParts)
                return (day, targets.intersection(workoutBodyParts).count)
            }
            .filter { $0.score > 0 }
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return ($0.day.sequenceIndex ?? Int.max) < ($1.day.sequenceIndex ?? Int.max)
            }
            .first
            .map { ($0.day.id, .completed) }
    }
}
