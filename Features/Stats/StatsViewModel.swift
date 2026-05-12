import SwiftUI
import Combine

final class StatsViewModel: ObservableObject {
    @Published var workoutCount = 0
    @Published var totalVolume: Double = 0
    @Published var totalSets = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var bodyPartData: [BodyPartStat] = []
    @Published var exerciseRanking: [ExerciseRankItem] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var workouts: [Workout] = []

    private let db = DatabaseManager.shared

    var formattedTotalDuration: String {
        let minutes = Int(totalDuration) / 60
        if minutes < 60 {
            return "\(minutes)分钟"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)小时\(remainingMinutes)分钟"
        }
    }

    func loadStats(for period: StatsPeriod) {
        do {
            try db.connect()

            // Use database-level filtering instead of loading all into memory
            let filteredWorkouts: [Workout]
            let now = Date()
            let calendar = Calendar.current

            switch period {
            case .week:
                filteredWorkouts = try db.getWorkouts(from: calendar.date(byAdding: .day, value: -7, to: now)!)
            case .month:
                filteredWorkouts = try db.getWorkouts(from: calendar.date(byAdding: .month, value: -1, to: now)!)
            case .all:
                filteredWorkouts = try db.getCompletedWorkouts(limit: 100) // Limit to prevent OOM
            }

            let allWorkouts = try db.getCompletedWorkouts(limit: 100)
            calculateStats(from: filteredWorkouts, allWorkouts: allWorkouts)
            workouts = Array(filteredWorkouts.prefix(10))
        } catch {
            print("Error loading stats: \(error)")
            resetStats()
        }
    }

    private func calculateStats(from workouts: [Workout], allWorkouts: [Workout]) {
        workoutCount = workouts.count
        totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }
        totalSets = workouts.reduce(0) { $0 + $1.totalSets }
        totalDuration = workouts.reduce(0) { $0 + $1.duration }

        calculateBodyPartStats(from: workouts)
        calculateExerciseRanking(from: workouts)
        calculatePersonalRecords(from: allWorkouts)
    }

    private func calculateBodyPartStats(from workouts: [Workout]) {
        var bodyPartVolumes: [BodyPart: Double] = [:]

        for workout in workouts {
            for we in workout.exercises {
                let volume = we.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                bodyPartVolumes[we.bodyPart, default: 0] += volume
            }
        }

        let total = bodyPartVolumes.values.reduce(0, +)

        bodyPartData = bodyPartVolumes.map { bp, volume in
            BodyPartStat(bodyPart: bp, volume: volume, percentage: total > 0 ? (volume / total) * 100 : 0)
        }.sorted { $0.volume > $1.volume }
    }

    private func calculateExerciseRanking(from workouts: [Workout]) {
        var exerciseVolumes: [String: (name: String, volume: Double)] = [:]

        for workout in workouts {
            for we in workout.exercises {
                let volume = we.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                let current = exerciseVolumes[we.exerciseName]?.volume ?? 0
                exerciseVolumes[we.exerciseName] = (name: we.exerciseName, volume: current + volume)
            }
        }

        exerciseRanking = exerciseVolumes.values
            .sorted { $0.volume > $1.volume }
            .prefix(10)
            .map { ExerciseRankItem(name: $0.name, volume: $0.volume) }
    }

    private func calculatePersonalRecords(from workouts: [Workout]) {
        var exerciseMaxWeight: [String: (weight: Double, date: Date, exerciseName: String)] = [:]

        for workout in workouts {
            for we in workout.exercises {
                for set in we.sets {
                    if set.setType == .normal && set.weight > 0 {
                        let current = exerciseMaxWeight[we.exerciseName]
                        if current == nil || set.weight > current!.weight {
                            exerciseMaxWeight[we.exerciseName] = (weight: set.weight, date: workout.startTime, exerciseName: we.exerciseName)
                        }
                    }
                }
            }
        }

        personalRecords = exerciseMaxWeight.values
            .sorted { $0.weight > $1.weight }
            .prefix(5)
            .map { pr in
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日"
                return PersonalRecord(
                    exerciseName: pr.exerciseName,
                    maxWeight: pr.weight,
                    date: formatter.string(from: pr.date)
                )
            }
    }

    private func resetStats() {
        workoutCount = 0
        totalVolume = 0
        totalSets = 0
        totalDuration = 0
        bodyPartData = []
        exerciseRanking = []
        personalRecords = []
        workouts = []
    }

    func deleteWorkout(_ workoutId: String) {
        do {
            try db.connect()
            try db.deleteWorkout(workoutId)
            loadStats(for: .week)
            Haptic.medium.trigger()
        } catch {
            print("Error deleting workout: \(error)")
        }
    }
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

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let maxWeight: Double
    let date: String
}

enum StatsPeriod: String, CaseIterable {
    case week = "本周"
    case month = "本月"
    case all = "全部"
}
