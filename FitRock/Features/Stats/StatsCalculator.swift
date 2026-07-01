import Foundation

struct StatsSummary {
    let workoutCount: Int
    let totalVolume: Double
    let totalSets: Int
    let totalDuration: TimeInterval
    let bodyPartData: [BodyPartStat]
    let exerciseRanking: [ExerciseRankItem]
    let recentWorkouts: [Workout]
}

struct BodyPartStat: Identifiable {
    let id = UUID()
    let bodyPart: BodyPart
    let volume: Double
    let percentage: Double
}

struct ExerciseRankItem: Identifiable {
    let id = UUID()
    let name: String
    let volume: Double
}

enum StatsPeriod: String, CaseIterable {
    case week = "本周"
    case month = "本月"
    case all = "全部"
}

struct StatsCalculator {
    func calculate(from allWorkouts: [Workout], period: StatsPeriod, now: Date = Date(), calendar: Calendar = .current) -> StatsSummary {
        let filteredWorkouts = filter(allWorkouts, for: period, now: now, calendar: calendar)

        return StatsSummary(
            workoutCount: filteredWorkouts.count,
            totalVolume: filteredWorkouts.reduce(0) { $0 + $1.totalVolume },
            totalSets: filteredWorkouts.reduce(0) { $0 + $1.totalSets },
            totalDuration: filteredWorkouts.reduce(0) { $0 + $1.duration },
            bodyPartData: calculateBodyPartStats(from: filteredWorkouts),
            exerciseRanking: calculateExerciseRanking(from: filteredWorkouts),
            recentWorkouts: Array(filteredWorkouts.prefix(10))
        )
    }

    private func filter(_ workouts: [Workout], for period: StatsPeriod, now: Date, calendar: Calendar) -> [Workout] {
        switch period {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return workouts.filter { $0.startTime >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return workouts.filter { $0.startTime >= monthAgo }
        case .all:
            return workouts
        }
    }

    private func calculateBodyPartStats(from workouts: [Workout]) -> [BodyPartStat] {
        var bodyPartVolumes: [BodyPart: Double] = [:]

        for workout in workouts {
            for workoutExercise in workout.exercises {
                let volume = workoutExercise.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                bodyPartVolumes[workoutExercise.bodyPart, default: 0] += volume
            }
        }

        let total = bodyPartVolumes.values.reduce(0, +)

        return bodyPartVolumes.map { bodyPart, volume in
            BodyPartStat(
                bodyPart: bodyPart,
                volume: volume,
                percentage: total > 0 ? (volume / total) * 100 : 0
            )
        }.sorted { $0.volume > $1.volume }
    }

    private func calculateExerciseRanking(from workouts: [Workout]) -> [ExerciseRankItem] {
        var exerciseVolumes: [String: (name: String, volume: Double)] = [:]

        for workout in workouts {
            for workoutExercise in workout.exercises {
                let volume = workoutExercise.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                let current = exerciseVolumes[workoutExercise.exerciseName]?.volume ?? 0
                exerciseVolumes[workoutExercise.exerciseName] = (name: workoutExercise.exerciseName, volume: current + volume)
            }
        }

        return exerciseVolumes.values
            .sorted { $0.volume > $1.volume }
            .prefix(10)
            .map { ExerciseRankItem(name: $0.name, volume: $0.volume) }
    }
}
