import Foundation

struct ExerciseHistorySummary {
    let exerciseName: String
    let workoutCount: Int
    let totalSets: Int
    let totalVolume: Double
    let recentWorkouts: [Workout]
    let personalRecords: [PersonalRecord]
    let relatedMuscles: [Muscle]

    var latestWorkout: Workout? {
        recentWorkouts.first
    }
}

struct ExerciseHistoryCalculator {
    func calculate(
        exerciseId: String?,
        exerciseName: String,
        bodyPart: BodyPart?,
        workouts: [Workout],
        personalRecords: [PersonalRecord],
        alternateExerciseIds: [String] = [],
        alternateExerciseNames: [String] = []
    ) -> ExerciseHistorySummary {
        let matched = workouts.compactMap { workout -> Workout? in
            let exercises = workout.exercises.filter { workoutExercise in
                if let exerciseId, workoutExercise.exerciseId == exerciseId {
                    return true
                }
                if alternateExerciseIds.contains(workoutExercise.exerciseId) {
                    return true
                }
                return workoutExercise.exerciseName == exerciseName || alternateExerciseNames.contains(workoutExercise.exerciseName)
            }
            guard !exercises.isEmpty else { return nil }
            var copy = workout
            copy.exercises = exercises
            return copy
        }.sorted { $0.startTime > $1.startTime }

        let matchedPRs = personalRecords.filter { record in
            if let exerciseId, record.exerciseId == exerciseId {
                return true
            }
            if alternateExerciseIds.contains(record.exerciseId) {
                return true
            }
            return record.exerciseName == exerciseName || alternateExerciseNames.contains(record.exerciseName)
        }

        let muscles: [Muscle]
        if let first = matched.first?.exercises.first {
            let mapping = ExerciseMuscleMappingProvider.mapping(for: first)
            muscles = Array(Set(mapping.primaryMuscles + mapping.secondaryMuscles)).sorted { $0.rawValue < $1.rawValue }
        } else if let bodyPart {
            let mapping = ExerciseMuscleMappingProvider.mapping(for: bodyPart)
            muscles = Array(Set(mapping.primaryMuscles + mapping.secondaryMuscles)).sorted { $0.rawValue < $1.rawValue }
        } else {
            muscles = []
        }

        return ExerciseHistorySummary(
            exerciseName: exerciseName,
            workoutCount: matched.count,
            totalSets: matched.reduce(0) { $0 + $1.totalSets },
            totalVolume: matched.reduce(0) { $0 + $1.totalVolume },
            recentWorkouts: Array(matched.prefix(12)),
            personalRecords: matchedPRs.sorted { $0.prType.priority < $1.prType.priority },
            relatedMuscles: muscles
        )
    }
}
