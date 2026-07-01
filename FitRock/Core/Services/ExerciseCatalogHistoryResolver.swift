import Foundation

struct ExerciseCatalogHistoryResolver {
    private let calculator: ExerciseHistoryCalculator

    init(calculator: ExerciseHistoryCalculator = ExerciseHistoryCalculator()) {
        self.calculator = calculator
    }

    func resolve(
        item: ExerciseCatalogItem,
        workouts: [Workout],
        personalRecords: [PersonalRecord]
    ) -> ExerciseHistorySummary {
        let summary = calculator.calculate(
            exerciseId: item.dbExerciseId,
            exerciseName: item.nameZh,
            bodyPart: item.bodyPart,
            workouts: workouts,
            personalRecords: personalRecords,
            alternateExerciseIds: alternateExerciseIds(for: item),
            alternateExerciseNames: alternateExerciseNames(for: item)
        )

        if summary.workoutCount > 0 || item.nameEn == nil {
            return summaryWithCatalogMuscles(summary, item: item)
        }

        let englishSummary = calculator.calculate(
            exerciseId: nil,
            exerciseName: item.nameEn ?? item.nameZh,
            bodyPart: item.bodyPart,
            workouts: workouts,
            personalRecords: personalRecords,
            alternateExerciseIds: alternateExerciseIds(for: item),
            alternateExerciseNames: [item.nameZh]
        )
        return summaryWithCatalogMuscles(englishSummary, item: item)
    }

    private func alternateExerciseIds(for item: ExerciseCatalogItem) -> [String] {
        var ids: [String] = []
        if let jsonExerciseId = item.jsonExerciseId {
            ids.append("json:\(jsonExerciseId)")
        }
        if let dbExerciseId = item.dbExerciseId {
            ids.append(dbExerciseId)
        }
        return ids
    }

    private func alternateExerciseNames(for item: ExerciseCatalogItem) -> [String] {
        [item.nameEn].compactMap { $0 }
    }

    private func summaryWithCatalogMuscles(_ summary: ExerciseHistorySummary, item: ExerciseCatalogItem) -> ExerciseHistorySummary {
        guard summary.relatedMuscles.isEmpty || summary.workoutCount == 0 else { return summary }
        let muscles = Array(Set(item.primaryMuscles + item.secondaryMuscles)).sorted { $0.rawValue < $1.rawValue }
        return ExerciseHistorySummary(
            exerciseName: summary.exerciseName,
            workoutCount: summary.workoutCount,
            totalSets: summary.totalSets,
            totalVolume: summary.totalVolume,
            recentWorkouts: summary.recentWorkouts,
            personalRecords: summary.personalRecords,
            relatedMuscles: muscles
        )
    }
}
