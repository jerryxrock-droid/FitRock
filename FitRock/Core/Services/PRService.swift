import Foundation

final class PRService {
    static let shared = PRService()
    private let db = DatabaseManager.shared

    private var tempIdCounter: Int64 = 0

    private init() {}

    /// Evaluate a workout and return any new PR events without saving
    func evaluate(workout: Workout) throws -> [PersonalRecordEvent] {
        var events: [PersonalRecordEvent] = []

        for we in workout.exercises {
            let exercise = try db.getExercise(by: we.exerciseId)
            try evaluateExercise(workoutExercise: we, unit: exercise?.unit ?? .weight, workout: workout, events: &events)
        }

        return events
    }

    /// Evaluate a workout, save PRs and events to DB, return new PR events
    func evaluateAndSave(workout: Workout) throws -> [PersonalRecordEvent] {
        let events = try evaluate(workout: workout)

        for event in events {
            let record = PersonalRecord(
                id: 0,
                exerciseId: event.exerciseId,
                exerciseName: event.exerciseName,
                bodyPart: event.bodyPart,
                prType: event.prType,
                value: event.newValue,
                weight: event.weight,
                reps: event.reps,
                volume: event.prType == .exerciseVolume ? event.newValue : nil,
                workoutId: event.workoutId,
                workoutExerciseId: event.workoutExerciseId,
                setId: event.setId,
                achievedAt: event.achievedAt,
                createdAt: Date(),
                updatedAt: Date()
            )
            try db.savePersonalRecord(record)
            try db.savePersonalRecordEvent(event)
        }

        return events
    }

    /// Rebuild all personal records from scratch (used after workout deletion)
    func rebuildAllPersonalRecords() throws {
        try db.clearAllPersonalRecords()

        let allWorkouts = try db.getAllCompletedWorkouts()

        var bestMaxWeight: [String: (value: Double, set: ExerciseSet, workout: Workout, we: WorkoutExercise)] = [:]
        var bestVolume: [String: (value: Double, workout: Workout, we: WorkoutExercise)] = [:]
        var bestDuration: [String: (value: Double, set: ExerciseSet, workout: Workout, we: WorkoutExercise)] = [:]

        for workout in allWorkouts {
            for we in workout.exercises {
                let completedSets = we.sets.filter { $0.isCompleted }
                guard !completedSets.isEmpty else { continue }

                let key = we.exerciseId
                let workingSets = completedSets.filter { $0.setType != .warmup }
                let exercise = try db.getExercise(by: we.exerciseId)
                let unit = exercise?.unit ?? .weight

                switch unit {
                case .weight:
                    // Max weight - best working set by weight
                    if let maxSet = workingSets.max(by: { $0.weight < $1.weight }), maxSet.weight > 0 {
                        if bestMaxWeight[key] == nil || maxSet.weight > bestMaxWeight[key]!.value {
                            bestMaxWeight[key] = (maxSet.weight, maxSet, workout, we)
                        }
                    }
                    // Volume - sum of ALL completed sets
                    let totalVolume = completedSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                    if totalVolume > 0 {
                        if bestVolume[key] == nil || totalVolume > bestVolume[key]!.value {
                            bestVolume[key] = (totalVolume, workout, we)
                        }
                    }

                case .reps:
                    // Volume - sum of ALL completed sets
                    let totalVolume = completedSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                    if totalVolume > 0 {
                        if bestVolume[key] == nil || totalVolume > bestVolume[key]!.value {
                            bestVolume[key] = (totalVolume, workout, we)
                        }
                    }

                case .duration:
                    // Duration - best working set by weight (which stores duration value)
                    if let maxSet = workingSets.max(by: { $0.weight < $1.weight }), maxSet.weight > 0 {
                        if bestDuration[key] == nil || maxSet.weight > bestDuration[key]!.value {
                            bestDuration[key] = (maxSet.weight, maxSet, workout, we)
                        }
                    }
                }
            }
        }

        let now = Date()

        for (exerciseId, data) in bestMaxWeight {
            let record = PersonalRecord(
                id: 0,
                exerciseId: exerciseId,
                exerciseName: data.we.exerciseName,
                bodyPart: data.we.bodyPart,
                prType: .maxWeight,
                value: data.value,
                weight: data.set.weight,
                reps: data.set.reps,
                volume: nil,
                workoutId: data.workout.id,
                workoutExerciseId: data.we.id,
                setId: data.set.id,
                achievedAt: data.workout.endTime ?? data.workout.startTime,
                createdAt: now,
                updatedAt: now
            )
            try db.savePersonalRecord(record)
        }

        for (exerciseId, data) in bestVolume {
            let record = PersonalRecord(
                id: 0,
                exerciseId: exerciseId,
                exerciseName: data.we.exerciseName,
                bodyPart: data.we.bodyPart,
                prType: .exerciseVolume,
                value: data.value,
                weight: nil,
                reps: nil,
                volume: data.value,
                workoutId: data.workout.id,
                workoutExerciseId: data.we.id,
                setId: nil,
                achievedAt: data.workout.endTime ?? data.workout.startTime,
                createdAt: now,
                updatedAt: now
            )
            try db.savePersonalRecord(record)
        }

        for (exerciseId, data) in bestDuration {
            let record = PersonalRecord(
                id: 0,
                exerciseId: exerciseId,
                exerciseName: data.we.exerciseName,
                bodyPart: data.we.bodyPart,
                prType: .duration,
                value: data.value,
                weight: data.set.weight,
                reps: data.set.reps,
                volume: nil,
                workoutId: data.workout.id,
                workoutExerciseId: data.we.id,
                setId: data.set.id,
                achievedAt: data.workout.endTime ?? data.workout.startTime,
                createdAt: now,
                updatedAt: now
            )
            try db.savePersonalRecord(record)
        }
    }

    // MARK: - Private

    private func evaluateExercise(workoutExercise we: WorkoutExercise, unit: ExerciseUnit, workout: Workout, events: inout [PersonalRecordEvent]) throws {
        let completedSets = we.sets.filter { $0.isCompleted }
        guard !completedSets.isEmpty else { return }

        let key = we.exerciseId
        let now = Date()
        let achievedAt = workout.endTime ?? now
        let workingSets = completedSets.filter { $0.setType != .warmup }

        switch unit {
        case .weight:
            // Max weight - best working set by weight
            if let maxSet = workingSets.max(by: { $0.weight < $1.weight }), maxSet.weight > 0 {
                let currentBest = try db.getPersonalRecords(for: key)
                    .first { $0.prType == .maxWeight }

                if currentBest == nil || maxSet.weight > currentBest!.value {
                    let event = PersonalRecordEvent(
                        id: nextTempId(),
                        exerciseId: key,
                        exerciseName: we.exerciseName,
                        bodyPart: we.bodyPart,
                        prType: .maxWeight,
                        oldValue: currentBest?.value,
                        newValue: maxSet.weight,
                        weight: maxSet.weight,
                        reps: maxSet.reps,
                        volume: nil,
                        workoutId: workout.id,
                        workoutExerciseId: we.id,
                        setId: maxSet.id,
                        achievedAt: achievedAt,
                        createdAt: now
                    )
                    events.append(event)
                }
            }

            // Volume - sum of ALL completed sets (including dropsets)
            let totalVolume = completedSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
            if totalVolume > 0 {
                let currentBest = try db.getPersonalRecords(for: key)
                    .first { $0.prType == .exerciseVolume }

                if currentBest == nil || totalVolume > currentBest!.value {
                    let event = PersonalRecordEvent(
                        id: nextTempId(),
                        exerciseId: key,
                        exerciseName: we.exerciseName,
                        bodyPart: we.bodyPart,
                        prType: .exerciseVolume,
                        oldValue: currentBest?.value,
                        newValue: totalVolume,
                        weight: nil,
                        reps: nil,
                        volume: totalVolume,
                        workoutId: workout.id,
                        workoutExerciseId: we.id,
                        setId: nil,
                        achievedAt: achievedAt,
                        createdAt: now
                    )
                    events.append(event)
                }
            }

        case .reps:
            // Volume - sum of ALL completed sets
            let totalVolume = completedSets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
            if totalVolume > 0 {
                let currentBest = try db.getPersonalRecords(for: key)
                    .first { $0.prType == .exerciseVolume }

                if currentBest == nil || totalVolume > currentBest!.value {
                    let event = PersonalRecordEvent(
                        id: nextTempId(),
                        exerciseId: key,
                        exerciseName: we.exerciseName,
                        bodyPart: we.bodyPart,
                        prType: .exerciseVolume,
                        oldValue: currentBest?.value,
                        newValue: totalVolume,
                        weight: nil,
                        reps: nil,
                        volume: totalVolume,
                        workoutId: workout.id,
                        workoutExerciseId: we.id,
                        setId: nil,
                        achievedAt: achievedAt,
                        createdAt: now
                    )
                    events.append(event)
                }
            }

        case .duration:
            // Duration - best working set by weight (stores seconds value)
            if let maxSet = workingSets.max(by: { $0.weight < $1.weight }), maxSet.weight > 0 {
                let currentBest = try db.getPersonalRecords(for: key)
                    .first { $0.prType == .duration }

                if currentBest == nil || maxSet.weight > currentBest!.value {
                    let event = PersonalRecordEvent(
                        id: nextTempId(),
                        exerciseId: key,
                        exerciseName: we.exerciseName,
                        bodyPart: we.bodyPart,
                        prType: .duration,
                        oldValue: currentBest?.value,
                        newValue: maxSet.weight,
                        weight: maxSet.weight,
                        reps: maxSet.reps,
                        volume: nil,
                        workoutId: workout.id,
                        workoutExerciseId: we.id,
                        setId: maxSet.id,
                        achievedAt: achievedAt,
                        createdAt: now
                    )
                    events.append(event)
                }
            }
        }
    }

    private func nextTempId() -> Int64 {
        tempIdCounter -= 1
        return tempIdCounter
    }
}
