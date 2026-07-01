import Foundation

enum HeatmapPeriod: String, CaseIterable {
    case week = "近7天"
    case month = "近30天"
    case quarter = "近90天"
    case all = "全部"

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .week:
            return date >= (calendar.date(byAdding: .day, value: -7, to: now) ?? now)
        case .month:
            return date >= (calendar.date(byAdding: .day, value: -30, to: now) ?? now)
        case .quarter:
            return date >= (calendar.date(byAdding: .day, value: -90, to: now) ?? now)
        case .all:
            return true
        }
    }
}

struct MuscleHeatmapSummary {
    let intensities: [MuscleIntensity]
    let overloaded: [Muscle]
    let missing: [Muscle]
    let rawVolumes: [Muscle: Double]
}

struct MuscleHeatmapCalculator {
    func calculate(workouts: [Workout], period: HeatmapPeriod, now: Date = Date()) -> MuscleHeatmapSummary {
        let filtered = workouts.filter { $0.isCompleted && period.contains($0.startTime, now: now) }
        var volumes: [Muscle: Double] = [:]

        for workout in filtered {
            for workoutExercise in workout.exercises {
                let mapping = ExerciseMuscleMappingProvider.mapping(for: workoutExercise)
                let load = trainingLoad(for: workoutExercise)
                for muscle in mapping.primaryMuscles {
                    volumes[muscle, default: 0] += load
                }
                for muscle in mapping.secondaryMuscles {
                    volumes[muscle, default: 0] += load * 0.4
                }
            }
        }

        let maxVolume = volumes.values.max() ?? 0
        let intensities = volumes
            .filter { $0.value > 0 && !$0.key.isCosmeticPart }
            .map { muscle, volume in
                MuscleIntensity(muscle: muscle, intensity: maxVolume > 0 ? volume / maxVolume : 0)
            }
            .sorted { $0.intensity > $1.intensity }

        let trainable = Muscle.allCases.filter { !$0.isCosmeticPart && $0 != .hands && $0 != .feet && $0 != .knees && $0 != .ankles && $0 != .neck }
        let average = volumes.values.isEmpty ? 0 : volumes.values.reduce(0, +) / Double(volumes.values.count)
        let overloaded = intensities.prefix(4).map(\.muscle)
        let missing = trainable
            .filter { (volumes[$0] ?? 0) < max(average * 0.5, 1) }
            .prefix(5)
            .map { $0 }

        return MuscleHeatmapSummary(
            intensities: intensities,
            overloaded: overloaded,
            missing: missing,
            rawVolumes: volumes
        )
    }

    func trainingLoad(for workoutExercise: WorkoutExercise) -> Double {
        workoutExercise.sets
            .filter { $0.isCompleted }
            .reduce(0) { total, set in
                if set.weight > 0 && set.reps > 0 {
                    return total + set.weight * Double(set.reps)
                }
                if set.weight > 0 {
                    return total + set.weight
                }
                return total + Double(max(set.reps, 0))
            }
    }
}
